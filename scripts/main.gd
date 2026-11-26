extends Node2D

const ARENA = preload("res://assets/dark_fantasy/arena_battle.png")
const MENU_BACKDROP = preload("res://assets/dark_fantasy/menu_fortress.png")
const CHAR_PORTRAITS = [preload("res://assets/dark_fantasy/portrait_knight.png"), preload("res://assets/dark_fantasy/portrait_rogue.png"), preload("res://assets/dark_fantasy/portrait_druid.png"), preload("res://assets/dark_fantasy/portrait_guardian.png"), preload("res://assets/dark_fantasy/portrait_dark_prince.png")]
# High-resolution, transparent full-body character art. The original gameplay sprites
# remain in assets/ for compatibility, but these unified illustrations are used in battle.
const CHAR_TEXTURES = [
    preload("res://assets/dark_fantasy/fighter_knight.png"),
    preload("res://assets/dark_fantasy/fighter_rogue.png"),
    preload("res://assets/dark_fantasy/fighter_druid.png"),
    preload("res://assets/dark_fantasy/fighter_guardian.png"),
    preload("res://assets/dark_fantasy/fighter_dark_prince.png")
]
# Six-row, four-frame-per-state atlases: idle, walk, attack, hurt, dodge, block.
const CHAR_ANIM_SHEETS = [
    preload("res://assets/dark_fantasy/anim_knight_sheet.png"),
    preload("res://assets/dark_fantasy/anim_rogue_sheet.png"),
    preload("res://assets/dark_fantasy/anim_druid_sheet.png"),
    preload("res://assets/dark_fantasy/anim_guardian_sheet.png"),
    preload("res://assets/dark_fantasy/anim_dark_prince_sheet.png")
]
const WEAPON_TEXTURES = [
    preload("res://assets/dark_fantasy/weapon_knight_sword.png"),
    preload("res://assets/dark_fantasy/weapon_rogue_dagger.png"),
    preload("res://assets/dark_fantasy/weapon_druid_staff.png"),
    preload("res://assets/dark_fantasy/weapon_guardian_hammer.png"),
    preload("res://assets/dark_fantasy/weapon_dark_prince_blade.png")
]
const GUARDIAN_SHIELD = preload("res://assets/dark_fantasy/weapon_guardian_shield.png")
const CHAR_NAMES = ["Рыцарь", "Разбойник", "Друид", "Страж", "Тёмный принц"]
const CHAR_COLORS = [Color("#d65b43"), Color("#56b6a0"), Color("#8bbd62"), Color("#d5a64d"), Color("#9b72d6")]

enum Mode { MENU, LOCAL, BOT, ONLINE }
var mode = Mode.MENU
var p1 := Vector2(500, 470)
var p2 := Vector2(1100, 470)
var hp1 := 100.0
var hp2 := 100.0
var round_time := 90.0
var attack_cd := [0.0, 0.0]
var ability_cd := [0.0, 0.0]
var attack_flash := [0.0, 0.0]
var ability_flash := [0.0, 0.0]
var facing := [Vector2.RIGHT, Vector2.LEFT]
var roots := [0.0, 0.0]
var dark_zones: Array[Dictionary] = [{}, {}]
var dark_zone_ticks := [0.0, 0.0]
var bot_level := 1
var char1 := 0
var char2 := 1
var projectiles: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var peer: ENetMultiplayerPeer
var net_send_timer := 0.0
var status_text := "Выбери режим"
var menu_layer: CanvasLayer
var game_layer: CanvasLayer
var hp1_bar: ProgressBar
var hp2_bar: ProgressBar
var portrait1: TextureRect
var portrait2: TextureRect
var skill1_label: Label
var skill2_label: Label
var timer_label: Label
var status_label: Label
var menu_panel: PanelContainer
var bot_option: OptionButton
var ip_input: LineEdit
var char1_option: OptionButton
var char2_option: OptionButton
var attack_was_down := [false, false]
var ability_was_down := [false, false]
var campaign_active := false
var campaign_result_handled := false
var campaign_unlocked := 0
var settings_dialog: AcceptDialog
var music_volume := 0.75
var sfx_volume := 0.85
var music_player: AudioStreamPlayer
var campaign_select_dialog: AcceptDialog
var campaign_story_dialog: AcceptDialog
var campaign_chapter := 0
var campaign_pending_result := false
var campaign_event_timer := 0.0
var campaign_event_warning := 0.0
var campaign_event_ready := false
var campaign_event_pos := Vector2(800, 470)
var campaign_event_flash := 0.0
var visual_time := 0.0
var ember_particles: Array[Dictionary] = []
# Combat presentation: procedural pose animation layered over the illustrated fighters.
var fighter_anim_time := [0.0, 0.0]
var attack_anim_timer := [0.0, 0.0]
var attack_anim_duration := [0.34, 0.34]
var hurt_anim_timer := [0.0, 0.0]
var move_blend := [0.0, 0.0]
var combo_index := [0, 0]
var combo_window := [0.0, 0.0]
var dodge_timer := [0.0, 0.0]
var dodge_cd := [0.0, 0.0]
var dodge_was_down := [false, false]
var block_active := [false, false]
var screen_shake := 0.0
var screen_shake_seed := 0.0
var draw_offset := Vector2.ZERO
var hit_stop := 0.0
const AUDIO_FILES := {
    "menu": "res://assets/audio/menu_theme.wav",
    "battle": "res://assets/audio/battle_theme.wav",
    "story": "res://assets/audio/story_theme.wav",
    "sword": "res://assets/audio/sword_swing.wav",
    "hit": "res://assets/audio/impact.wav",
    "button": "res://assets/audio/button.wav",
    "magic": "res://assets/audio/magic.wav",
    "shadow": "res://assets/audio/shadow.wav",
    "tentacle": "res://assets/audio/tentacle.wav",
    "boss": "res://assets/audio/boss.wav",
    "knight_ability": "res://assets/audio/knight_ability.wav",
    "rogue_ability": "res://assets/audio/rogue_ability.wav",
    "druid_ability": "res://assets/audio/druid_ability.wav",
    "guardian_ability": "res://assets/audio/guardian_ability.wav",
    "prince_ability": "res://assets/audio/prince_ability.wav",
    "shadow_end": "res://assets/audio/shadow_end.wav"
}
const CAMPAIGN_INTROS := [
    "Крепость Серебряного Предела пала за одну ночь. Рыцарь находит на камне следы живой тьмы и отправляется искать выживших. На дороге он встречает Разбойника, который знает больше, чем говорит.",
    "Разбойник украл древнюю печать не ради золота: её символ совпадает с клеймом на вещи, оставленной его пропавшей сестрой. Рыцарь считает его предателем, но в руинах они находят запись о принце, который когда-то удерживал Тьму за гранью.",
    "Друид входит в проклятый лес, где корни помнят рождение магии. Древние существа не нападают первыми — они пытаются предупредить героя: печать не уничтожает Тьму, а удерживает внутри неё чью-то волю.",
    "Страж веками охранял королевскую печать, не зная, что её создали из самой сущности наследника престола. Его клятва была основана на лжи. Теперь он должен решить, защищает ли он королевство или продолжает его древнюю ошибку.",
    "Тёмный принц был последним, кто добровольно принял в себя разлом, чтобы спасти королевство. Совет запечатал его вместе с катастрофой и назвал чудовищем. Его тьма — не жажда власти, а боль и попытка удержать расползающийся разлом. Финальная битва решит, можно ли разорвать печать, не погубив мир."
]
const CAMPAIGN_OUTROS := [
    "За стенами крепости тьма отступила, но Рыцарь находит на обломке печати знак вора. След ведёт к старому тракту.",
    "Печать отвечает на прикосновение Разбойника. В её памяти звучит голос: «Он не открыл врата. Он держал их закрытыми».",
    "Лес раскрывает истину: тьма была создана как узел, связывающий разлом с живым сердцем. Страж знает, где находится последний замок.",
    "Страж снимает шлем перед руинами трона. Он вспоминает мальчика-принца и понимает, что сам помог совету запечатать невиновного.",
    "Разлом затихает. Принц больше не один несёт его тяжесть. Королевство должно решить, кем считать того, кого оно веками называло чудовищем. Это не конец памяти — это начало искупления."
]

const CAMPAIGN_NAMES := [
    "I — The Forgotten Arena",
    "II — Forest of Shadows",
    "III — The Fallen Fortress",
    "IV — Abyss Gate",
    "V — The Dark Throne"
]
const CAMPAIGN_DESCRIPTIONS := [
    "Пыль забытой арены скрывает первую печать. Старые стражи проверят решимость героя.",
    "Лесные тропы меняются под ногами, а древние хранители защищают тайну печати.",
    "В павшей крепости остались верные защитники совета и следы королевской тайны.",
    "У врат Бездны защитник печати испытывает героя последним испытанием.",
    "На Тёмном троне ждёт тот, чья судьба связана с разломом."
]
const CAMPAIGN_GOALS := [
    "Победить Разбойника и найти знак на печати.",
    "Победить Тёмного принца и вернуть украденную печать.",
    "Победить Стража крепости и раскрыть тайну леса.",
    "Победить Тёмного принца у врат Бездны.",
    "Победить последнего противника и завершить историю."
]
const CAMPAIGN_REWARDS := [
    "Открывается глава Forest of Shadows.",
    "Открывается глава The Fallen Fortress.",
    "Открывается глава Abyss Gate.",
    "Открывается глава The Dark Throne.",
    "Кампания завершена. Все главы доступны для повторного прохождения."
]
const CAMPAIGN_ENEMIES := [1, 4, 3, 4, 0]
const CAMPAIGN_SAVE := "user://campaign_progress.save"

func _ready():
    _load_audio_settings()
    _setup_audio_buses()
    _build_ui()
    _seed_embers()
    _play_music("menu")
    set_process(true)
    queue_redraw()

func _build_ui():
    menu_layer = CanvasLayer.new()
    menu_layer.layer = 3
    add_child(menu_layer)

    # Full-screen transparent root: the fortress artwork is drawn behind this UI.
    menu_panel = PanelContainer.new()
    menu_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    menu_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
    menu_layer.add_child(menu_panel)
    menu_panel.modulate.a = 0.0
    var menu_intro := create_tween()
    menu_intro.set_parallel(true)
    menu_intro.tween_property(menu_panel, "modulate:a", 1.0, 0.85)

    var canvas := Control.new()
    canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    menu_panel.add_child(canvas)

    # Left title block and one clean hero silhouette keep the composition focused.
    var title := Label.new()
    title.text = "ARENA DUEL"
    title.position = Vector2(92, 76)
    title.size = Vector2(700, 88)
    title.add_theme_font_size_override("font_size", 68)
    title.add_theme_color_override("font_color", Color("#f3dfbd"))
    title.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
    title.add_theme_constant_override("shadow_offset_x", 3)
    title.add_theme_constant_override("shadow_offset_y", 5)
    canvas.add_child(title)

    var subtitle := Label.new()
    subtitle.text = "СТАЛЬ  •  МАГИЯ  •  ЧЕСТЬ"
    subtitle.position = Vector2(100, 165)
    subtitle.size = Vector2(600, 32)
    subtitle.add_theme_font_size_override("font_size", 19)
    subtitle.add_theme_color_override("font_color", Color("#d8bd91"))
    canvas.add_child(subtitle)

    var hero_art := TextureRect.new()
    hero_art.texture = CHAR_TEXTURES[0]
    hero_art.position = Vector2(355, 205)
    hero_art.size = Vector2(430, 485)
    hero_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    hero_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    hero_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hero_art.modulate = Color(1.0, 1.0, 1.0, 0.96)
    canvas.add_child(hero_art)

    var hero_caption := Label.new()
    hero_caption.text = "ПЯТЬ ГЕРОЕВ. ОДНА АРЕНА."
    hero_caption.position = Vector2(120, 520)
    hero_caption.size = Vector2(520, 34)
    hero_caption.add_theme_font_size_override("font_size", 18)
    hero_caption.add_theme_color_override("font_color", Color("#e9d4b0"))
    canvas.add_child(hero_caption)

    # Character setup card at the lower left.
    var select_card := PanelContainer.new()
    select_card.position = Vector2(86, 610)
    select_card.size = Vector2(800, 205)
    select_card.add_theme_stylebox_override("panel", _make_menu_card_style(Color(0.025, 0.032, 0.048, 0.91)))
    canvas.add_child(select_card)
    var select_content := VBoxContainer.new()
    select_content.add_theme_constant_override("separation", 10)
    select_card.add_child(select_content)
    var select_title := Label.new()
    select_title.text = "ВЫБОР ГЕРОЕВ"
    select_title.add_theme_font_size_override("font_size", 17)
    select_title.add_theme_color_override("font_color", Color("#e4c18b"))
    select_content.add_child(select_title)
    var picks_row := HBoxContainer.new()
    picks_row.add_theme_constant_override("separation", 18)
    select_content.add_child(picks_row)

    var p1_box := VBoxContainer.new()
    p1_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    picks_row.add_child(p1_box)
    var p1_label := Label.new()
    p1_label.text = "ИГРОК 1"
    p1_label.add_theme_font_size_override("font_size", 12)
    p1_label.add_theme_color_override("font_color", Color("#b9b1a5"))
    p1_box.add_child(p1_label)
    char1_option = OptionButton.new()
    for i in range(CHAR_NAMES.size()):
        char1_option.add_item(CHAR_NAMES[i], i)
    char1_option.select(0)
    char1_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _style_menu_option(char1_option)
    p1_box.add_child(char1_option)

    var p2_box := VBoxContainer.new()
    p2_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    picks_row.add_child(p2_box)
    var p2_label := Label.new()
    p2_label.text = "ИГРОК 2 / БОТ"
    p2_label.add_theme_font_size_override("font_size", 12)
    p2_label.add_theme_color_override("font_color", Color("#b9b1a5"))
    p2_box.add_child(p2_label)
    char2_option = OptionButton.new()
    for i in range(CHAR_NAMES.size()):
        char2_option.add_item(CHAR_NAMES[i], i)
    char2_option.select(1)
    char2_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _style_menu_option(char2_option)
    p2_box.add_child(char2_option)

    var bot_box := VBoxContainer.new()
    bot_box.custom_minimum_size = Vector2(150, 0)
    picks_row.add_child(bot_box)
    var bot_label := Label.new()
    bot_label.text = "СЛОЖНОСТЬ БОТА"
    bot_label.add_theme_font_size_override("font_size", 12)
    bot_label.add_theme_color_override("font_color", Color("#b9b1a5"))
    bot_box.add_child(bot_label)
    bot_option = OptionButton.new()
    bot_option.add_item("Лёгкая", 0)
    bot_option.add_item("Средняя", 1)
    bot_option.add_item("Сложная", 2)
    bot_option.select(1)
    _style_menu_option(bot_option)
    bot_box.add_child(bot_option)

    # Main navigation card. All actions from the original menu are retained.
    var nav_card := PanelContainer.new()
    nav_card.position = Vector2(1010, 78)
    nav_card.size = Vector2(500, 744)
    nav_card.add_theme_stylebox_override("panel", _make_menu_card_style(Color(0.018, 0.023, 0.038, 0.94)))
    canvas.add_child(nav_card)
    var nav := VBoxContainer.new()
    nav.add_theme_constant_override("separation", 11)
    nav_card.add_child(nav)

    var nav_heading := Label.new()
    nav_heading.text = "ГЛАВНОЕ МЕНЮ"
    nav_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    nav_heading.add_theme_font_size_override("font_size", 25)
    nav_heading.add_theme_color_override("font_color", Color("#f0d6aa"))
    nav.add_child(nav_heading)
    var nav_subtitle := Label.new()
    nav_subtitle.text = "ВЫБЕРИ СВОЙ ПУТЬ"
    nav_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    nav_subtitle.add_theme_font_size_override("font_size", 11)
    nav_subtitle.add_theme_color_override("font_color", Color("#9d8a70"))
    nav.add_child(nav_subtitle)
    var separator := HSeparator.new()
    separator.add_theme_color_override("font_color", Color("#755b3e"))
    nav.add_child(separator)

    _add_button(nav, "PLAY     ·     ЛОКАЛЬНАЯ АРЕНА", _start_local, true)
    _add_button(nav, "CAMPAIGN     ·     КАМПАНИЯ", _start_campaign)
    _add_button(nav, "PvB     ·     ПРОТИВ БОТА", _start_bot)
    _add_button(nav, "PvP     ·     СОЗДАТЬ КОМНАТУ", _host_online)

    var online_label := Label.new()
    online_label.text = "ПОДКЛЮЧЕНИЕ К ИГРОКУ"
    online_label.add_theme_font_size_override("font_size", 11)
    online_label.add_theme_color_override("font_color", Color("#b7a58b"))
    nav.add_child(online_label)
    ip_input = LineEdit.new()
    ip_input.placeholder_text = "IP-адрес хоста"
    ip_input.text = "127.0.0.1"
    ip_input.custom_minimum_size = Vector2(0, 42)
    ip_input.add_theme_stylebox_override("normal", _make_menu_card_style(Color("#111722")))
    ip_input.add_theme_color_override("font_color", Color("#f0e5d2"))
    ip_input.add_theme_color_override("font_placeholder_color", Color("#8b8277"))
    nav.add_child(ip_input)
    _add_button(nav, "PvP     ·     ПОДКЛЮЧИТЬСЯ", _join_online)

    var spacer_menu := Control.new()
    spacer_menu.size_flags_vertical = Control.SIZE_EXPAND_FILL
    nav.add_child(spacer_menu)
    _add_button(nav, "SETTINGS     ·     НАСТРОЙКИ", _open_settings)
    _add_button(nav, "EXIT     ·     ВЫХОД", func(): get_tree().quit())

    status_label = Label.new()
    status_label.text = "P1: WASD / геймпад  ·  SPACE атака  ·  Q способность\nP2: стрелки / второй геймпад  ·  ENTER атака  ·  SHIFT способность"
    status_label.position = Vector2(95, 835)
    status_label.size = Vector2(1390, 48)
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status_label.add_theme_font_size_override("font_size", 12)
    status_label.add_theme_color_override("font_color", Color("#c6b69e"))
    canvas.add_child(status_label)

    _load_campaign_progress()
    _build_settings_dialog()
    _build_campaign_dialog()
    campaign_story_dialog = AcceptDialog.new()
    campaign_story_dialog.title = "Хроники Пепельного Королевства"
    campaign_story_dialog.min_size = Vector2i(700, 340)
    campaign_story_dialog.confirmed.connect(_campaign_story_confirmed)
    campaign_story_dialog.close_requested.connect(_back_menu)
    menu_layer.add_child(campaign_story_dialog)

    game_layer = CanvasLayer.new()
    game_layer.layer = 2
    add_child(game_layer)
    game_layer.visible = false
    var top = HBoxContainer.new()
    top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    top.offset_left = 28
    top.offset_top = 16
    top.offset_right = -28
    top.offset_bottom = 112
    top.add_theme_constant_override("separation", 22)
    game_layer.add_child(top)
    var left_hud := VBoxContainer.new()
    left_hud.custom_minimum_size = Vector2(390, 0)
    top.add_child(left_hud)
    var left_title_row := HBoxContainer.new()
    left_title_row.add_theme_constant_override("separation", 10)
    left_hud.add_child(left_title_row)
    portrait1 = TextureRect.new()
    portrait1.custom_minimum_size = Vector2(48, 48)
    portrait1.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    portrait1.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    portrait1.texture = CHAR_PORTRAITS[0]
    left_title_row.add_child(portrait1)
    var left_name := Label.new()
    left_name.name = "PlayerOneName"
    left_name.text = "РЫЦАРЬ"
    left_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    left_name.add_theme_font_size_override("font_size", 20)
    left_name.add_theme_color_override("font_color", Color("#f3d6a1"))
    left_title_row.add_child(left_name)
    hp1_bar = ProgressBar.new()
    hp1_bar.custom_minimum_size = Vector2(390, 30)
    hp1_bar.max_value = 100
    hp1_bar.show_percentage = false
    hp1_bar.add_theme_stylebox_override("background", _make_bar_style(Color("#241b1a")))
    hp1_bar.add_theme_stylebox_override("fill", _make_bar_style(Color("#b94d42")))
    left_hud.add_child(hp1_bar)
    skill1_label = Label.new()
    skill1_label.name = "PlayerOneSkill"
    skill1_label.text = "A / SPACE — АТАКА     X / Q — СПОСОБНОСТЬ"
    skill1_label.add_theme_font_size_override("font_size", 12)
    left_hud.add_child(skill1_label)
    var spacer = Control.new()
    spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top.add_child(spacer)
    var center_hud := VBoxContainer.new()
    center_hud.alignment = BoxContainer.ALIGNMENT_CENTER
    top.add_child(center_hud)
    timer_label = Label.new()
    timer_label.add_theme_font_size_override("font_size", 34)
    timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    center_hud.add_child(timer_label)
    var round_label := Label.new()
    round_label.text = "РАУНД"
    round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    round_label.add_theme_font_size_override("font_size", 11)
    center_hud.add_child(round_label)
    var spacer2 = Control.new()
    spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top.add_child(spacer2)
    var right_hud := VBoxContainer.new()
    right_hud.custom_minimum_size = Vector2(390, 0)
    right_hud.alignment = BoxContainer.ALIGNMENT_END
    top.add_child(right_hud)
    var right_title_row := HBoxContainer.new()
    right_title_row.alignment = BoxContainer.ALIGNMENT_END
    right_title_row.add_theme_constant_override("separation", 10)
    right_hud.add_child(right_title_row)
    var right_name := Label.new()
    right_name.name = "PlayerTwoName"
    right_name.text = "РАЗБОЙНИК"
    right_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    right_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    right_name.add_theme_font_size_override("font_size", 20)
    right_name.add_theme_color_override("font_color", Color("#f3d6a1"))
    right_title_row.add_child(right_name)
    portrait2 = TextureRect.new()
    portrait2.custom_minimum_size = Vector2(48, 48)
    portrait2.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    portrait2.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    portrait2.texture = CHAR_PORTRAITS[1]
    right_title_row.add_child(portrait2)
    hp2_bar = ProgressBar.new()
    hp2_bar.custom_minimum_size = Vector2(390, 30)
    hp2_bar.max_value = 100
    hp2_bar.show_percentage = false
    hp2_bar.add_theme_stylebox_override("background", _make_bar_style(Color("#1b2029")))
    hp2_bar.add_theme_stylebox_override("fill", _make_bar_style(Color("#4d8fbd")))
    right_hud.add_child(hp2_bar)
    skill2_label = Label.new()
    skill2_label.name = "PlayerTwoSkill"
    skill2_label.text = "A / ENTER — АТАКА     X / SHIFT — СПОСОБНОСТЬ"
    skill2_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    skill2_label.add_theme_font_size_override("font_size", 12)
    right_hud.add_child(skill2_label)
    var back = Button.new()
    back.text = "В МЕНЮ"
    back.position = Vector2(18, 850)
    back.pressed.connect(_back_menu)
    game_layer.add_child(back)

func _make_menu_card_style(fill: Color) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = fill
    style.border_color = Color("#80613d")
    style.set_border_width_all(1)
    style.set_corner_radius_all(5)
    style.content_margin_left = 20
    style.content_margin_right = 20
    style.content_margin_top = 16
    style.content_margin_bottom = 16
    return style

func _style_menu_option(option: OptionButton) -> void:
    option.custom_minimum_size = Vector2(0, 42)
    option.add_theme_stylebox_override("normal", _make_menu_card_style(Color("#151c28")))
    option.add_theme_stylebox_override("hover", _make_menu_card_style(Color("#202b3a")))
    option.add_theme_color_override("font_color", Color("#eee0c8"))
    option.add_theme_font_size_override("font_size", 15)

func _add_button(parent: VBoxContainer, caption: String, action: Callable, primary: bool = false):
    var b := Button.new()
    b.text = caption
    b.custom_minimum_size = Vector2(0, 54 if primary else 48)
    b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    b.add_theme_font_size_override("font_size", 16 if primary else 14)
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color("#51391f") if primary else Color("#182231")
    normal.border_color = Color("#d0a45e") if primary else Color("#766044")
    normal.set_border_width_all(1 if not primary else 2)
    normal.set_corner_radius_all(4)
    normal.content_margin_left = 16
    normal.content_margin_right = 16
    var hover := normal.duplicate() as StyleBoxFlat
    hover.bg_color = Color("#765329") if primary else Color("#29394d")
    hover.border_color = Color("#f0ca83")
    var pressed := normal.duplicate() as StyleBoxFlat
    pressed.bg_color = Color("#2a2119")
    b.add_theme_stylebox_override("normal", normal)
    b.add_theme_stylebox_override("hover", hover)
    b.add_theme_stylebox_override("pressed", pressed)
    b.add_theme_stylebox_override("focus", hover)
    b.add_theme_color_override("font_color", Color("#f5e5ca"))
    b.add_theme_color_override("font_hover_color", Color("#fff4df"))
    b.add_theme_color_override("font_pressed_color", Color("#d8b978"))
    b.pressed.connect(_play_button_and_action.bind(action))
    parent.add_child(b)

func _make_bar_style(color: Color) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.set_corner_radius_all(5)
    style.content_margin_left = 2
    style.content_margin_right = 2
    style.content_margin_top = 2
    style.content_margin_bottom = 2
    return style

func _read_character_picks():
    char1 = char1_option.get_selected_id()
    char2 = char2_option.get_selected_id()

func _start_local():
    campaign_active = false
    _read_character_picks()
    _start_game(Mode.LOCAL)

func _start_bot():
    campaign_active = false
    _read_character_picks()
    bot_level = bot_option.selected
    _start_game(Mode.BOT)

func _start_game(new_mode: int):
    _disconnect_network()
    mode = new_mode
    p1 = Vector2(500, 470)
    p2 = Vector2(1100, 470)
    hp1 = 100
    hp2 = 100
    round_time = 90
    attack_cd = [0.0, 0.0]
    ability_cd = [0.0, 0.0]
    attack_flash = [0.0, 0.0]
    ability_flash = [0.0, 0.0]
    facing = [Vector2.RIGHT, Vector2.LEFT]
    roots = [0.0, 0.0]
    dark_zones = [{}, {}]
    dark_zone_ticks = [0.0, 0.0]
    attack_was_down = [false, false]
    ability_was_down = [false, false]
    dodge_was_down = [false, false]
    dodge_timer = [0.0, 0.0]
    dodge_cd = [0.0, 0.0]
    block_active = [false, false]
    attack_anim_timer = [0.0, 0.0]
    attack_anim_duration = [0.34, 0.34]
    hurt_anim_timer = [0.0, 0.0]
    campaign_result_handled = false
    projectiles.clear()
    effects.clear()
    status_text = "E / KP1 — УКЛОНЕНИЕ   •   R / KP0 — БЛОК"
    menu_panel.visible = false
    game_layer.visible = true
    _update_hud()
    _play_music("battle")
    queue_redraw()

func _host_online():
    campaign_active = false
    _read_character_picks()
    _start_game(Mode.ONLINE)
    peer = ENetMultiplayerPeer.new()
    var err = peer.create_server(2456, 1)
    if err != OK:
        status_label.text = "Не удалось открыть порт 2456: " + str(err)
        _back_menu()
        return
    multiplayer.multiplayer_peer = peer
    status_text = "Комната создана. Сообщи другу IP; UDP-порт 2456."
    status_label.text = status_text

func _join_online():
    campaign_active = false
    _read_character_picks()
    var address = ip_input.text.strip_edges()
    if address.is_empty(): address = "127.0.0.1"
    _start_game(Mode.ONLINE)
    peer = ENetMultiplayerPeer.new()
    var err = peer.create_client(address, 2456)
    if err != OK:
        status_label.text = "Не удалось подключиться: " + str(err)
        _back_menu()
        return
    multiplayer.multiplayer_peer = peer
    status_text = "Подключение к " + address

func _disconnect_network():
    if multiplayer.multiplayer_peer != null:
        multiplayer.multiplayer_peer.close()
        multiplayer.multiplayer_peer = null

func _back_menu():
    _disconnect_network()
    mode = Mode.MENU
    game_layer.visible = false
    menu_panel.visible = true
    status_label.text = "Выбери режим"
    campaign_active = false
    _play_music("menu")
    queue_redraw()

func _process(delta):
    visual_time += delta
    _update_embers(delta)
    if mode == Mode.MENU:
        queue_redraw()
        return
    if hp1 <= 0 or hp2 <= 0 or round_time <= 0:
        if hp1 <= 0: status_text = "Победил " + CHAR_NAMES[char2] + "!"
        elif hp2 <= 0: status_text = "Победил " + CHAR_NAMES[char1] + "!"
        else: status_text = "Время вышло!"
        if campaign_active and not campaign_result_handled:
            campaign_result_handled = true
            if hp2 <= 0:
                campaign_unlocked = min(4, max(campaign_unlocked, campaign_chapter + 1))
                _save_campaign_progress()
                status_text = "ГЛАВА ПРОЙДЕНА: " + CAMPAIGN_NAMES[campaign_chapter] + " • Прогресс сохранён"
                campaign_pending_result = true
                call_deferred("_show_campaign_result")
            else:
                status_text = "ГЛАВА НЕ ПРОЙДЕНА • Попробуй ещё раз"
                campaign_pending_result = true
                call_deferred("_show_campaign_fail")
        queue_redraw()
        return

    round_time = max(0.0, round_time - delta)
    var combat_delta: float = delta
    if hit_stop > 0.0:
        hit_stop = maxf(0.0, hit_stop - delta)
        combat_delta = delta * 0.22
    screen_shake = maxf(0.0, screen_shake - delta * 2.8)
    for i in range(2):
        attack_cd[i] = max(0.0, attack_cd[i] - combat_delta)
        ability_cd[i] = max(0.0, ability_cd[i] - combat_delta)
        attack_flash[i] = max(0.0, attack_flash[i] - delta)
        ability_flash[i] = max(0.0, ability_flash[i] - delta)
        roots[i] = max(0.0, roots[i] - combat_delta)
        fighter_anim_time[i] += delta
        attack_anim_timer[i] = maxf(0.0, attack_anim_timer[i] - delta)
        hurt_anim_timer[i] = maxf(0.0, hurt_anim_timer[i] - delta)
        combo_window[i] = maxf(0.0, combo_window[i] - delta)
        dodge_timer[i] = maxf(0.0, dodge_timer[i] - delta)
        dodge_cd[i] = maxf(0.0, dodge_cd[i] - delta)
    _update_dark_zones(delta)
    _update_campaign_event(delta)

    var pads = Input.get_connected_joypads()
    # Player 1 owns the first connected controller in every mode, including PvB.
    # With one controller, player 2 remains on the arrow-key keyboard layout.
    var p1_pad = pads[0] if pads.size() >= 1 else -1
    var p2_pad = pads[1] if pads.size() >= 2 else -1
    block_active[0] = Input.is_key_pressed(KEY_R) or (p1_pad >= 0 and Input.is_joy_button_pressed(p1_pad, JOY_BUTTON_Y))
    block_active[1] = Input.is_key_pressed(KEY_KP_0) or (p2_pad >= 0 and Input.is_joy_button_pressed(p2_pad, JOY_BUTTON_Y))
    if _p1_dodge_pressed(): _dodge(0)
    if mode == Mode.LOCAL and _p2_dodge_pressed(): _dodge(1)

    var m1 = _keyboard_move_1()
    if p1_pad >= 0:
        var stick1 = _joy_move(p1_pad)
        if stick1.length() > 0.1:
            m1 = stick1
    move_blend[0] = clampf(m1.length(), 0.0, 1.0)
    if roots[0] <= 0.0 and m1.length() > 0.1:
        p1 += m1.limit_length(1.0) * _speed(char1) * (1.3 if _is_dark_prince_empowered(0) else 1.0) * combat_delta
        facing[0] = m1.normalized()
    p1 = _clamp_player(p1)

    if mode == Mode.LOCAL:
        var m2 = _keyboard_move_2()
        if p2_pad >= 0:
            var stick2 = _joy_move(p2_pad)
            if stick2.length() > 0.1:
                m2 = stick2
        move_blend[1] = clampf(m2.length(), 0.0, 1.0)
        if roots[1] <= 0 and m2.length() > 0.1:
            p2 += m2.limit_length(1.0) * _speed(char2) * (1.3 if _is_dark_prince_empowered(1) else 1.0) * combat_delta
            facing[1] = m2.normalized()
        if _p2_attack_pressed(): _melee(1)
        if _p2_ability_pressed(): _ability(1)
    elif mode == Mode.BOT:
        _bot_update(combat_delta)
    elif mode == Mode.ONLINE:
        if not multiplayer.is_server(): _send_remote_state()

    if roots[0] <= 0 and _p1_attack_pressed(): _melee(0)
    if _p1_ability_pressed(): _ability(0)
    _update_effects(delta)
    _update_hud()
    queue_redraw()

func _keyboard_move_1() -> Vector2:
    return Vector2(float(Input.is_key_pressed(KEY_D))-float(Input.is_key_pressed(KEY_A)), float(Input.is_key_pressed(KEY_S))-float(Input.is_key_pressed(KEY_W)))

func _keyboard_move_2() -> Vector2:
    return Vector2(float(Input.is_key_pressed(KEY_RIGHT))-float(Input.is_key_pressed(KEY_LEFT)), float(Input.is_key_pressed(KEY_DOWN))-float(Input.is_key_pressed(KEY_UP)))

func _joy_move(index: int) -> Vector2:
    if not Input.get_connected_joypads().has(index): return Vector2.ZERO
    var v = Vector2(Input.get_joy_axis(index, JOY_AXIS_LEFT_X), Input.get_joy_axis(index, JOY_AXIS_LEFT_Y))
    if v.length() < 0.22: return Vector2.ZERO
    return v.limit_length(1.0)

func _p1_attack_pressed() -> bool:
    var pads = Input.get_connected_joypads()
    var pad_down := pads.size() > 0 and Input.is_joy_button_pressed(pads[0], JOY_BUTTON_A)
    var key_down := Input.is_key_pressed(KEY_SPACE)
    var down := key_down or pad_down
    var just: bool = down and not attack_was_down[0]
    attack_was_down[0] = down
    return just

func _p1_ability_pressed() -> bool:
    var pads = Input.get_connected_joypads()
    var pad_down := pads.size() > 0 and Input.is_joy_button_pressed(pads[0], JOY_BUTTON_X)
    var key_down := Input.is_key_pressed(KEY_Q)
    var down := key_down or pad_down
    var just: bool = down and not ability_was_down[0]
    ability_was_down[0] = down
    return just

func _p2_attack_pressed() -> bool:
    var pads = Input.get_connected_joypads()
    var pad_down := pads.size() > 1 and Input.is_joy_button_pressed(pads[1], JOY_BUTTON_A)
    var key_down := Input.is_key_pressed(KEY_ENTER)
    var down := key_down or pad_down
    var just: bool = down and not attack_was_down[1]
    attack_was_down[1] = down
    return just

func _p2_ability_pressed() -> bool:
    var pads = Input.get_connected_joypads()
    var pad_down := pads.size() > 1 and Input.is_joy_button_pressed(pads[1], JOY_BUTTON_X)
    var key_down := Input.is_key_pressed(KEY_SHIFT)
    var down := key_down or pad_down
    var just: bool = down and not ability_was_down[1]
    ability_was_down[1] = down
    return just

func _p1_dodge_pressed() -> bool:
    var pads = Input.get_connected_joypads()
    var down := Input.is_key_pressed(KEY_E) or (pads.size() > 0 and Input.is_joy_button_pressed(pads[0], JOY_BUTTON_B))
    var just_pressed := down and not dodge_was_down[0]
    dodge_was_down[0] = down
    return just_pressed

func _p2_dodge_pressed() -> bool:
    var pads = Input.get_connected_joypads()
    var down := Input.is_key_pressed(KEY_KP_1) or (pads.size() > 1 and Input.is_joy_button_pressed(pads[1], JOY_BUTTON_B))
    var just_pressed := down and not dodge_was_down[1]
    dodge_was_down[1] = down
    return just_pressed

func _dodge(player: int) -> void:
    if dodge_cd[player] > 0.0:
        return
    dodge_cd[player] = 1.15
    dodge_timer[player] = 0.34
    var direction: Vector2 = facing[player]
    if move_blend[player] > 0.1:
        direction = _keyboard_move_1().normalized() if player == 0 else _keyboard_move_2().normalized()
        if direction.length() < 0.1:
            direction = facing[player]
    if player == 0:
        p1 = _clamp_player(p1 + direction * 118.0)
    else:
        p2 = _clamp_player(p2 + direction * 118.0)
    effects.append({"kind":"dodge_dust", "pos":p1 if player == 0 else p2, "life":0.28, "max":0.28, "color":CHAR_COLORS[char1 if player == 0 else char2]})

func _clamp_player(p: Vector2) -> Vector2:
    return Vector2(clamp(p.x, 235, 1365), clamp(p.y, 270, 690))

func _speed(character: int) -> float:
    return [260.0, 330.0, 270.0, 215.0, 250.0][character]

func _bot_update(delta):
    var dir = p1 - p2
    move_blend[1] = 1.0 if dir.length() > 105.0 else 0.0
    if dir.length() > 105:
        p2 += dir.normalized() * (150 + bot_level * 48) * delta
        facing[1] = dir.normalized()
    elif dir.length() < 65:
        p2 -= dir.normalized() * 90 * delta
    if attack_cd[1] <= 0 and dir.length() < 115: _melee(1)
    if ability_cd[1] <= 0 and dir.length() < 210 and randf() < (0.008 + bot_level * 0.012): _ability(1)
    p2 = _clamp_player(p2)

func _melee(player: int):
    if attack_cd[player] > 0: return
    attack_cd[player] = [0.48, 0.32, 0.55, 0.72, 0.52][char1 if player == 0 else char2]
    attack_flash[player] = 0.22
    attack_anim_timer[player] = 0.34
    attack_anim_duration[player] = 0.34
    if combo_window[player] > 0.0:
        combo_index[player] = (combo_index[player] + 1) % 3
    else:
        combo_index[player] = 0
    combo_window[player] = 0.78
    _play_sfx("sword")
    var attacker = p1 if player == 0 else p2
    var target = p2 if player == 0 else p1
    var dir = (target - attacker).normalized()
    facing[player] = dir
    var reach = [112.0, 88.0, 105.0, 125.0, 118.0][char1 if player == 0 else char2]
    var damage = [16.0, 12.0, 11.0, 23.0, 17.0][char1 if player == 0 else char2]
    damage *= [1.0, 1.12, 1.28][combo_index[player]]
    if _is_dark_prince_empowered(player): damage *= 1.3
    var delta_pos = target - attacker
    if delta_pos.length() <= reach and facing[player].dot(delta_pos.normalized()) > 0.35:
        _damage(1-player, damage)
        _play_sfx("hit")
        var knock_dir: Vector2 = dir
        if 1 - player == 0:
            p1 = _clamp_player(p1 + knock_dir * (24.0 + combo_index[player] * 13.0))
        else:
            p2 = _clamp_player(p2 + knock_dir * (24.0 + combo_index[player] * 13.0))
        hit_stop = maxf(hit_stop, 0.045 if combo_index[player] < 2 else 0.075)
        screen_shake = maxf(screen_shake, 0.10 + combo_index[player] * 0.045)
        effects.append({"kind":"hit","pos":target,"life":0.28,"max":0.28,"color":Color("#ffe2a0")})
        effects.append({"kind":"sparks","pos":target,"dir":dir,"life":0.32,"max":0.32,"color":Color("#ffd28a")})
    effects.append({"kind":"weapon_trail", "weapon":char1 if player == 0 else char2, "pos":attacker+dir*55, "dir":dir.rotated((combo_index[player] - 1) * 0.24), "life":0.28, "max":0.28, "color":CHAR_COLORS[char1 if player == 0 else char2]})

func _ability(player: int):
    if ability_cd[player] > 0: return
    var character = char1 if player == 0 else char2
    var attacker = p1 if player == 0 else p2
    var target = p2 if player == 0 else p1
    var dir = (target-attacker).normalized()
    facing[player] = dir
    ability_cd[player] = [5.0, 4.0, 6.0, 7.0, 30.0][character]
    ability_flash[player] = 0.45
    attack_anim_timer[player] = 0.42
    attack_anim_duration[player] = 0.42
    screen_shake = maxf(screen_shake, 0.12)
    var ability_sounds := ["knight_ability", "rogue_ability", "druid_ability", "guardian_ability", "prince_ability"]
    _play_sfx(ability_sounds[character])
    match character:
        0: # Knight: shielded charge and heavy cleave
            if player == 0: p1 = _clamp_player(p1 + dir*135)
            else: p2 = _clamp_player(p2 + dir*135)
            if (target-attacker).length() < 245: _damage(1-player, 29)
            effects.append({"kind":"weapon_trail", "weapon":character, "pos":attacker+dir*105, "dir":dir, "life":0.45, "max":0.45, "color":Color("#f5c36d")})
        1: # Rogue: quick twin dagger strike
            if (target-attacker).length() < 175: _damage(1-player, 24)
            effects.append({"kind":"weapon_trail", "weapon":character, "pos":attacker+dir*70, "dir":dir.rotated(0.25), "life":0.35, "max":0.35, "color":Color("#80e6cb")})
            effects.append({"kind":"weapon_trail", "weapon":character, "pos":attacker+dir*70, "dir":dir.rotated(-0.25), "life":0.35, "max":0.35, "color":Color("#80e6cb")})
        2: # Druid: root zone
            if (target-attacker).length() < 260:
                roots[1-player] = 1.45
                _damage(1-player, 17)
            effects.append({"kind":"roots","pos":target,"life":0.7,"max":0.7,"color":Color("#a8d96c")})
        3: # Guardian: ground slam
            if (target-attacker).length() < 205: _damage(1-player, 34)
            effects.append({"kind":"slam","pos":attacker,"life":0.55,"max":0.55,"color":Color("#f1bd65")})
        4: # Dark Prince: ten-second shadow dominion
            _play_sfx("shadow")
            var zone_center = attacker.lerp(target, 0.42)
            dark_zones[player] = {"center": zone_center, "radius": 285.0, "life": 10.0}
            dark_zone_ticks[player] = 0.25
            status_text = "ABYSS DOMINION • ВЛАДЕНИЯ БЕЗДНЫ"
            effects.append({"kind":"shadow_burst","pos":zone_center,"life":0.9,"max":0.9,"color":Color("#9b72d6")})

func _is_dark_prince_empowered(player: int) -> bool:
    var character = char1 if player == 0 else char2
    if character != 4 or dark_zones[player].is_empty(): return false
    if float(dark_zones[player].get("life", 0.0)) <= 0.0: return false
    var pos = p1 if player == 0 else p2
    return pos.distance_to(dark_zones[player].center) <= float(dark_zones[player].radius)

func _update_dark_zones(delta: float):
    for owner in range(2):
        if dark_zones[owner].is_empty(): continue
        dark_zones[owner].life = max(0.0, float(dark_zones[owner].life) - delta)
        dark_zone_ticks[owner] -= delta
        if dark_zones[owner].life <= 0.0:
            var ending_center: Vector2 = dark_zones[owner].center
            _play_sfx("shadow_end")
            effects.append({"kind":"shadow_burst","pos":ending_center,"life":0.55,"max":0.55,"color":Color("#7650a8")})
            dark_zones[owner] = {}
            continue
        if dark_zone_ticks[owner] <= 0.0:
            dark_zone_ticks[owner] = 0.7
            var center: Vector2 = dark_zones[owner].center
            var radius: float = dark_zones[owner].radius
            var enemy = p2 if owner == 0 else p1
            for n in range(8):
                var angle = TAU * float(n) / 8.0
                var tentacle_pos = center + Vector2(cos(angle), sin(angle)) * radius * 0.68
                if enemy.distance_to(tentacle_pos) < 43.0:
                    _damage(1-owner, 5.0)
                    _play_sfx("tentacle")
                    effects.append({"kind":"hit","pos":enemy,"life":0.2,"max":0.2,"color":Color("#a77be8")})
                    break

func _damage(player: int, amount: float):
    if block_active[player]:
        amount *= 0.42
        effects.append({"kind":"block_sparks", "pos":p1 if player == 0 else p2, "life":0.24, "max":0.24, "color":Color("#8bd7ff")})
    if player == 0:
        hp1 = max(0.0, hp1-amount)
    else:
        hp2 = max(0.0, hp2-amount)
    hurt_anim_timer[player] = 0.24
    screen_shake = maxf(screen_shake, 0.075)

func _update_effects(delta):
    for i in range(effects.size()-1,-1,-1):
        effects[i].life -= delta
        if effects[i].life <= 0: effects.remove_at(i)

func _update_hud():
    hp1_bar.value = hp1
    hp2_bar.value = hp2
    timer_label.text = "%02d:%02d" % [int(round_time/60), int(round_time)%60]
    var p1_name := game_layer.find_child("PlayerOneName", true, false) as Label
    var p2_name := game_layer.find_child("PlayerTwoName", true, false) as Label
    if p1_name: p1_name.text = CHAR_NAMES[char1].to_upper()
    if p2_name: p2_name.text = CHAR_NAMES[char2].to_upper()
    portrait1.texture = CHAR_PORTRAITS[char1]
    portrait2.texture = CHAR_PORTRAITS[char2]
    var p1_cd := "ГОТОВО" if ability_cd[0] <= 0.0 else "%.1f СЕК" % ability_cd[0]
    var p2_cd := "ГОТОВО" if ability_cd[1] <= 0.0 else "%.1f СЕК" % ability_cd[1]
    skill1_label.text = "SPACE УДАР  •  Q СПОСОБНОСТЬ  •  E УКЛОНЕНИЕ  •  R БЛОК  |  " + p1_cd
    skill2_label.text = "ENTER УДАР  •  SHIFT СПОСОБНОСТЬ  •  KP1 УКЛОНЕНИЕ  •  KP0 БЛОК  |  " + p2_cd

func _send_remote_state():
    net_send_timer += get_process_delta_time()
    if net_send_timer > 0.05:
        net_send_timer = 0
        rpc_id(1, "_receive_remote_position", p1)

@rpc("any_peer","call_remote","unreliable")
func _receive_remote_position(pos: Vector2):
    if multiplayer.is_server(): p2 = _clamp_player(pos)

func _draw():
    if mode == Mode.MENU:
        _draw_menu_backdrop()
        return
    draw_offset = Vector2(sin(visual_time * 47.0), cos(visual_time * 39.0) * 0.7) * screen_shake * 13.0
    draw_set_transform(draw_offset, 0.0, Vector2.ONE)
    draw_texture_rect(ARENA, Rect2(0,0,1600,900), false)
    _draw_arena_ambience()
    if campaign_active:
        _draw_campaign_arena_tint()
        if campaign_event_warning > 0.0:
            var warn_color := _campaign_event_color()
            var pulse := 1.0 + 0.12 * sin(visual_time * 13.0)
            draw_circle(campaign_event_pos, 78.0 * pulse, Color(warn_color.r, warn_color.g, warn_color.b, 0.16))
            draw_arc(campaign_event_pos, 78.0 * pulse, 0, TAU, 48, warn_color, 7.0)
        if campaign_event_flash > 0.0:
            var flash_ratio := campaign_event_flash / 0.45
            draw_circle(campaign_event_pos, 120.0 * (1.0 - flash_ratio) + 25.0, Color(0.8, 0.7, 1.0, 0.22 * flash_ratio))
            draw_arc(campaign_event_pos, 120.0 * (1.0 - flash_ratio) + 25.0, 0, TAU, 48, _campaign_event_color(), 8.0)
    for owner in range(2):
        if not dark_zones[owner].is_empty():
            var zc: Vector2 = dark_zones[owner].center
            var zr: float = dark_zones[owner].radius
            var fade = clamp(float(dark_zones[owner].life) / 1.2, 0.0, 1.0)
            draw_circle(zc, zr, Color(0.035,0.018,0.075,0.56*fade))
            draw_arc(zc, zr, 0, TAU, 80, Color(0.48,0.25,0.78,0.8*fade), 7)
            for n in range(8):
                var angle = TAU * float(n) / 8.0
                var base = zc + Vector2(cos(angle),sin(angle))*zr*0.68
                var tangent = Vector2(-sin(angle), cos(angle))
                var points := PackedVector2Array()
                for segment in range(9):
                    var t := float(segment) / 8.0
                    var sway := sin(visual_time * 3.1 + float(n) * 1.7 + t * 4.0) * 24.0 * t
                    var reach := 42.0 + 42.0 * sin(visual_time * 1.8 + float(n))
                    points.append(base + Vector2(cos(angle+0.45),sin(angle+0.45))*reach*t + tangent*sway)
                draw_polyline(points, Color(0.055,0.025,0.095,0.96*fade), 20.0, true)
                draw_polyline(points, Color(0.48,0.25,0.72,0.9*fade), 5.0, true)
                draw_circle(points[8], 8.0, Color(0.75,0.56,1.0,0.9*fade))
    # Soft contact shadows anchor the illustrated fighters to the arena floor.
    draw_circle(p1 + Vector2(0, 132), 43, Color(0.015, 0.012, 0.018, 0.58))
    draw_circle(p2 + Vector2(0, 132), 43, Color(0.015, 0.012, 0.018, 0.58))
    if char1 == 4:
        _draw_prince_aura(p1)
    if char2 == 4:
        _draw_prince_aura(p2)
    _draw_fighter(p1, 0)
    _draw_fighter(p2, 1)
    if _is_dark_prince_empowered(0):
        draw_arc(p1, 76, 0, TAU, 48, Color("#bd91ff"), 5)
    if _is_dark_prince_empowered(1):
        draw_arc(p2, 76, 0, TAU, 48, Color("#bd91ff"), 5)
    for pr in projectiles:
        draw_circle(pr.pos,14,Color("#ffbd62"))
    for fx in effects:
        var ratio = fx.life/fx.max
        if fx.kind == "weapon_trail":
            var d: Vector2 = fx.dir.normalized()
            var side: Vector2 = d.orthogonal()
            var c: Color = fx.color
            var weapon_id: int = int(fx.get("weapon", 0))
            var fade: float = ratio
            var length: float = [108.0, 72.0, 96.0, 88.0, 122.0][weapon_id]
            var start: Vector2 = fx.pos - d * 24.0
            var finish: Vector2 = fx.pos + d * length * (1.0 - ratio * 0.12)
            match weapon_id:
                0: # Knight — one clean steel sword stroke
                    draw_line(start + side * 15.0, finish, Color(0.40, 0.72, 1.0, fade * 0.38), 13.0 * fade + 1.0, true)
                    draw_line(start + side * 7.0, finish, Color(0.88, 0.95, 1.0, fade), 5.0 * fade + 1.0, true)
                    draw_line(start + side * 3.0, finish, Color(1.0, 1.0, 1.0, fade), 1.8, true)
                1: # Rogue — two short crossing dagger cuts
                    draw_line(start + side * 18.0, finish - side * 12.0, Color(0.95, 0.34, 0.30, fade), 5.0 * fade + 1.0, true)
                    draw_line(start - side * 18.0, finish + side * 12.0, Color(1.0, 0.76, 0.60, fade), 4.0 * fade + 1.0, true)
                2: # Druid — leaf-shaped motes along the staff sweep
                    draw_line(start, finish, Color(0.45, 0.78, 0.30, fade * 0.5), 4.0 * fade + 1.0, true)
                    for leaf in range(5):
                        var leaf_pos: Vector2 = start.lerp(finish, float(leaf + 1) / 6.0) + side * sin(float(leaf) * 2.1) * 16.0
                        draw_colored_polygon(PackedVector2Array([leaf_pos, leaf_pos + d * 10.0 + side * 4.0, leaf_pos + d * 19.0, leaf_pos - side * 4.0]), Color(0.64, 0.90, 0.36, fade))
                3: # Guardian — heavy hammer impact line and ground sparks
                    draw_line(start, finish, Color(0.55, 0.78, 1.0, fade * 0.65), 10.0 * fade + 1.0, true)
                    for spark in range(5):
                        var spark_pos: Vector2 = finish + side * (float(spark) - 2.0) * 10.0
                        draw_line(spark_pos, spark_pos + Vector2(0.0, 15.0 + float(spark % 2) * 9.0), Color(1.0, 0.78, 0.38, fade), 3.0, true)
                4: # Dark Prince — jagged void blade with violet core
                    draw_line(start + side * 18.0, finish, Color(0.38, 0.10, 0.68, fade * 0.6), 16.0 * fade + 1.0, true)
                    draw_line(start + side * 7.0, finish - side * 5.0, Color(0.78, 0.48, 1.0, fade), 6.0 * fade + 1.0, true)
                    draw_line(start, finish, Color(0.12, 0.04, 0.22, fade), 2.0, true)
        elif fx.kind == "block_sparks":
            for spark in range(7):
                var a: float = TAU * float(spark) / 7.0
                var ray: Vector2 = Vector2(cos(a), sin(a))
                draw_line(fx.pos + ray * 16.0, fx.pos + ray * (28.0 + 22.0 * (1.0 - ratio)), Color(0.55, 0.82, 1.0, ratio), 3.0, true)
        elif fx.kind == "dodge_dust":
            for puff in range(5):
                var puff_pos: Vector2 = fx.pos + Vector2(-28.0 + puff * 14.0, 28.0 + sin(float(puff)) * 7.0)
                draw_circle(puff_pos, (8.0 + puff * 1.5) * ratio, Color(0.62, 0.57, 0.50, ratio * 0.36))
        elif fx.kind == "hit":
            var burst_radius: float = 12.0 + 24.0 * (1.0 - ratio)
            for ray in range(8):
                var ray_dir := Vector2.RIGHT.rotated(TAU * float(ray) / 8.0)
                draw_line(fx.pos + ray_dir * 3.0, fx.pos + ray_dir * burst_radius, Color(1.0, 0.78, 0.36, ratio), 3.0 * ratio + 0.5, true)
        elif fx.kind == "sparks":
            var spark_dir: Vector2 = fx.dir
            for spark in range(7):
                var angle: float = -0.9 + float(spark) * 0.3
                var ray_dir: Vector2 = spark_dir.rotated(angle)
                var start: Vector2 = fx.pos + ray_dir * (7.0 + float(spark % 3) * 3.0)
                draw_line(start, start + ray_dir * (18.0 + 24.0 * (1.0 - ratio)), Color(1.0, 0.72 + 0.2 * ratio, 0.38, ratio), 2.0, true)
        elif fx.kind == "roots":
            for a in range(8):
                var angle = TAU*a/8
                draw_line(fx.pos,fx.pos+Vector2(cos(angle),sin(angle))*78*(1-ratio*0.35),Color(0.55,0.78,0.32,ratio),8)
        elif fx.kind == "slam":
            var crack_length: float = 82.0 * (1.0 - ratio * 0.25)
            for crack in range(10):
                var crack_dir := Vector2.RIGHT.rotated(TAU * float(crack) / 10.0)
                var start: Vector2 = fx.pos + crack_dir * 12.0
                var finish: Vector2 = fx.pos + crack_dir * crack_length
                draw_line(start, finish, Color(0.98, 0.66, 0.27, ratio * 0.9), 5.0 * ratio + 1.0, true)
                draw_line(start + crack_dir.orthogonal() * 4.0, finish + crack_dir.orthogonal() * 4.0, Color(0.28, 0.18, 0.12, ratio * 0.8), 2.0, true)
        elif fx.kind == "shadow_burst":
            draw_circle(fx.pos, 260*(1-ratio)+30, Color(0.22,0.10,0.38,0.28*ratio))
            draw_arc(fx.pos, 260*(1-ratio)+30, 0, TAU, 64, Color(0.68,0.42,0.95,ratio), 10)
    draw_string(ThemeDB.fallback_font,Vector2(460,850),status_text,HORIZONTAL_ALIGNMENT_CENTER,700,18,Color("#fff0d0"))
    if roots[0] > 0: draw_string(ThemeDB.fallback_font,p1+Vector2(-25,-70),"ROOTED",HORIZONTAL_ALIGNMENT_CENTER,100,14,Color("#b4e47d"))
    if roots[1] > 0: draw_string(ThemeDB.fallback_font,p2+Vector2(-25,-70),"ROOTED",HORIZONTAL_ALIGNMENT_CENTER,100,14,Color("#b4e47d"))
    for fighter in range(2):
        if combo_window[fighter] > 0.0 and combo_index[fighter] > 0:
            var combo_pos: Vector2 = p1 if fighter == 0 else p2
            draw_string(ThemeDB.fallback_font, combo_pos + Vector2(-28, -176), "КОМБО  x%d" % (combo_index[fighter] + 1), HORIZONTAL_ALIGNMENT_CENTER, 140, 15, Color("#ffd58e"))


func _draw_fighter(center: Vector2, player: int) -> void:
    var character: int = char1 if player == 0 else char2
    var moving: bool = move_blend[player] > 0.12
    var row: int = 0
    var frame: int = 0
    if dodge_timer[player] > 0.0:
        row = 4
        frame = clampi(int((0.34 - dodge_timer[player]) / 0.34 * 4.0), 0, 3)
    elif block_active[player]:
        row = 5
        frame = int(fighter_anim_time[player] * 8.0) % 4
    elif attack_anim_timer[player] > 0.0:
        row = 2
        frame = clampi(int((1.0 - attack_anim_timer[player] / maxf(0.01, attack_anim_duration[player])) * 4.0), 0, 3)
    elif hurt_anim_timer[player] > 0.0:
        row = 3
        frame = clampi(int((1.0 - hurt_anim_timer[player] / 0.24) * 4.0), 0, 3)
    elif moving:
        row = 1
        frame = int(fighter_anim_time[player] * (14.0 if move_blend[player] > 0.82 else 9.0)) % 4
    else:
        row = 0
        frame = int(fighter_anim_time[player] * 2.2) % 4

    var bob: float = sin(fighter_anim_time[player] * (8.0 if moving else 2.2)) * (2.8 if moving else 1.3)
    if dodge_timer[player] > 0.0:
        bob += 4.0
    var hurt_ratio: float = clampf(hurt_anim_timer[player] / 0.24, 0.0, 1.0)
    var side_sign: float = -1.0 if facing[player].x < 0.0 else 1.0
    var lean: float = clampf(facing[player].angle() * 0.08, -0.12, 0.12) * move_blend[player]
    var attack_ratio: float = clampf(attack_anim_timer[player] / maxf(0.01, attack_anim_duration[player]), 0.0, 1.0)
    var attack_ease: float = sin((1.0 - attack_ratio) * PI)
    var lunge: Vector2 = facing[player] * attack_ease * (20.0 if character == 1 else 13.0)
    var draw_center: Vector2 = center + draw_offset + Vector2(0.0, bob) + lunge + Vector2(-side_sign * hurt_ratio * 8.0, 0.0)
    var target_height: float = 320.0 if character == 3 else 310.0
    var target_width: float = target_height * (256.0 / 384.0)
    var flip: float = -1.0 if facing[player].x < 0.0 else 1.0
    var pose_rotation: float = lean - side_sign * attack_ease * 0.035 - side_sign * hurt_ratio * 0.08
    draw_set_transform(draw_center, pose_rotation, Vector2(flip, 1.0))
    var tint: Color = Color(1.0, 0.78, 0.78, 1.0) if hurt_ratio > 0.0 else Color.WHITE
    var atlas_region := Rect2(frame * 256, row * 384, 256, 384)
    draw_texture_rect_region(CHAR_ANIM_SHEETS[character], Rect2(-target_width * 0.5, -target_height * 0.5, target_width, target_height), atlas_region, false, tint)
    draw_set_transform(draw_offset, 0.0, Vector2.ONE)
    _draw_character_weapon(character, draw_center, player, attack_ease)
    if hurt_ratio > 0.0:
        draw_circle(draw_center + Vector2(0.0, -target_height * 0.36), 5.0 + hurt_ratio * 4.0, Color(1.0, 0.35, 0.25, hurt_ratio * 0.55))
    if block_active[player]:
        draw_arc(draw_center + Vector2(0.0, -20.0), 76.0, -1.15, 1.15, 24, Color(0.35, 0.72, 1.0, 0.78), 4.0, true)

func _draw_character_weapon(character: int, body_center: Vector2, player: int, attack_ease: float) -> void:
    var facing_angle: float = facing[player].angle()
    var swing: float = sin(attack_ease * PI)
    var base_rotation: float = facing_angle + PI * 0.5
    var hand: Vector2 = body_center + Vector2((1.0 if facing[player].x >= 0.0 else -1.0) * 32.0, -34.0)
    var weapon_rotation: float = base_rotation
    if attack_anim_timer[player] > 0.0:
        weapon_rotation += [-1.05, 1.15, -0.65, 1.3, 1.45][character] * swing
    elif move_blend[player] > 0.1:
        weapon_rotation += sin(fighter_anim_time[player] * 9.0) * 0.09
    match character:
        0: # Knight — longsword
            draw_set_transform(hand, weapon_rotation, Vector2(0.58, 0.58))
            draw_texture_rect(WEAPON_TEXTURES[0], Rect2(-64.0, -154.0, 128.0, 154.0), false)
        1: # Rogue — twin daggers, independently angled
            draw_set_transform(hand + Vector2(-18.0, 2.0), weapon_rotation - 0.34 - swing * 0.45, Vector2(0.32, 0.32))
            draw_texture_rect(WEAPON_TEXTURES[1], Rect2(-64.0, -154.0, 128.0, 154.0), false)
            draw_set_transform(hand + Vector2(19.0, 0.0), weapon_rotation + 0.34 + swing * 0.45, Vector2(0.32, 0.32))
            draw_texture_rect(WEAPON_TEXTURES[1], Rect2(-64.0, -154.0, 128.0, 154.0), false)
        2: # Druid — rune staff
            draw_set_transform(hand + Vector2(5.0, -10.0), weapon_rotation + sin(fighter_anim_time[player] * 2.0) * 0.04, Vector2(0.48, 0.48))
            draw_texture_rect(WEAPON_TEXTURES[2], Rect2(-64.0, -210.0, 128.0, 210.0), false)
        3: # Guardian — war hammer and shield
            draw_set_transform(hand, weapon_rotation + swing * 0.65, Vector2(0.53, 0.53))
            draw_texture_rect(WEAPON_TEXTURES[3], Rect2(-64.0, -170.0, 128.0, 170.0), false)
            draw_set_transform(body_center + Vector2(-42.0 if facing[player].x > 0.0 else 42.0, -18.0), facing_angle + PI * 0.5, Vector2(0.42, 0.42))
            draw_texture_rect(GUARDIAN_SHIELD, Rect2(-64.0, -110.0, 128.0, 110.0), false)
        4: # Dark Prince — void greatblade
            draw_set_transform(hand, weapon_rotation + swing * 1.2, Vector2(0.60, 0.60))
            draw_texture_rect(WEAPON_TEXTURES[4], Rect2(-64.0, -176.0, 128.0, 176.0), false)
    draw_set_transform(draw_offset, 0.0, Vector2.ONE)


func _update_campaign_event(delta: float) -> void:
    if not campaign_active:
        return
    campaign_event_flash = max(0.0, campaign_event_flash - delta)
    if campaign_event_ready:
        campaign_event_warning = max(0.0, campaign_event_warning - delta)
        if campaign_event_warning <= 0.0:
            _resolve_campaign_event()
            campaign_event_ready = false
            campaign_event_timer = [7.5, 8.0, 7.0, 8.5, 6.5][campaign_chapter]
        return
    campaign_event_timer -= delta
    if campaign_event_timer <= 0.0:
        campaign_event_pos = Vector2(randf_range(340.0, 1260.0), randf_range(350.0, 650.0))
        campaign_event_warning = 1.35
        campaign_event_ready = true
        _play_sfx("magic")

func _resolve_campaign_event() -> void:
    campaign_event_flash = 0.45
    var dist1 := p1.distance_to(campaign_event_pos)
    var dist2 := p2.distance_to(campaign_event_pos)
    match campaign_chapter:
        0: # Falling masonry in the ruined fortress.
            if dist1 < 88.0: _damage(0, 12.0)
            if dist2 < 88.0: _damage(1, 12.0)
            effects.append({"kind":"slam", "pos":campaign_event_pos, "life":0.55, "max":0.55, "color":Color("#d59a63")})
        1: # The seal sends a short-range pulse.
            if dist1 < 170.0: _damage(0, 9.0)
            if dist2 < 170.0: _damage(1, 9.0)
            effects.append({"kind":"shadow_burst", "pos":campaign_event_pos, "life":0.7, "max":0.7, "color":Color("#d7b56d")})
        2: # Cursed roots briefly hold anyone caught in the patch.
            if dist1 < 105.0:
                roots[0] = max(roots[0], 1.25)
                _damage(0, 6.0)
            if dist2 < 105.0:
                roots[1] = max(roots[1], 1.25)
                _damage(1, 6.0)
            effects.append({"kind":"roots", "pos":campaign_event_pos, "life":0.8, "max":0.8, "color":Color("#9cc76a")})
        3: # The ancient oath releases a defensive shockwave.
            if dist1 < 145.0: _damage(0, 10.0)
            if dist2 < 145.0: _damage(1, 10.0)
            effects.append({"kind":"slam", "pos":campaign_event_pos, "life":0.6, "max":0.6, "color":Color("#e0bd79")})
        4: # The rift surges unpredictably around its focal point.
            if dist1 < 190.0: _damage(0, 14.0)
            if dist2 < 190.0: _damage(1, 14.0)
            effects.append({"kind":"shadow_burst", "pos":campaign_event_pos, "life":0.9, "max":0.9, "color":Color("#9d73d8")})
    _play_sfx("hit")

func _campaign_event_color() -> Color:
    return [Color("#d58b58"), Color("#d5b56e"), Color("#8dbb63"), Color("#d6c18b"), Color("#a47ad8")][campaign_chapter]

func _draw_campaign_arena_tint() -> void:
    var tint: Color = [Color(0.28,0.08,0.035,0.10), Color(0.28,0.22,0.08,0.10), Color(0.08,0.22,0.07,0.12), Color(0.22,0.18,0.10,0.10), Color(0.16,0.06,0.28,0.14)][campaign_chapter]
    draw_rect(Rect2(0,0,1600,900), tint)
    if campaign_chapter == 2:
        for i in range(5):
            var mist_x := fposmod(float(i) * 370.0 + visual_time * 13.0, 1900.0) - 150.0
            draw_circle(Vector2(mist_x, 600.0 + sin(visual_time + i) * 28.0), 110.0, Color(0.36,0.58,0.28,0.055))
    elif campaign_chapter == 4:
        for i in range(5):
            var ray_angle := visual_time * 0.06 + TAU * float(i) / 5.0
            var ray_end := Vector2(800, 460) + Vector2(cos(ray_angle), sin(ray_angle)) * 520.0
            draw_line(Vector2(800, 460), ray_end, Color(0.52,0.25,0.78,0.10), 22.0)

func _load_campaign_progress() -> void:
    if not FileAccess.file_exists(CAMPAIGN_SAVE):
        campaign_unlocked = 0
        return
    var file := FileAccess.open(CAMPAIGN_SAVE, FileAccess.READ)
    if file:
        campaign_unlocked = clampi(int(file.get_32()), 0, 4)

func _save_campaign_progress() -> void:
    var file := FileAccess.open(CAMPAIGN_SAVE, FileAccess.WRITE)
    if file:
        file.store_32(campaign_unlocked)

func _start_campaign() -> void:
    _load_campaign_progress()
    if campaign_select_dialog:
        campaign_select_dialog.popup_centered()

func _build_campaign_dialog() -> void:
    campaign_select_dialog = AcceptDialog.new()
    campaign_select_dialog.title = "Хроники Пепельного Королевства"
    campaign_select_dialog.dialog_text = "Выбери открытую главу. Пройденные главы можно переигрывать."
    campaign_select_dialog.min_size = Vector2i(620, 470)
    campaign_select_dialog.confirmed.connect(_back_menu)
    campaign_select_dialog.close_requested.connect(_back_menu)
    menu_layer.add_child(campaign_select_dialog)
    var list := VBoxContainer.new()
    list.name = "ChapterList"
    list.custom_minimum_size = Vector2(560, 390)
    campaign_select_dialog.add_child(list)
    for i in range(CAMPAIGN_NAMES.size()):
        var chapter_button := Button.new()
        chapter_button.text = ("✓  " if i < campaign_unlocked else ("▶  " if i == campaign_unlocked else "🔒  ")) + CAMPAIGN_NAMES[i]
        chapter_button.custom_minimum_size = Vector2(0, 48)
        chapter_button.disabled = i > campaign_unlocked
        chapter_button.pressed.connect(_play_sfx.bind("button"))
        chapter_button.pressed.connect(_launch_campaign_chapter.bind(i))
        list.add_child(chapter_button)

func _refresh_campaign_chapters() -> void:
    if not campaign_select_dialog:
        _build_campaign_dialog()
        return
    var list := campaign_select_dialog.get_node("ChapterList") as VBoxContainer
    for i in range(list.get_child_count()):
        var b := list.get_child(i) as Button
        b.text = ("✓  " if i < campaign_unlocked else ("▶  " if i == campaign_unlocked else "🔒  ")) + CAMPAIGN_NAMES[i]
        b.disabled = i > campaign_unlocked

func _launch_campaign_chapter(chapter: int) -> void:
    if chapter > campaign_unlocked:
        return
    campaign_chapter = chapter
    bot_level = 1 if chapter < 2 else 2
    char1 = chapter
    char2 = CAMPAIGN_ENEMIES[chapter]
    char1_option.select(char1)
    char2_option.select(char2)
    campaign_active = true
    campaign_result_handled = false
    campaign_pending_result = false
    campaign_event_timer = 3.5
    campaign_event_warning = 0.0
    campaign_event_ready = false
    campaign_event_flash = 0.0
    campaign_select_dialog.hide()
    _play_music("story")
    campaign_story_dialog.dialog_text = "ГЛАВА " + str(chapter + 1) + " • " + CAMPAIGN_NAMES[chapter] + "\n\n" + CAMPAIGN_DESCRIPTIONS[chapter] + "\n\n" + CAMPAIGN_INTROS[chapter] + "\n\nПротивник: " + CHAR_NAMES[char2] + "\nЦель: " + CAMPAIGN_GOALS[chapter] + "\nНаграда: " + CAMPAIGN_REWARDS[chapter]
    campaign_story_dialog.set_meta("story_phase", "intro")
    campaign_story_dialog.popup_centered()

func _begin_campaign_battle() -> void:
    campaign_story_dialog.hide()
    _start_game(Mode.BOT)
    status_text = "КАМПАНИЯ • " + CAMPAIGN_NAMES[campaign_chapter]
    _play_sfx("boss")

func _show_campaign_result() -> void:
    if not campaign_active or not campaign_pending_result:
        return
    campaign_story_dialog.dialog_text = "ГЛАВА ПРОЙДЕНА\n\n" + CAMPAIGN_OUTROS[campaign_chapter] + "\n\nНаграда: " + CAMPAIGN_REWARDS[campaign_chapter]
    campaign_story_dialog.set_meta("story_phase", "outro")
    _play_music("story")
    campaign_story_dialog.popup_centered()

func _show_campaign_fail() -> void:
    if not campaign_active or not campaign_pending_result:
        return
    campaign_story_dialog.dialog_text = "ПОРАЖЕНИЕ\n\nГлава не пройдена. История и открытые главы сохранены. Можно попробовать ещё раз или вернуться к выбору глав."
    campaign_story_dialog.set_meta("story_phase", "retry")
    campaign_story_dialog.popup_centered()

func _campaign_story_confirmed() -> void:
    var phase := str(campaign_story_dialog.get_meta("story_phase", "intro"))
    campaign_story_dialog.hide()
    if phase == "intro":
        _begin_campaign_battle()
    elif phase == "outro":
        campaign_pending_result = false
        _refresh_campaign_chapters()
        campaign_select_dialog.popup_centered()
    elif phase == "retry":
        campaign_pending_result = false
        _refresh_campaign_chapters()
        campaign_select_dialog.popup_centered()

func _build_settings_dialog() -> void:
    settings_dialog = AcceptDialog.new()
    settings_dialog.title = "Настройки звука"
    settings_dialog.dialog_text = "Громкость музыки и звуковых эффектов"
    settings_dialog.min_size = Vector2i(560, 390)
    menu_layer.add_child(settings_dialog)
    var content := VBoxContainer.new()
    content.custom_minimum_size = Vector2(480, 270)
    settings_dialog.add_child(content)
    var music_label := Label.new()
    music_label.text = "Музыка"
    content.add_child(music_label)
    var music_slider := HSlider.new()
    music_slider.min_value = 0.0
    music_slider.max_value = 1.0
    music_slider.step = 0.01
    music_slider.value = music_volume
    music_slider.value_changed.connect(func(value: float):
        music_volume = value
        _apply_volume()
        _save_audio_settings()
    )
    content.add_child(music_slider)
    var sfx_label := Label.new()
    sfx_label.text = "Звуковые эффекты"
    content.add_child(sfx_label)
    var sfx_slider := HSlider.new()
    sfx_slider.min_value = 0.0
    sfx_slider.max_value = 1.0
    sfx_slider.step = 0.01
    sfx_slider.value = sfx_volume
    sfx_slider.value_changed.connect(func(value: float):
        sfx_volume = value
        _apply_volume()
        _save_audio_settings()
    )
    content.add_child(sfx_slider)
    var controls_title := Label.new()
    controls_title.text = "УПРАВЛЕНИЕ"
    controls_title.add_theme_font_size_override("font_size", 18)
    content.add_child(controls_title)
    var controls := Label.new()
    controls.text = "Игрок 1: WASD • Space / A — атака • Q / X — способность\nИгрок 2: стрелки • Enter / A — атака • Shift / X — способность\nГеймпад: левый стик — движение; A — атака; X — способность\nПервый подключённый контроллер — P1, второй — P2."
    controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    content.add_child(controls)
    var note := Label.new()
    note.text = "Музыка и эффекты созданы специально для этой версии проекта."
    note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    content.add_child(note)

func _open_settings() -> void:
    settings_dialog.popup_centered()

func _setup_audio_buses() -> void:
    # Dedicated buses keep the generated music and sound effects independent.
    if AudioServer.get_bus_index("Music") < 0:
        AudioServer.add_bus()
        var music_bus := AudioServer.bus_count - 1
        AudioServer.set_bus_name(music_bus, "Music")
        AudioServer.set_bus_send(music_bus, "Master")
    if AudioServer.get_bus_index("SFX") < 0:
        AudioServer.add_bus()
        var sfx_bus := AudioServer.bus_count - 1
        AudioServer.set_bus_name(sfx_bus, "SFX")
        AudioServer.set_bus_send(sfx_bus, "Master")
    _apply_volume()

func _apply_volume() -> void:
    var music_bus := AudioServer.get_bus_index("Music")
    var sfx_bus := AudioServer.get_bus_index("SFX")
    if music_bus >= 0:
        AudioServer.set_bus_volume_db(music_bus, linear_to_db(max(0.001, music_volume)))
    if sfx_bus >= 0:
        AudioServer.set_bus_volume_db(sfx_bus, linear_to_db(max(0.001, sfx_volume)))


func _play_music(track: String) -> void:
    if not music_player:
        music_player = AudioStreamPlayer.new()
        music_player.bus = "Music"
        add_child(music_player)
    var stream := load(AUDIO_FILES.get(track, AUDIO_FILES["menu"])) as AudioStreamWAV
    if stream:
        stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
        music_player.stream = stream
        music_player.play()

func _play_sfx(effect_name: String) -> void:
    var stream := load(AUDIO_FILES.get(effect_name, AUDIO_FILES["button"])) as AudioStream
    if not stream:
        return
    var player := AudioStreamPlayer.new()
    player.bus = "SFX"
    player.stream = stream
    add_child(player)
    player.finished.connect(player.queue_free)
    player.play()

func _play_button_and_action(action: Callable) -> void:
    _play_sfx("button")
    action.call()

func _seed_embers() -> void:
    for i in range(52):
        ember_particles.append({
            "pos": Vector2(randf_range(0, 1600), randf_range(0, 900)),
            "speed": randf_range(8, 28),
            "drift": randf_range(-9, 9),
            "size": randf_range(1.0, 3.0),
            "alpha": randf_range(0.18, 0.65)
        })

func _update_embers(delta: float) -> void:
    for i in range(ember_particles.size()):
        var particle: Dictionary = ember_particles[i]
        var pos: Vector2 = particle.pos
        pos.y -= float(particle.speed) * delta
        pos.x += sin(visual_time * 0.8 + float(i)) * float(particle.drift) * delta
        if pos.y < -10:
            pos.y = 910
            pos.x = randf_range(0, 1600)
        particle.pos = pos
        ember_particles[i] = particle

func _draw_menu_backdrop() -> void:
    draw_texture_rect(MENU_BACKDROP, Rect2(0, 0, 1600, 900), false)
    # Dark cinematic overlay keeps menu labels readable while preserving the supplied artwork.
    draw_rect(Rect2(0, 0, 1600, 900), Color(0.018, 0.022, 0.045, 0.28))
    draw_rect(Rect2(0, 0, 1600, 900), Color(0.0, 0.0, 0.0, 0.08))
    for i in range(7):
        var fx := fposmod(float(i) * 260.0 + visual_time * 18.0, 1900.0) - 150.0
        draw_circle(Vector2(fx, 660 + sin(visual_time * 0.35 + i) * 25), 95, Color(0.55, 0.60, 0.72, 0.055))
    for particle in ember_particles:
        var pos: Vector2 = particle.pos
        draw_circle(pos, float(particle.size), Color(1.0, 0.58, 0.22, float(particle.alpha)))
    draw_rect(Rect2(0, 0, 1600, 900), Color(0, 0, 0, 0.05))

func _draw_arena_ambience() -> void:
    var torch_positions := [Vector2(350, 150), Vector2(1250, 150), Vector2(350, 650), Vector2(1250, 650)]
    for i in range(torch_positions.size()):
        var torch_pos: Vector2 = torch_positions[i]
        var flicker := 1.0 + 0.14 * sin(visual_time * 13.0 + float(i) * 2.1)
        draw_circle(torch_pos, 92.0 * flicker, Color(1.0, 0.58, 0.2, 0.055))
        draw_circle(torch_pos, 32.0 * flicker, Color(1.0, 0.66, 0.28, 0.10))
    for i in range(ember_particles.size()):
        if i % 3 != 0:
            continue
        var particle: Dictionary = ember_particles[i]
        var pos: Vector2 = particle.pos
        var alpha := float(particle.alpha) * 0.35
        draw_circle(pos, float(particle.size) * 0.7, Color(0.92, 0.68, 0.38, alpha))

func _draw_prince_aura(pos: Vector2) -> void:
    var pulse := 1.0 + 0.08 * sin(visual_time * 5.0)
    draw_circle(pos + Vector2(0, 12), 86 * pulse, Color(0.12,0.035,0.2,0.22))
    for i in range(6):
        var angle := visual_time * (0.45 if i % 2 == 0 else -0.35) + TAU * float(i) / 6.0
        var start := pos + Vector2(cos(angle), sin(angle)) * 48
        var end := pos + Vector2(cos(angle+0.5), sin(angle+0.5)) * (92 + 10*sin(visual_time*3+i))
        draw_line(start, end, Color(0.38,0.16,0.58,0.42), 7)


func _load_audio_settings() -> void:
    var config := ConfigFile.new()
    if config.load("user://settings.cfg") == OK:
        music_volume = clampf(float(config.get_value("audio", "music", 0.75)), 0.0, 1.0)
        sfx_volume = clampf(float(config.get_value("audio", "sfx", 0.85)), 0.0, 1.0)

func _save_audio_settings() -> void:
    var config := ConfigFile.new()
    config.set_value("audio", "music", music_volume)
    config.set_value("audio", "sfx", sfx_volume)
    config.save("user://settings.cfg")
