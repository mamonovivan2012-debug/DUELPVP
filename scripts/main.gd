extends Node2D

const ARENA = preload("res://assets/arena.png")
const CHAR_TEXTURES = [
    preload("res://assets/hero_red.png"),
    preload("res://assets/hero_blue.png"),
    preload("res://assets/hero_druid.png"),
    preload("res://assets/hero_guardian.png"),
    preload("res://assets/hero_dark_prince.png")
]
const CHAR_NAMES = ["Рыцарь", "Разбойник", "Друид", "Страж", "Тёмный принц"]
const CHAR_COLORS = [Color("#d65b43"), Color("#56b6a0"), Color("#8bbd62"), Color("#d5a64d"), Color("#9b72d6")]

enum Mode { MENU, LOCAL, BOT, ONLINE, CAMPAIGN }
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
var hp1_name: Label
var hp2_name: Label
var hp1_portrait: TextureRect
var hp2_portrait: TextureRect
var ability1_label: Label
var ability2_label: Label
var timer_label: Label
var status_label: Label
var menu_panel: PanelContainer
var bot_option: OptionButton
var ip_input: LineEdit
var char1_option: OptionButton
var char2_option: OptionButton
var campaign_option: OptionButton
var chapter_panel: PanelContainer
var settings_panel: PanelContainer
var music_slider: HSlider
var sfx_slider: HSlider
var control_info_label: Label
var music_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer
var campaign_unlocked := 1
var campaign_chapter := 0
var campaign_finished := false
var result_handled := false
var joy_previous: Dictionary = {}
var key_previous: Dictionary = {}
var music_volume := 0.55
var sfx_volume := 0.8
var shadow_trail_timer := [0.0, 0.0]
var fighter_motion := [0.0, 0.0]
var fighter_anim_time := [0.0, 0.0]
const CHAPTER_NAMES := ["I · Падение крепости", "II · Кража печати", "III · Проклятый лес", "IV · Клятва Стража", "V · Сердце тьмы"]
const CHAPTER_HEROES := [0, 1, 2, 3, 4]
const CHAPTER_STORIES := [
    "Крепость Эйрхольм пала за одну ночь. Рыцарь возвращается к разрушенным воротам и находит следы тьмы, которой не было в старых хрониках. На дороге ему встречается Разбойник — и у каждого своя версия случившегося.",
    "Разбойник признаётся: он украл древнюю печать не ради золота. Кто-то обещал ему вернуть человека, которого он потерял. Но печать оказалась ключом к тому, что должно было оставаться запертым.",
    "В проклятом лесу Друид слышит голоса корней. Тьма не уничтожает жизнь — она заставляет её помнить чужую боль. Древний Страж леса не пропустит путников без испытания.",
    "Страж хранит клятву, данную при основании королевства. Он знает, что печать создавалась не для уничтожения тьмы, а для разделения двух сущностей. Теперь клятва требует от него невозможного.",
    "Тёмный принц открывает последнюю дверь. За чудовищной территорией скрывается не завоеватель, а тот, чью сущность раскололи ради спасения королевства. Финал решит, что останется от мира — и от него самого."
]
const CHAPTER_BOSSES := ["Пепельный капитан", "Хранитель печати", "Страж корней", "Первый рыцарь", "Отражение принца"]

func _ready():
    _load_progress()
    _setup_audio()
    _build_ui()
    set_process(true)
    queue_redraw()

func _setup_audio():
    music_player = AudioStreamPlayer.new()
    music_player.bus = "Master"
    add_child(music_player)
    sfx_player = AudioStreamPlayer.new()
    sfx_player.bus = "Master"
    add_child(sfx_player)
    _play_music("menu")

func _play_music(kind: String):
    var path = "res://assets/audio/menu_ambience.wav" if kind == "menu" else "res://assets/audio/battle_ambience.wav"
    if ResourceLoader.exists(path):
        var audio_stream: AudioStreamWAV = load(path) as AudioStreamWAV
        if audio_stream != null:
            audio_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
            music_player.stream = audio_stream
            music_player.volume_db = linear_to_db(max(0.001, music_volume))
            music_player.play()

func _play_sfx(kind: String):
    var files = {"sword":"sword.wav", "hit":"impact.wav", "ability":"shadow.wav", "ui":"ui.wav"}
    if not files.has(kind): return
    var path = "res://assets/audio/" + files[kind]
    if ResourceLoader.exists(path):
        sfx_player.stream = load(path)
        sfx_player.volume_db = linear_to_db(max(0.001, sfx_volume))
        sfx_player.play()

func _load_progress():
    var save = ConfigFile.new()
    if save.load("user://arena_duel_progress.cfg") == OK:
        campaign_unlocked = clampi(int(save.get_value("campaign", "unlocked", 1)), 1, 5)
        campaign_finished = bool(save.get_value("campaign", "finished", false))
        music_volume = float(save.get_value("audio", "music", 0.55))
        sfx_volume = float(save.get_value("audio", "sfx", 0.8))

func _save_progress():
    var save = ConfigFile.new()
    save.set_value("campaign", "unlocked", campaign_unlocked)
    save.set_value("campaign", "finished", campaign_finished)
    save.set_value("audio", "music", music_volume)
    save.set_value("audio", "sfx", sfx_volume)
    save.save("user://arena_duel_progress.cfg")

func _style_panel(panel: PanelContainer, color: Color = Color("#171923")):
    var style = StyleBoxFlat.new()
    style.bg_color = color
    style.border_color = Color("#9b7848")
    style.set_border_width_all(2)
    style.set_corner_radius_all(12)
    style.content_margin_left = 24
    style.content_margin_right = 24
    style.content_margin_top = 18
    style.content_margin_bottom = 18
    panel.add_theme_stylebox_override("panel", style)

func _build_ui():
    menu_layer = CanvasLayer.new()
    add_child(menu_layer)
    var root = Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    menu_layer.add_child(root)

    menu_panel = PanelContainer.new()
    menu_panel.set_anchors_preset(Control.PRESET_CENTER)
    menu_panel.offset_left = -285
    menu_panel.offset_top = -380
    menu_panel.offset_right = 285
    menu_panel.offset_bottom = 380
    menu_panel.custom_minimum_size = Vector2(570, 760)
    _style_panel(menu_panel, Color(0.055, 0.065, 0.09, 0.96))
    root.add_child(menu_panel)
    var vb = VBoxContainer.new()
    vb.add_theme_constant_override("separation", 8)
    menu_panel.add_child(vb)
    var title = Label.new()
    title.text = "ARENA DUEL"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 46)
    title.add_theme_color_override("font_color", Color("#f2d49b"))
    vb.add_child(title)
    var sub = Label.new()
    sub.text = "МЕЧИ  ·  МАГИЯ  ·  СУДЬБА КОРОЛЕВСТВА"
    sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    sub.add_theme_font_size_override("font_size", 13)
    sub.add_theme_color_override("font_color", Color("#b9a98c"))
    vb.add_child(sub)
    var divider = HSeparator.new()
    vb.add_child(divider)

    var pick1 = Label.new()
    pick1.text = "БОЕЦ ПЕРВОГО ИГРОКА"
    pick1.add_theme_color_override("font_color", Color("#d7bd91"))
    vb.add_child(pick1)
    char1_option = OptionButton.new()
    for i in range(CHAR_NAMES.size()): char1_option.add_item(CHAR_NAMES[i], i)
    char1_option.select(0)
    vb.add_child(char1_option)
    var pick2 = Label.new()
    pick2.text = "БОЕЦ ВТОРОГО ИГРОКА / БОТА"
    pick2.add_theme_color_override("font_color", Color("#d7bd91"))
    vb.add_child(pick2)
    char2_option = OptionButton.new()
    for i in range(CHAR_NAMES.size()): char2_option.add_item(CHAR_NAMES[i], i)
    char2_option.select(1)
    vb.add_child(char2_option)

    _add_button(vb, "СЮЖЕТНАЯ КАМПАНИЯ  ·  ГЛАВА %d/5" % campaign_unlocked, _open_chapters)
    _add_button(vb, "ЛОКАЛЬНЫЙ PvP", _start_local)
    _add_button(vb, "PvB  ·  ПРОТИВ БОТА", _start_bot)
    _add_button(vb, "ОНЛАЙН PvP  ·  СОЗДАТЬ КОМНАТУ", _host_online)
    ip_input = LineEdit.new()
    ip_input.placeholder_text = "IP компьютера-хоста"
    ip_input.text = "127.0.0.1"
    vb.add_child(ip_input)
    _add_button(vb, "ПОДКЛЮЧИТЬСЯ К ОНЛАЙН PvP", _join_online)
    var optrow = HBoxContainer.new()
    var optlabel = Label.new()
    optlabel.text = "Сложность бота:"
    optrow.add_child(optlabel)
    bot_option = OptionButton.new()
    bot_option.add_item("Лёгкая", 0)
    bot_option.add_item("Средняя", 1)
    bot_option.add_item("Сложная", 2)
    bot_option.select(1)
    optrow.add_child(bot_option)
    vb.add_child(optrow)
    _add_button(vb, "НАСТРОЙКИ ЗВУКА", _open_settings)
    status_label = Label.new()
    status_label.text = "WASD / стрелки  ·  Xbox A — атака  ·  X — способность"
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status_label.add_theme_color_override("font_color", Color("#d9c18f"))
    status_label.add_theme_font_size_override("font_size", 12)
    vb.add_child(status_label)
    _add_button(vb, "ВЫХОД", func(): get_tree().quit())

    chapter_panel = PanelContainer.new()
    chapter_panel.set_anchors_preset(Control.PRESET_CENTER)
    chapter_panel.offset_left = -310
    chapter_panel.offset_top = -250
    chapter_panel.offset_right = 310
    chapter_panel.offset_bottom = 250
    _style_panel(chapter_panel)
    chapter_panel.visible = false
    root.add_child(chapter_panel)
    var cv = VBoxContainer.new()
    cv.add_theme_constant_override("separation", 12)
    chapter_panel.add_child(cv)
    var ch_title = Label.new()
    ch_title.text = "ХРОНИКИ ЗАТМЕНИЯ"
    ch_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    ch_title.add_theme_font_size_override("font_size", 28)
    ch_title.add_theme_color_override("font_color", Color("#f2d49b"))
    cv.add_child(ch_title)
    campaign_option = OptionButton.new()
    for i in range(CHAPTER_NAMES.size()): campaign_option.add_item(CHAPTER_NAMES[i] + ("  ·  ЗАКРЫТО" if i >= campaign_unlocked else ""), i)
    campaign_option.select(min(campaign_unlocked - 1, 4))
    campaign_option.item_selected.connect(_show_chapter_info)
    cv.add_child(campaign_option)
    var info = Label.new()
    info.name = "ChapterInfo"
    info.text = CHAPTER_STORIES[min(campaign_unlocked - 1, 4)]
    info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    info.custom_minimum_size = Vector2(550, 130)
    cv.add_child(info)
    _add_button(cv, "НАЧАТЬ ГЛАВУ", _start_selected_chapter)
    _add_button(cv, "НАЗАД", _close_chapters)

    settings_panel = PanelContainer.new()
    settings_panel.set_anchors_preset(Control.PRESET_CENTER)
    settings_panel.offset_left = -280
    settings_panel.offset_top = -280
    settings_panel.offset_right = 280
    settings_panel.offset_bottom = 280
    _style_panel(settings_panel)
    settings_panel.visible = false
    root.add_child(settings_panel)
    var sv = VBoxContainer.new()
    sv.add_theme_constant_override("separation", 14)
    settings_panel.add_child(sv)
    var st = Label.new()
    st.text = "НАСТРОЙКИ ЗВУКА"
    st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    st.add_theme_font_size_override("font_size", 27)
    sv.add_child(st)
    var ml = Label.new()
    ml.text = "Музыка"
    sv.add_child(ml)
    music_slider = HSlider.new()
    music_slider.min_value = 0
    music_slider.max_value = 1
    music_slider.step = 0.01
    music_slider.value = music_volume
    music_slider.value_changed.connect(_on_music_volume)
    sv.add_child(music_slider)
    var sl = Label.new()
    sl.text = "Звуковые эффекты"
    sv.add_child(sl)
    sfx_slider = HSlider.new()
    sfx_slider.min_value = 0
    sfx_slider.max_value = 1
    sfx_slider.step = 0.01
    sfx_slider.value = sfx_volume
    sfx_slider.value_changed.connect(_on_sfx_volume)
    sv.add_child(sfx_slider)
    _add_button(sv, "ПРОВЕРИТЬ ЗВУК", func(): _play_sfx("ui"))
    control_info_label = Label.new()
    control_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    control_info_label.add_theme_font_size_override("font_size", 13)
    control_info_label.text = "P1: WASD · SPACE · Q\nP2: стрелки · ENTER · SHIFT\nГеймпад: левый стик · A · X"
    sv.add_child(control_info_label)
    _add_button(sv, "НАЗАД", _close_settings)

    game_layer = CanvasLayer.new()
    add_child(game_layer)
    game_layer.visible = false
    var hud = Control.new()
    hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    game_layer.add_child(hud)
    var top = HBoxContainer.new()
    top.set_anchors_preset(Control.PRESET_TOP_WIDE)
    top.offset_left = 30
    top.offset_top = 18
    top.offset_right = -30
    top.offset_bottom = 72
    hud.add_child(top)
    hp1_portrait = TextureRect.new()
    hp1_portrait.custom_minimum_size = Vector2(58, 58)
    hp1_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    top.add_child(hp1_portrait)
    var p1_hud = VBoxContainer.new()
    p1_hud.add_theme_constant_override("separation", 2)
    top.add_child(p1_hud)
    hp1_name = Label.new()
    hp1_name.add_theme_color_override("font_color", Color("#f1d5a5"))
    p1_hud.add_child(hp1_name)
    hp1_bar = ProgressBar.new()
    hp1_bar.custom_minimum_size = Vector2(360, 25)
    hp1_bar.max_value = 100
    hp1_bar.show_percentage = false
    p1_hud.add_child(hp1_bar)
    ability1_label = Label.new()
    ability1_label.add_theme_font_size_override("font_size", 12)
    ability1_label.add_theme_color_override("font_color", Color("#d5c6aa"))
    p1_hud.add_child(ability1_label)
    var spacer = Control.new()
    spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top.add_child(spacer)
    timer_label = Label.new()
    timer_label.add_theme_font_size_override("font_size", 30)
    timer_label.add_theme_color_override("font_color", Color("#f6e2bb"))
    top.add_child(timer_label)
    var spacer2 = Control.new()
    spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top.add_child(spacer2)
    var p2_hud = VBoxContainer.new()
    p2_hud.add_theme_constant_override("separation", 2)
    p2_hud.alignment = BoxContainer.ALIGNMENT_END
    top.add_child(p2_hud)
    hp2_name = Label.new()
    hp2_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    hp2_name.add_theme_color_override("font_color", Color("#f1d5a5"))
    p2_hud.add_child(hp2_name)
    hp2_bar = ProgressBar.new()
    hp2_bar.custom_minimum_size = Vector2(360, 25)
    hp2_bar.max_value = 100
    hp2_bar.show_percentage = false
    p2_hud.add_child(hp2_bar)
    ability2_label = Label.new()
    ability2_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    ability2_label.add_theme_font_size_override("font_size", 12)
    ability2_label.add_theme_color_override("font_color", Color("#d5c6aa"))
    p2_hud.add_child(ability2_label)
    hp2_portrait = TextureRect.new()
    hp2_portrait.custom_minimum_size = Vector2(58, 58)
    hp2_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    top.add_child(hp2_portrait)
    var help = Label.new()
    help.text = "P1: WASD / геймпад  ·  SPACE / A — меч  ·  Q / X — способность     P2: стрелки / второй геймпад  ·  ENTER — меч  ·  SHIFT — способность"
    help.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    help.offset_left = 170
    help.offset_top = -46
    help.offset_right = -170
    help.offset_bottom = -12
    help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    help.add_theme_font_size_override("font_size", 13)
    help.add_theme_color_override("font_color", Color("#f0dfc1"))
    hud.add_child(help)
    var back = Button.new()
    back.text = "В МЕНЮ"
    back.position = Vector2(18, 18)
    back.pressed.connect(_back_menu)
    hud.add_child(back)

func _show_chapter_info(index: int):
    var info: Label = chapter_panel.find_child("ChapterInfo", true, false) as Label
    if info != null:
        info.text = CHAPTER_STORIES[index] if index < campaign_unlocked else "Эта глава пока закрыта. Пройди предыдущую главу, чтобы открыть её."

func _open_chapters():
    menu_panel.visible = false
    chapter_panel.visible = true
    settings_panel.visible = false
    _play_sfx("ui")

func _close_chapters():
    chapter_panel.visible = false
    menu_panel.visible = true

func _start_selected_chapter():
    var index = campaign_option.get_selected_id()
    if index >= campaign_unlocked:
        _show_chapter_info(index)
        return
    campaign_chapter = index
    char1 = CHAPTER_HEROES[index]
    char2 = 4 if index < 4 else 3
    char1_option.select(char1)
    char2_option.select(char2)
    chapter_panel.visible = false
    _start_game(Mode.CAMPAIGN)
    hp2 = 100.0 + float(index) * 12.0
    hp2_bar.max_value = hp2
    bot_level = mini(2, int(index / 2))
    _update_hud()
    status_text = CHAPTER_STORIES[index]

func _open_settings():
    menu_panel.visible = false
    settings_panel.visible = true
    var pads = Input.get_connected_joypads()
    control_info_label.text = "КЛАВИАТУРА\nP1: WASD · SPACE — атака · Q — способность\nP2: стрелки · ENTER — атака · SHIFT — способность\n\nГЕЙМПАДЫ\nЛевый стик — движение · A — атака · X — способность\nПодключено контроллеров: %d\nПервый контроллер — P1; второй — P2. Один контроллер в PvB управляет P1." % pads.size()

func _close_settings():
    settings_panel.visible = false
    menu_panel.visible = true
    _save_progress()

func _on_music_volume(value: float):
    music_volume = value
    if music_player: music_player.volume_db = linear_to_db(max(0.001, value))
    _save_progress()

func _on_sfx_volume(value: float):
    sfx_volume = value
    _save_progress()

func _add_button(parent: VBoxContainer, caption: String, action: Callable):
    var b = Button.new()
    b.text = caption
    b.custom_minimum_size = Vector2(0, 42)
    b.add_theme_font_size_override("font_size", 16)
    var normal = StyleBoxFlat.new()
    normal.bg_color = Color("#34303a")
    normal.border_color = Color("#8d7048")
    normal.set_border_width_all(1)
    normal.set_corner_radius_all(7)
    var hover = StyleBoxFlat.new()
    hover.bg_color = Color("#55422e")
    hover.border_color = Color("#e0b86f")
    hover.set_border_width_all(2)
    hover.set_corner_radius_all(7)
    var pressed = StyleBoxFlat.new()
    pressed.bg_color = Color("#211c25")
    pressed.border_color = Color("#b28b50")
    pressed.set_border_width_all(2)
    pressed.set_corner_radius_all(7)
    b.add_theme_stylebox_override("normal", normal)
    b.add_theme_stylebox_override("hover", hover)
    b.add_theme_stylebox_override("pressed", pressed)
    b.add_theme_color_override("font_color", Color("#f1dfc1"))
    b.add_theme_color_override("font_hover_color", Color("#fff0cf"))
    b.pressed.connect(action)
    parent.add_child(b)

func _read_character_picks():
    char1 = char1_option.get_selected_id()
    char2 = char2_option.get_selected_id()

func _start_local():
    _read_character_picks()
    _start_game(Mode.LOCAL)

func _start_bot():
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
    hp1_bar.max_value = 100.0
    hp2_bar.max_value = 100.0
    round_time = 90
    attack_cd = [0.0, 0.0]
    ability_cd = [0.0, 0.0]
    attack_flash = [0.0, 0.0]
    ability_flash = [0.0, 0.0]
    fighter_motion = [0.0, 0.0]
    fighter_anim_time = [0.0, 0.0]
    shadow_trail_timer = [0.0, 0.0]
    facing = [Vector2.RIGHT, Vector2.LEFT]
    roots = [0.0, 0.0]
    dark_zones = [{}, {}]
    dark_zone_ticks = [0.0, 0.0]
    projectiles.clear()
    effects.clear()
    status_text = "Меч: SPACE / ENTER     Способность: Q / SHIFT"
    result_handled = false
    menu_panel.visible = false
    chapter_panel.visible = false
    settings_panel.visible = false
    game_layer.visible = true
    _play_music("battle")
    _play_sfx("ui")
    queue_redraw()

func _host_online():
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
    chapter_panel.visible = false
    settings_panel.visible = false
    _play_music("menu")
    queue_redraw()

func _process(delta):
    if mode == Mode.MENU:
        _capture_joy_state()
        queue_redraw()
        return
    if hp1 <= 0 or hp2 <= 0 or round_time <= 0:
        if mode == Mode.CAMPAIGN:
            if not result_handled:
                result_handled = true
                if hp2 <= 0:
                    campaign_unlocked = min(5, max(campaign_unlocked, campaign_chapter + 2))
                    if campaign_chapter == 4:
                        campaign_finished = true
                    _save_progress()
                    status_text = "ГЛАВА ПРОЙДЕНА!  " + CHAPTER_NAMES[campaign_chapter] + "  ·  Нажми В МЕНЮ для продолжения"
                else:
                    status_text = "ПОРАЖЕНИЕ. Попробуй ещё раз — глава останется открытой."
        else:
            if hp1 <= 0:
                status_text = "Победил " + CHAR_NAMES[char2] + "!"
            elif hp2 <= 0:
                status_text = "Победил " + CHAR_NAMES[char1] + "!"
            else:
                status_text = "Время вышло!"
        _capture_joy_state()
        queue_redraw()
        return

    round_time = max(0.0, round_time - delta)
    for i in range(2):
        attack_cd[i] = max(0.0, attack_cd[i] - delta)
        ability_cd[i] = max(0.0, ability_cd[i] - delta)
        attack_flash[i] = max(0.0, attack_flash[i] - delta)
        ability_flash[i] = max(0.0, ability_flash[i] - delta)
        roots[i] = max(0.0, roots[i] - delta)
    _update_dark_zones(delta)

    var pads = Input.get_connected_joypads()
    var p1_device = pads[0] if pads.size() > 0 else -1
    var m1 = _keyboard_move_1()
    if p1_device >= 0:
        var joy0 = _joy_move(p1_device)
        if joy0.length() > 0.2: m1 = joy0
    fighter_motion[0] = 1.0 if m1.length() > 0.1 and roots[0] <= 0.0 else 0.0
    fighter_anim_time[0] += delta * (1.0 if fighter_motion[0] > 0.0 else 0.55)
    if roots[0] <= 0.0 and m1.length() > 0.1:
        p1 += m1.normalized() * _speed(char1) * (1.3 if _is_dark_prince_empowered(0) else 1.0) * delta
        facing[0] = m1.normalized()
        if char1 == 4:
            shadow_trail_timer[0] -= delta
            if shadow_trail_timer[0] <= 0.0:
                shadow_trail_timer[0] = 0.075
                effects.append({"kind":"shadow_trail", "pos":p1 + Vector2(0, 25), "life":0.42, "max":0.42, "color":Color("#7650a8")})
    p1 = _clamp_player(p1)

    if mode == Mode.LOCAL:
        var m2 = _keyboard_move_2()
        if pads.size() > 1:
            var jm = _joy_move(pads[1])
            if jm.length() > 0.2: m2 = jm
        fighter_motion[1] = 1.0 if m2.length() > 0.1 and roots[1] <= 0.0 else 0.0
        fighter_anim_time[1] += delta * (1.0 if fighter_motion[1] > 0.0 else 0.55)
        if roots[1] <= 0 and m2.length() > 0.1:
            p2 += m2.normalized() * _speed(char2) * (1.3 if _is_dark_prince_empowered(1) else 1.0) * delta
            facing[1] = m2.normalized()
            if char2 == 4:
                shadow_trail_timer[1] -= delta
                if shadow_trail_timer[1] <= 0.0:
                    shadow_trail_timer[1] = 0.075
                    effects.append({"kind":"shadow_trail", "pos":p2 + Vector2(0, 25), "life":0.42, "max":0.42, "color":Color("#7650a8")})
        if _p2_attack_pressed(): _melee(1)
        if _p2_ability_pressed(): _ability(1)
    elif mode == Mode.BOT or mode == Mode.CAMPAIGN:
        _bot_update(delta)
    elif mode == Mode.ONLINE:
        if not multiplayer.is_server(): _send_remote_state()

    if roots[0] <= 0 and _p1_attack_pressed(): _melee(0)
    if _p1_ability_pressed(): _ability(0)
    _update_effects(delta)
    _update_hud()
    _capture_joy_state()
    queue_redraw()

func _capture_joy_state():
    for keycode in [KEY_SPACE, KEY_Q, KEY_ENTER, KEY_SHIFT]:
        key_previous[str(keycode)] = Input.is_key_pressed(keycode)
    for device in Input.get_connected_joypads():
        for button in [JOY_BUTTON_A, JOY_BUTTON_X]:
            joy_previous[str(device) + ":" + str(button)] = Input.is_joy_button_pressed(device, button)

func _key_just_pressed(keycode: int) -> bool:
    var key = str(keycode)
    var down = Input.is_key_pressed(keycode)
    return down and not bool(key_previous.get(key, false))

func _joy_just_pressed(device: int, button: int) -> bool:
    if device < 0 or not Input.get_connected_joypads().has(device): return false
    var key = str(device) + ":" + str(button)
    var down = Input.is_joy_button_pressed(device, button)
    return down and not bool(joy_previous.get(key, false))

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
    return _key_just_pressed(KEY_SPACE) or (pads.size() > 0 and _joy_just_pressed(pads[0], JOY_BUTTON_A))

func _p1_ability_pressed() -> bool:
    var pads = Input.get_connected_joypads()
    return _key_just_pressed(KEY_Q) or (pads.size() > 0 and _joy_just_pressed(pads[0], JOY_BUTTON_X))

func _p2_attack_pressed() -> bool:
    var pads = Input.get_connected_joypads()
    return _key_just_pressed(KEY_ENTER) or (pads.size() > 1 and _joy_just_pressed(pads[1], JOY_BUTTON_A))

func _p2_ability_pressed() -> bool:
    var pads = Input.get_connected_joypads()
    return _key_just_pressed(KEY_SHIFT) or (pads.size() > 1 and _joy_just_pressed(pads[1], JOY_BUTTON_X))

func _clamp_player(p: Vector2) -> Vector2:
    return Vector2(clamp(p.x, 235, 1365), clamp(p.y, 270, 690))

func _speed(character: int) -> float:
    return [260.0, 330.0, 270.0, 215.0, 250.0][character]

func _bot_update(delta):
    var dir = p1 - p2
    fighter_motion[1] = 1.0 if roots[1] <= 0.0 and dir.length() > 105.0 else 0.0
    fighter_anim_time[1] += delta * (1.0 if fighter_motion[1] > 0.0 else 0.55)
    var campaign_bonus = (campaign_chapter + 1) * 18 if mode == Mode.CAMPAIGN else 0
    if roots[1] <= 0.0 and dir.length() > 105:
        p2 += dir.normalized() * (150 + bot_level * 48 + campaign_bonus) * delta
        facing[1] = dir.normalized()
    elif roots[1] <= 0.0 and dir.length() < 65:
        p2 -= dir.normalized() * 90 * delta
    if attack_cd[1] <= 0 and dir.length() < 115: _melee(1)
    var boss_chance = 0.008 + bot_level * 0.012 + (campaign_chapter * 0.006 if mode == Mode.CAMPAIGN else 0.0)
    if ability_cd[1] <= 0 and dir.length() < 210 and randf() < boss_chance: _ability(1)
    p2 = _clamp_player(p2)

func _melee(player: int):
    if attack_cd[player] > 0: return
    attack_cd[player] = [0.48, 0.32, 0.55, 0.72, 0.52][char1 if player == 0 else char2]
    attack_flash[player] = 0.22
    _play_sfx("sword")
    var attacker = p1 if player == 0 else p2
    var target = p2 if player == 0 else p1
    var dir = (target - attacker).normalized()
    facing[player] = dir
    var reach = [112.0, 88.0, 105.0, 125.0, 118.0][char1 if player == 0 else char2]
    var damage = [16.0, 12.0, 11.0, 23.0, 17.0][char1 if player == 0 else char2]
    if _is_dark_prince_empowered(player): damage *= 1.3
    var delta_pos = target - attacker
    if delta_pos.length() <= reach and facing[player].dot(delta_pos.normalized()) > 0.35:
        _damage(1-player, damage)
        effects.append({"kind":"hit","pos":target,"life":0.25,"max":0.25,"color":Color("#ffe2a0")})
    effects.append({"kind":"slash","pos":attacker+dir*50,"dir":dir,"life":0.22,"max":0.22,"color":CHAR_COLORS[char1 if player == 0 else char2]})

func _ability(player: int):
    if ability_cd[player] > 0: return
    var character = char1 if player == 0 else char2
    var attacker = p1 if player == 0 else p2
    var target = p2 if player == 0 else p1
    var dir = (target-attacker).normalized()
    facing[player] = dir
    ability_cd[player] = [5.0, 4.0, 6.0, 7.0, 30.0][character]
    ability_flash[player] = 0.45
    _play_sfx("ability")
    match character:
        0: # Knight: shielded charge and heavy cleave
            if player == 0: p1 = _clamp_player(p1 + dir*135)
            else: p2 = _clamp_player(p2 + dir*135)
            if (target-attacker).length() < 245: _damage(1-player, 29)
            effects.append({"kind":"slash","pos":attacker+dir*105,"dir":dir,"life":0.45,"max":0.45,"color":Color("#f5c36d")})
        1: # Rogue: quick twin dagger strike
            if (target-attacker).length() < 175: _damage(1-player, 24)
            effects.append({"kind":"slash","pos":attacker+dir*70,"dir":dir.rotated(0.25),"life":0.35,"max":0.35,"color":Color("#80e6cb")})
            effects.append({"kind":"slash","pos":attacker+dir*70,"dir":dir.rotated(-0.25),"life":0.35,"max":0.35,"color":Color("#80e6cb")})
        2: # Druid: root zone
            if (target-attacker).length() < 260:
                roots[1-player] = 1.45
                _damage(1-player, 17)
            effects.append({"kind":"roots","pos":target,"life":0.7,"max":0.7,"color":Color("#a8d96c")})
        3: # Guardian: ground slam
            if (target-attacker).length() < 205: _damage(1-player, 34)
            effects.append({"kind":"slam","pos":attacker,"life":0.55,"max":0.55,"color":Color("#f1bd65")})
        4: # Dark Prince: ten-second shadow dominion (30s cooldown)
            var zone_center = attacker.lerp(target, 0.42)
            dark_zones[player] = {"center": zone_center, "radius": 285.0, "life": 10.0}
            dark_zone_ticks[player] = 0.25
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
                    effects.append({"kind":"hit","pos":enemy,"life":0.2,"max":0.2,"color":Color("#a77be8")})
                    break

func _damage(player: int, amount: float):
    _play_sfx("hit")
    if player == 0:
        if mode == Mode.CAMPAIGN: amount *= 1.0 + float(campaign_chapter) * 0.08
        hp1 = max(0.0, hp1-amount)
    else:
        hp2 = max(0.0, hp2-amount)

func _update_effects(delta):
    for i in range(effects.size()-1,-1,-1):
        effects[i].life -= delta
        if effects[i].life <= 0: effects.remove_at(i)

func _update_hud():
    hp1_bar.value = hp1
    hp2_bar.value = hp2
    hp1_name.text = CHAR_NAMES[char1]
    hp2_name.text = CHAR_NAMES[char2]
    hp1_portrait.texture = CHAR_TEXTURES[char1]
    hp2_portrait.texture = CHAR_TEXTURES[char2]
    ability1_label.text = "Способность: ГОТОВА" if ability_cd[0] <= 0.0 else "Способность: %.1f с" % ability_cd[0]
    ability2_label.text = "Способность: ГОТОВА" if ability_cd[1] <= 0.0 else "Способность: %.1f с" % ability_cd[1]
    timer_label.text = "%02d:%02d" % [int(round_time/60), int(round_time)%60]

func _send_remote_state():
    net_send_timer += get_process_delta_time()
    if net_send_timer > 0.05:
        net_send_timer = 0
        rpc_id(1, "_receive_remote_position", p1)

@rpc("any_peer","call_remote","unreliable")
func _receive_remote_position(pos: Vector2):
    if multiplayer.is_server(): p2 = _clamp_player(pos)

func _draw_fighter_sprite(player: int, world_pos: Vector2, character: int, tick: float):
    # Painterly 512x640 transparent character art, animated with a subtle idle/breath cycle.
    var moving := fighter_motion[player] > 0.0
    var phase := fighter_anim_time[player] * (10.0 if moving else 2.2)
    var bob := sin(phase) * (5.0 if moving else 2.0)
    var sway := sin(phase * 0.5) * (3.0 if moving else 1.2)
    var pulse := 1.0 + sin(tick * 2.0 + float(player)) * 0.012
    var w := (176.0 if character == 4 else 184.0) * pulse
    var h := (230.0 if character == 4 else 236.0) * pulse
    var foot_y := world_pos.y + 46.0
    var shadow_color := Color(0.10, 0.045, 0.16, 0.32) if character == 4 else Color(0.015, 0.02, 0.03, 0.38)
    draw_set_transform(Vector2(world_pos.x, foot_y), 0.0, Vector2(1.0, 0.38))
    draw_circle(Vector2.ZERO, 48.0 if character == 3 else 42.0, shadow_color)
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
    if character == 4:
        for aura_index in range(3):
            var aura_phase := tick * 1.25 + float(aura_index) * TAU / 3.0
            var aura_pos := world_pos + Vector2(cos(aura_phase) * (58.0 + 5.0 * sin(tick * 2.0)), -34.0 + sin(aura_phase) * 35.0)
            draw_circle(aura_pos, 13.0 + 3.0 * sin(tick * 3.0 + aura_index), Color(0.38, 0.16, 0.62, 0.16))
    else:
        draw_circle(world_pos + Vector2(0, 12), 55.0, Color(CHAR_COLORS[character].r, CHAR_COLORS[character].g, CHAR_COLORS[character].b, 0.055))
    var attack_ratio := clamp(attack_flash[player] / 0.22, 0.0, 1.0)
    var lunge := facing[player] * attack_ratio * 9.0
    var sprite_rect := Rect2(world_pos.x - w * 0.5 + sway + lunge.x, world_pos.y - h * 0.53 - bob + lunge.y, w * (1.0 + attack_ratio * 0.025), h * (1.0 - attack_ratio * 0.018))
    draw_texture_rect(CHAR_TEXTURES[character], sprite_rect, false, Color(1, 1, 1, 1))
    if attack_flash[player] > 0.0:
        var flash_alpha := clamp(attack_flash[player] / 0.22, 0.0, 1.0) * 0.22
        draw_circle(world_pos + facing[player] * 38.0, 62.0, Color(1.0, 0.78, 0.42, flash_alpha))

func _draw_prince_tendrils(center: Vector2, tick: float):
    for n in range(8):
        var angle = TAU * float(n) / 8.0 + sin(tick * 2.1 + n) * 0.13
        var reach = 72.0 + sin(tick * 3.0 + n * 1.7) * 17.0
        var direction = Vector2(cos(angle), sin(angle))
        var base = center + direction * 43.0
        var bend = center + direction.rotated(sin(tick * 2.7 + n) * 0.24) * reach * 0.72 + Vector2(0, sin(tick * 4.0 + n) * 9.0)
        var tip = center + direction * reach + Vector2(0, sin(tick * 3.5 + n * 0.8) * 15.0)
        draw_line(base, bend, Color(0.10, 0.035, 0.17, 0.9), 8.0)
        draw_line(bend, tip, Color(0.20, 0.08, 0.31, 0.92), 5.0)
        draw_circle(tip, 4.0, Color(0.52, 0.30, 0.77, 0.8))

func _draw():
    draw_texture_rect(ARENA, Rect2(0,0,1600,900), false)
    if mode == Mode.MENU:
        draw_rect(Rect2(0, 0, 1600, 900), Color(0.025, 0.035, 0.065, 0.76), true)
        for i in range(18):
            var x = float(i) * 96.0
            draw_line(Vector2(x, 0), Vector2(x - 120, 900), Color(0.65, 0.48, 0.25, 0.07), 2)
        draw_circle(Vector2(800, 265), 190, Color(0.52, 0.31, 0.16, 0.08))
        draw_arc(Vector2(800, 265), 190, 0, TAU, 96, Color(0.76, 0.58, 0.31, 0.18), 3)
        # Дальний силуэт разрушенной крепости для заставки.
        var stone = Color(0.035, 0.045, 0.065, 0.94)
        draw_rect(Rect2(0, 560, 1600, 340), stone, true)
        draw_rect(Rect2(115, 390, 220, 260), stone, true)
        draw_rect(Rect2(1265, 365, 225, 285), stone, true)
        draw_rect(Rect2(420, 470, 760, 210), stone, true)
        draw_colored_polygon(PackedVector2Array([Vector2(105, 390), Vector2(225, 275), Vector2(345, 390)]), stone)
        draw_colored_polygon(PackedVector2Array([Vector2(1250, 365), Vector2(1375, 245), Vector2(1505, 365)]), stone)
        draw_colored_polygon(PackedVector2Array([Vector2(405, 470), Vector2(800, 315), Vector2(1195, 470)]), stone)
        for wx in [175, 245, 1325, 1400, 600, 760, 910, 1060]:
            draw_rect(Rect2(wx, 465 if wx < 400 or wx > 1200 else 535, 24, 54), Color(0.78, 0.42, 0.15, 0.32), true)
        draw_rect(Rect2(0, 640, 1600, 260), Color(0.02, 0.025, 0.04, 0.42), true)
        for i in range(34):
            var px = fposmod(float(i) * 173.0 + Time.get_ticks_msec() * 0.012, 1600.0)
            var py = fposmod(float(i) * 71.0 + Time.get_ticks_msec() * 0.004, 900.0)
            draw_circle(Vector2(px, py), 1.5 + float(i % 3) * 0.6, Color(0.85, 0.68, 0.42, 0.22))
        return
    # Мягкие факельные ореолы и частицы пыли на арене.
    var tick = Time.get_ticks_msec() * 0.001
    for torch in [Vector2(350, 155), Vector2(1250, 155), Vector2(350, 675), Vector2(1250, 675)]:
        var flicker = 0.82 + 0.18 * sin(tick * 8.0 + torch.x)
        draw_circle(torch, 52.0 * flicker, Color(1.0, 0.56, 0.18, 0.055))
        draw_circle(torch, 21.0 * flicker, Color(1.0, 0.68, 0.28, 0.10))
    for i in range(26):
        var dust_x = fposmod(float(i) * 197.0 + tick * (9.0 + float(i % 5)), 1600.0)
        var dust_y = fposmod(float(i) * 83.0 - tick * (4.0 + float(i % 4)), 900.0)
        draw_circle(Vector2(dust_x, dust_y), 1.3, Color(0.95, 0.82, 0.61, 0.24))
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
                var tip = base + Vector2(cos(angle+0.5),sin(angle+0.5))*55
                draw_line(base, tip, Color(0.13,0.07,0.22,0.95*fade), 18)
                draw_line(base, tip, Color(0.55,0.31,0.83,0.9*fade), 4)
    _draw_fighter_sprite(0, p1, char1, tick)
    _draw_fighter_sprite(1, p2, char2, tick)
    if char1 == 4:
        _draw_prince_tendrils(p1, tick)
    if char2 == 4:
        _draw_prince_tendrils(p2, tick)
    if _is_dark_prince_empowered(0):
        draw_arc(p1, 76, 0, TAU, 48, Color("#bd91ff"), 5)
    if _is_dark_prince_empowered(1):
        draw_arc(p2, 76, 0, TAU, 48, Color("#bd91ff"), 5)
    for pr in projectiles:
        draw_circle(pr.pos,14,Color("#ffbd62"))
    for fx in effects:
        var ratio = fx.life/fx.max
        if fx.kind == "slash":
            var d: Vector2 = fx.dir
            var c: Color = fx.color
            var center: Vector2 = fx.pos
            var side = d.rotated(1.05)*54*ratio
            var end = d*70*ratio
            draw_line(center-side,center+end,Color(c.r,c.g,c.b,ratio),12)
            draw_line(center-side*0.7,center+end*0.8,Color(1,0.92,0.72,ratio),4)
        elif fx.kind == "hit":
            draw_circle(fx.pos, 36*(1-ratio)+8, Color(1,0.86,0.55,ratio))
        elif fx.kind == "roots":
            for a in range(8):
                var angle = TAU*a/8
                draw_line(fx.pos,fx.pos+Vector2(cos(angle),sin(angle))*78*(1-ratio*0.35),Color(0.55,0.78,0.32,ratio),8)
        elif fx.kind == "slam":
            draw_arc(fx.pos,100*(1-ratio*0.3),0,TAU,48,Color(0.95,0.68,0.32,ratio),10)
        elif fx.kind == "shadow_burst":
            draw_circle(fx.pos, 260*(1-ratio)+30, Color(0.22,0.10,0.38,0.28*ratio))
            draw_arc(fx.pos, 260*(1-ratio)+30, 0, TAU, 64, Color(0.68,0.42,0.95,ratio), 10)
        elif fx.kind == "shadow_trail":
            draw_circle(fx.pos, 18.0 * ratio + 3.0, Color(0.18, 0.07, 0.27, 0.25 * ratio))
            draw_circle(fx.pos + Vector2(0, 5), 7.0 * ratio, Color(0.42, 0.22, 0.62, 0.35 * ratio))
    if attack_flash[0] > 0:
        draw_arc(p1+facing[0]*42,68,-1.3,1.3,20,CHAR_COLORS[char1],8)
    if attack_flash[1] > 0:
        draw_arc(p2+facing[1]*42,68,PI-1.3,PI+1.3,20,CHAR_COLORS[char2],8)
    draw_string(ThemeDB.fallback_font,Vector2(460,850),status_text,HORIZONTAL_ALIGNMENT_CENTER,700,18,Color("#fff0d0"))
    if mode == Mode.CAMPAIGN:
        draw_string(ThemeDB.fallback_font, Vector2(650, 112), CHAPTER_NAMES[campaign_chapter] + "  ·  БОСС: " + CHAPTER_BOSSES[campaign_chapter], HORIZONTAL_ALIGNMENT_CENTER, 700, 18, Color("#f0d29c"))
    if roots[0] > 0: draw_string(ThemeDB.fallback_font,p1+Vector2(-25,-70),"ROOTED",HORIZONTAL_ALIGNMENT_CENTER,100,14,Color("#b4e47d"))
    if roots[1] > 0: draw_string(ThemeDB.fallback_font,p2+Vector2(-25,-70),"ROOTED",HORIZONTAL_ALIGNMENT_CENTER,100,14,Color("#b4e47d"))
