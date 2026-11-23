extends Node2D

const ARENA = preload("res://assets/arena.png")
const MENU_MUSIC = preload("res://assets/audio/menu_ambience.wav")
const BATTLE_MUSIC = preload("res://assets/audio/battle_ambience.wav")
const SWORD_SFX = preload("res://assets/audio/sword.wav")
const HIT_SFX = preload("res://assets/audio/impact.wav")
const SHADOW_SFX = preload("res://assets/audio/shadow.wav")
const UI_SFX = preload("res://assets/audio/ui.wav")
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
var timer_label: Label
var status_label: Label
var menu_panel: PanelContainer
var bot_option: OptionButton
var ip_input: LineEdit
var char1_option: OptionButton
var char2_option: OptionButton
var campaign_option: OptionButton
var campaign_chapter := 0
var campaign_unlocked := 0
var campaign_wins := 0
var save_path := "user://arena_duel_save.cfg"
var settings_panel: PanelContainer
var music_volume := 0.65
var sfx_volume := 0.8
var music_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer
var last_round_finished := false
var attack_was_down := [false, false]
var ability_was_down := [false, false]
var last_pad_ids: Array[int] = []
var story_label: Label
var story_panel: PanelContainer
var story_queue: Array[String] = []
var story_active := false
var hud_name1: Label
var hud_name2: Label
var ability_label1: Label
var ability_label2: Label
const CHAPTERS := [
    {"title":"I — Падение крепости", "hero":0, "enemy":1, "lines":["Крепость Эйрхольм пала за одну ночь. На камнях остался след, похожий на ожог самой тьмы.","Рыцарь ищет выживших и встречает Разбойника у запечатанных ворот.","За стенами пробуждается первый страж заражённой крепости."]},
    {"title":"II — Печать воров", "hero":1, "enemy":0, "lines":["Разбойник украл древний ключ не ради золота: он пытался сорвать печать, которая удерживала нечто внутри.","Рыцарь считает его предателем. Но найденная запись говорит о другом хозяине печати.","Из темноты доносится голос: «Вы заперли не чудовище. Вы заперли свидетеля»."]},
    {"title":"III — Проклятый лес", "hero":2, "enemy":3, "lines":["Лес перестал узнавать собственные корни. Друид слышит шёпот в древесине.","Древняя магия тьмы не родилась здесь — её принесли, чтобы остановить нечто худшее.","Страж леса не пропускает путников к источнику порчи."]},
    {"title":"IV — Клятва Стража", "hero":3, "enemy":4, "lines":["Страж помнит королевство до падения и клятву, которую дал последнему королю.","Печать была создана из части сущности принца. Она не уничтожала тьму — она разделила его.","Тёмный принц впервые появляется перед героями, но не нападает."]},
    {"title":"V — Тот, кто остался", "hero":4, "enemy":3, "lines":["Когда-то принц добровольно принял в себя живую бездну, чтобы остановить её распространение.","Совет короля испугался его изменившейся сущности и запечатал его, оставив часть тьмы без хозяина.","Теперь печать рушится. Принц распространяет владения, пытаясь собрать свою сущность прежде, чем бездна поглотит всё.","Он не просит прощения. Он просит не дать бездне стать тем, чем когда-то стал он."]}
]

func _ready():
    _build_ui()
    set_process(true)
    queue_redraw()

func _build_ui():
    menu_layer = CanvasLayer.new()
    add_child(menu_layer)
    menu_panel = PanelContainer.new()
    menu_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    menu_panel.custom_minimum_size = Vector2(560, 760)
    menu_panel.add_theme_stylebox_override("panel", _make_panel_style())
    menu_layer.add_child(menu_panel)
    var vb = VBoxContainer.new()
    vb.add_theme_constant_override("separation", 9)
    menu_panel.add_child(vb)
    var title = Label.new()
    title.text = "ARENA DUEL"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 42)
    title.add_theme_color_override("font_color", Color("#f1d5a5"))
    vb.add_child(title)
    var sub = Label.new()
    sub.text = "МЕЧИ • МАГИЯ • АРЕНА"
    sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    sub.add_theme_color_override("font_color", Color("#d6c4a4"))
    vb.add_child(sub)

    var pick1 = Label.new()
    pick1.text = "Персонаж игрока 1"
    vb.add_child(pick1)
    char1_option = OptionButton.new()
    for i in range(CHAR_NAMES.size()): char1_option.add_item(CHAR_NAMES[i], i)
    char1_option.select(0)
    vb.add_child(char1_option)

    var pick2 = Label.new()
    pick2.text = "Персонаж игрока 2 / бота"
    vb.add_child(pick2)
    char2_option = OptionButton.new()
    for i in range(CHAR_NAMES.size()): char2_option.add_item(CHAR_NAMES[i], i)
    char2_option.select(1)
    vb.add_child(char2_option)

    campaign_option = OptionButton.new()
    for chapter in CHAPTERS: campaign_option.add_item(chapter.title)
    campaign_option.select(0)
    vb.add_child(campaign_option)
    _add_button(vb, "СЮЖЕТНАЯ КАМПАНИЯ", _start_campaign)
    _add_button(vb, "ЛОКАЛЬНЫЙ PvP — 2 ИГРОКА", _start_local)
    _add_button(vb, "PvB — ПРОТИВ БОТА", _start_bot)
    _add_button(vb, "ОНЛАЙН PvP — СОЗДАТЬ КОМНАТУ", _host_online)
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
    bot_option.add_item("Лёгкая",0)
    bot_option.add_item("Средняя",1)
    bot_option.add_item("Сложная",2)
    bot_option.select(1)
    optrow.add_child(bot_option)
    vb.add_child(optrow)
    status_label = Label.new()
    status_label.text = "Локально: WASD + стрелки или геймпад."
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status_label.add_theme_color_override("font_color", Color("#e7c98f"))
    vb.add_child(status_label)
    _add_button(vb, "НАСТРОЙКИ", _show_settings)
    _add_button(vb, "ВЫХОД", func(): get_tree().quit())
    _load_progress()
    music_player = AudioStreamPlayer.new()
    music_player.name = "MusicPlayer"
    music_player.volume_db = linear_to_db(music_volume)
    add_child(music_player)
    sfx_player = AudioStreamPlayer.new()
    sfx_player.name = "SfxPlayer"
    sfx_player.volume_db = linear_to_db(sfx_volume)
    add_child(sfx_player)
    game_layer = CanvasLayer.new()
    add_child(game_layer)
    game_layer.visible = false
    _build_story_ui()
    var top = HBoxContainer.new()
    top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    top.offset_left = 30
    top.offset_top = 18
    top.offset_right = -30
    top.offset_bottom = 90
    game_layer.add_child(top)
    hp1_bar = ProgressBar.new()
    hp1_bar.custom_minimum_size = Vector2(360, 28)
    hp1_bar.max_value = 100
    var left_hud = VBoxContainer.new()
    hud_name1 = _hud_name("РЫЦАРЬ")
    left_hud.add_child(hud_name1)
    left_hud.add_child(hp1_bar)
    ability_label1 = _hud_name("Способность готова")
    left_hud.add_child(ability_label1)
    top.add_child(left_hud)
    var spacer = Control.new()
    spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top.add_child(spacer)
    timer_label = Label.new()
    timer_label.add_theme_font_size_override("font_size", 28)
    top.add_child(timer_label)
    var spacer2 = Control.new()
    spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top.add_child(spacer2)
    hp2_bar = ProgressBar.new()
    hp2_bar.custom_minimum_size = Vector2(360, 28)
    hp2_bar.max_value = 100
    var right_hud = VBoxContainer.new()
    hud_name2 = _hud_name("РАЗБОЙНИК")
    right_hud.add_child(hud_name2)
    right_hud.add_child(hp2_bar)
    ability_label2 = _hud_name("Способность готова")
    right_hud.add_child(ability_label2)
    top.add_child(right_hud)
    var help = Label.new()
    help.text = "P1: WASD / левый стик • SPACE/A атака • Q/X способность     P2: стрелки / второй геймпад • ENTER/A атака • SHIFT/X способность"
    help.position = Vector2(245, 820)
    help.add_theme_font_size_override("font_size", 16)
    game_layer.add_child(help)
    var back = Button.new()
    back.text = "В МЕНЮ"
    back.position = Vector2(18, 820)
    back.pressed.connect(_back_menu)
    game_layer.add_child(back)

func _make_panel_style() -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.035, 0.045, 0.075, 0.94)
    style.border_color = Color("#b18a50")
    style.set_border_width_all(2)
    style.set_corner_radius_all(14)
    style.content_margin_left = 24
    style.content_margin_right = 24
    style.content_margin_top = 20
    style.content_margin_bottom = 20
    return style

func _play_sfx(stream: AudioStream):
    if sfx_player == null: return
    sfx_player.stream = stream
    sfx_player.play()

func _hud_name(value: String) -> Label:
    var label := Label.new()
    label.text = value
    label.add_theme_color_override("font_color", Color("#f2d7a0"))
    label.add_theme_font_size_override("font_size", 17)
    return label

func _build_story_ui():
    story_panel = PanelContainer.new()
    story_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    story_panel.custom_minimum_size = Vector2(760, 220)
    game_layer.add_child(story_panel)
    story_panel.visible = false
    var vb := VBoxContainer.new()
    story_panel.add_child(vb)
    story_label = Label.new()
    story_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    story_label.custom_minimum_size = Vector2(700, 130)
    story_label.add_theme_font_size_override("font_size", 21)
    vb.add_child(story_label)
    var next := Button.new()
    next.text = "ПРОДОЛЖИТЬ"
    next.pressed.connect(_advance_story)
    vb.add_child(next)

func _start_campaign():
    campaign_chapter = mini(campaign_option.selected, campaign_unlocked)
    char1 = int(CHAPTERS[campaign_chapter].hero)
    char2 = int(CHAPTERS[campaign_chapter].enemy)
    _start_game(Mode.CAMPAIGN)
    story_queue = CHAPTERS[campaign_chapter].lines.duplicate()
    story_active = true
    _advance_story()

func _advance_story():
    if story_queue.is_empty():
        story_panel.visible = false
        story_active = false
        status_text = "Глава %d — %s" % [campaign_chapter + 1, CHAPTERS[campaign_chapter].title]
        return
    story_label.text = story_queue.pop_front()
    story_panel.visible = true

func _show_settings():
    var dialog := AcceptDialog.new()
    dialog.title = "Настройки"
    dialog.dialog_text = "Управление: Игрок 1 — WASD / геймпад 1, SPACE/A — атака, Q/X — способность. Игрок 2 — стрелки / геймпад 2 (или первый геймпад, если он один), ENTER/A — атака, SHIFT/X — способность. Левый стик — движение."
    var content := VBoxContainer.new()
    var ml := Label.new()
    ml.text = "Музыка: %d%%" % int(music_volume * 100)
    content.add_child(ml)
    var ms := HSlider.new()
    ms.min_value = 0; ms.max_value = 1; ms.step = 0.05; ms.value = music_volume
    ms.value_changed.connect(_on_music_volume_changed)
    content.add_child(ms)
    var sl := Label.new()
    sl.text = "Звуковые эффекты: %d%%" % int(sfx_volume * 100)
    content.add_child(sl)
    var ss := HSlider.new()
    ss.min_value = 0; ss.max_value = 1; ss.step = 0.05; ss.value = sfx_volume
    ss.value_changed.connect(_on_sfx_volume_changed)
    content.add_child(ss)
    dialog.add_child(content)
    add_child(dialog)
    dialog.confirmed.connect(func(): _save_progress())
    dialog.popup_centered(Vector2i(420, 260))

func _on_music_volume_changed(value: float):
    music_volume = value
    music_player.volume_db = linear_to_db(max(value, 0.001))
    _save_progress()

func _on_sfx_volume_changed(value: float):
    sfx_volume = value
    sfx_player.volume_db = linear_to_db(max(value, 0.001))
    _save_progress()

func _load_progress():
    var cfg := ConfigFile.new()
    if cfg.load(save_path) == OK:
        campaign_unlocked = clampi(int(cfg.get_value("campaign", "unlocked", 0)), 0, CHAPTERS.size()-1)
        campaign_wins = int(cfg.get_value("campaign", "wins", 0))
        music_volume = float(cfg.get_value("audio", "music", 0.65))
        sfx_volume = float(cfg.get_value("audio", "sfx", 0.8))

func _save_progress():
    var cfg := ConfigFile.new()
    cfg.set_value("campaign", "unlocked", campaign_unlocked)
    cfg.set_value("campaign", "wins", campaign_wins)
    cfg.set_value("audio", "music", music_volume)
    cfg.set_value("audio", "sfx", sfx_volume)
    cfg.save(save_path)

func _add_button(parent: VBoxContainer, caption: String, action: Callable):
    var b = Button.new()
    b.text = caption
    b.custom_minimum_size = Vector2(0, 42)
    b.add_theme_font_size_override("font_size", 17)
    b.pressed.connect(_run_menu_action.bind(action))
    b.mouse_entered.connect(_play_sfx.bind(UI_SFX))
    parent.add_child(b)

func _run_menu_action(action: Callable):
    _play_sfx(UI_SFX)
    action.call()

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
    round_time = 90
    attack_cd = [0.0, 0.0]
    ability_cd = [0.0, 0.0]
    attack_flash = [0.0, 0.0]
    ability_flash = [0.0, 0.0]
    facing = [Vector2.RIGHT, Vector2.LEFT]
    roots = [0.0, 0.0]
    dark_zones = [{}, {}]
    dark_zone_ticks = [0.0, 0.0]
    projectiles.clear()
    effects.clear()
    last_round_finished = false
    attack_was_down = [false, false]
    ability_was_down = [false, false]
    status_text = "Меч: SPACE / ENTER     Способность: Q / SHIFT"
    menu_panel.visible = false
    game_layer.visible = true
    if music_player.stream != BATTLE_MUSIC:
        music_player.stream = BATTLE_MUSIC
        BATTLE_MUSIC.loop_mode = AudioStreamWAV.LOOP_FORWARD
        music_player.play()
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
    _save_progress()
    _disconnect_network()
    mode = Mode.MENU
    game_layer.visible = false
    menu_panel.visible = true
    status_label.text = "Выбери режим"
    if music_player.stream != MENU_MUSIC:
        music_player.stream = MENU_MUSIC
        music_player.play()
    queue_redraw()

func _process(delta):
    if mode == Mode.MENU: return
    _refresh_controllers()
    if story_active: return
    if hp1 <= 0 or hp2 <= 0 or round_time <= 0:
        if hp1 <= 0: status_text = "Победил " + CHAR_NAMES[char2] + "!"
        elif hp2 <= 0: status_text = "Победил " + CHAR_NAMES[char1] + "!"
        else: status_text = "Время вышло!"
        if mode == Mode.CAMPAIGN and not last_round_finished:
            last_round_finished = true
            if hp1 > hp2:
                campaign_unlocked = mini(campaign_unlocked + 1, CHAPTERS.size()-1)
                campaign_wins += 1
                _save_progress()
                status_text = "Глава пройдена! Следующая глава открыта."
            else:
                status_text = "Герой пал. Попробуй ещё раз."
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

    var m1 = _keyboard_move_1()
    var pads_for_move = Input.get_connected_joypads()
    var p1_pad := _assigned_pad(0)
    if p1_pad >= 0:
        var joy0 = _joy_move(p1_pad)
        if joy0.length() > 0.2: m1 = joy0
    if m1.length() > 0.1:
        p1 += m1.normalized() * _speed(char1) * (1.3 if _is_dark_prince_empowered(0) else 1.0) * delta
        facing[0] = m1.normalized()
    p1 = _clamp_player(p1)

    if mode == Mode.LOCAL:
        var m2 = _keyboard_move_2()
        var p2_pad := _assigned_pad(1)
        if p2_pad >= 0:
            var jm = _joy_move(p2_pad)
            if jm.length() > 0.2: m2 = jm
        if roots[1] <= 0 and m2.length() > 0.1:
            p2 += m2.normalized() * _speed(char2) * (1.3 if _is_dark_prince_empowered(1) else 1.0) * delta
            facing[1] = m2.normalized()
        var p2a := _p2_attack_pressed()
        var p2x := _p2_ability_pressed()
        if p2a and not attack_was_down[1]: _melee(1)
        if p2x and not ability_was_down[1]: _ability(1)
        attack_was_down[1] = p2a
        ability_was_down[1] = p2x
    elif mode == Mode.BOT or mode == Mode.CAMPAIGN:
        _bot_update(delta)
    elif mode == Mode.ONLINE:
        if not multiplayer.is_server(): _send_remote_state()

    var p1a := _p1_attack_pressed()
    var p1x := _p1_ability_pressed()
    if roots[0] <= 0 and p1a and not attack_was_down[0]: _melee(0)
    if p1x and not ability_was_down[0]: _ability(0)
    attack_was_down[0] = p1a
    ability_was_down[0] = p1x
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

func _assigned_pad(player: int) -> int:
    var pads := Input.get_connected_joypads()
    if pads.is_empty(): return -1
    if mode == Mode.LOCAL and pads.size() == 1:
        return -1 if player == 0 else pads[0]
    if player == 0: return pads[0]
    if pads.size() > 1: return pads[1]
    return -1

func _p1_attack_pressed() -> bool:
    return Input.is_key_pressed(KEY_SPACE) or _joy_button_down(_assigned_pad(0), JOY_BUTTON_A)

func _p1_ability_pressed() -> bool:
    return Input.is_key_pressed(KEY_Q) or _joy_button_down(_assigned_pad(0), JOY_BUTTON_X)

func _p2_attack_pressed() -> bool:
    return Input.is_key_pressed(KEY_ENTER) or _joy_button_down(_assigned_pad(1), JOY_BUTTON_A)

func _p2_ability_pressed() -> bool:
    return Input.is_key_pressed(KEY_SHIFT) or _joy_button_down(_assigned_pad(1), JOY_BUTTON_X)

func _joy_button_down(device: int, button: int) -> bool:
    return device >= 0 and Input.get_connected_joypads().has(device) and Input.is_joy_button_pressed(device, button)

func _refresh_controllers():
    var current := Input.get_connected_joypads()
    if current != last_pad_ids:
        last_pad_ids = current.duplicate()
        status_text = "Контроллеры: %d подключено" % current.size()

func _clamp_player(p: Vector2) -> Vector2:
    return Vector2(clamp(p.x, 235, 1365), clamp(p.y, 270, 690))

func _speed(character: int) -> float:
    return [260.0, 330.0, 270.0, 215.0, 250.0][character]

func _bot_update(delta):
    var dir = p1 - p2
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
    _play_sfx(SWORD_SFX)
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
        _play_sfx(HIT_SFX)
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
    _play_sfx(SWORD_SFX)
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
        4: # Dark Prince: ten-second shadow dominion
            var zone_center = attacker.lerp(target, 0.42)
            dark_zones[player] = {"center": zone_center, "radius": 285.0, "life": 10.0}
            _play_sfx(SHADOW_SFX)
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

func _damage(player: int, amount: float):
    if player == 0: hp1 = max(0.0, hp1-amount)
    else: hp2 = max(0.0, hp2-amount)

func _update_effects(delta):
    for i in range(effects.size()-1,-1,-1):
        effects[i].life -= delta
        if effects[i].life <= 0: effects.remove_at(i)

func _update_hud():
    hp1_bar.value = hp1
    hp2_bar.value = hp2
    timer_label.text = "%02d:%02d" % [int(round_time/60), int(round_time)%60]
    hud_name1.text = CHAR_NAMES[char1].to_upper()
    hud_name2.text = CHAR_NAMES[char2].to_upper()
    ability_label1.text = "Способность: ГОТОВА" if ability_cd[0] <= 0.0 else "Способность: %.1f с" % ability_cd[0]
    ability_label2.text = "Способность: ГОТОВА" if ability_cd[1] <= 0.0 else "Способность: %.1f с" % ability_cd[1]
    if mode == Mode.CAMPAIGN and hp1 > hp2: timer_label.add_theme_color_override("font_color", Color("#e6c27b"))
    if story_active: story_panel.visible = true

func _send_remote_state():
    net_send_timer += get_process_delta_time()
    if net_send_timer > 0.05:
        net_send_timer = 0
        rpc_id(1, "_receive_remote_position", p1)

@rpc("any_peer","call_remote","unreliable")
func _receive_remote_position(pos: Vector2):
    if multiplayer.is_server(): p2 = _clamp_player(pos)

func _draw():
    draw_texture_rect(ARENA, Rect2(0,0,1600,900), false)
    if mode == Mode.MENU:
        var t := Time.get_ticks_msec() * 0.001
        for i in range(32):
            var x := fposmod(float(i) * 97.0 + sin(t * 0.22 + float(i)) * 42.0, 1600.0)
            var y := fposmod(float(i) * 53.0 - t * (9.0 + float(i % 5) * 2.0), 900.0)
            var alpha := 0.18 + 0.22 * (0.5 + 0.5 * sin(t + float(i)))
            draw_circle(Vector2(x, y), 1.5 + float(i % 3), Color(1.0, 0.68, 0.32, alpha))
        return
    for owner in range(2):
        if not dark_zones[owner].is_empty():
            var zc: Vector2 = dark_zones[owner].center
            var zr: float = dark_zones[owner].radius
            var fade = clamp(float(dark_zones[owner].life) / 1.2, 0.0, 1.0)
            draw_circle(zc, zr, Color(0.035,0.018,0.075,0.56*fade))
            draw_arc(zc, zr, 0, TAU, 80, Color(0.48,0.25,0.78,0.8*fade), 7)
            for n in range(8):
                var angle = TAU * float(n) / 8.0
                var base = zc + Vector2(cos(angle),sin(angle))*zr*0.64
                var sway = sin(Time.get_ticks_msec() * 0.003 + float(n)) * 24.0
                var side = Vector2(-sin(angle), cos(angle))
                var points := PackedVector2Array([base, base + Vector2(cos(angle),sin(angle))*35 + side*sway*0.35, base + Vector2(cos(angle+0.25),sin(angle+0.25))*72 + side*sway, base + Vector2(cos(angle+0.5),sin(angle+0.5))*112])
                draw_polyline(points, Color(0.035,0.018,0.055,0.98*fade), 19, true)
                draw_polyline(points, Color(0.55,0.31,0.83,0.88*fade), 4, true)
                draw_circle(points[3], 8.0, Color(0.78,0.58,1.0,fade))
    draw_circle(p1+Vector2(0,32),45,Color(0.65,0.12,0.10,0.22))
    draw_circle(p2+Vector2(0,32),45,Color(0.12,0.38,0.78,0.22))
    draw_texture(CHAR_TEXTURES[char1], p1-Vector2(96,96))
    draw_texture(CHAR_TEXTURES[char2], p2-Vector2(96,96))
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
    if attack_flash[0] > 0:
        draw_arc(p1+facing[0]*42,68,-1.3,1.3,20,CHAR_COLORS[char1],8)
    if attack_flash[1] > 0:
        draw_arc(p2+facing[1]*42,68,PI-1.3,PI+1.3,20,CHAR_COLORS[char2],8)
    draw_string(ThemeDB.fallback_font,Vector2(460,850),status_text,HORIZONTAL_ALIGNMENT_CENTER,700,18,Color("#fff0d0"))
    if roots[0] > 0: draw_string(ThemeDB.fallback_font,p1+Vector2(-25,-70),"ROOTED",HORIZONTAL_ALIGNMENT_CENTER,100,14,Color("#b4e47d"))
    if roots[1] > 0: draw_string(ThemeDB.fallback_font,p2+Vector2(-25,-70),"ROOTED",HORIZONTAL_ALIGNMENT_CENTER,100,14,Color("#b4e47d"))
