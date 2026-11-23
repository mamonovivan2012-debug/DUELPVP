extends Node2D

const ARENA = preload("res://assets/arena.png")
const HERO_RED = preload("res://assets/hero_red.png")
const HERO_BLUE = preload("res://assets/hero_blue.png")
const BOT = preload("res://assets/bot.png")

enum Mode { MENU, LOCAL, BOT, ONLINE }
var mode = Mode.MENU
var p1 := Vector2(500, 470)
var p2 := Vector2(1100, 470)
var hp1 := 100.0
var hp2 := 100.0
var round_time := 90.0
var cooldown1 := 0.0
var cooldown2 := 0.0
var projectiles: Array[Dictionary] = []
var bot_level := 1
var peer: ENetMultiplayerPeer
var online_ready := false
var net_send_timer := 0.0
var status_text := "Выбери режим"
var ip_field: LineEdit
var menu_layer: CanvasLayer
var game_layer: CanvasLayer
var hp1_bar: ProgressBar
var hp2_bar: ProgressBar
var timer_label: Label
var status_label: Label
var menu_panel: PanelContainer
var bot_option: OptionButton
var ip_input: LineEdit

func _ready():
    _build_ui()
    set_process(true)
    queue_redraw()

func _build_ui():
    menu_layer = CanvasLayer.new()
    add_child(menu_layer)
    menu_panel = PanelContainer.new()
    menu_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    menu_panel.custom_minimum_size = Vector2(460, 540)
    menu_layer.add_child(menu_panel)
    var vb = VBoxContainer.new()
    vb.add_theme_constant_override("separation", 14)
    menu_panel.add_child(vb)
    var title = Label.new()
    title.text = "ARENA DUEL"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 42)
    title.add_theme_color_override("font_color", Color("#f1d5a5"))
    vb.add_child(title)
    var sub = Label.new()
    sub.text = "СРАЖАЙСЯ. ПОБЕЖДАЙ. ДОКАЖИ!"
    sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    sub.add_theme_color_override("font_color", Color("#d6c4a4"))
    vb.add_child(sub)
    _add_button(vb, "ОНЛАЙН PvP — СОЗДАТЬ КОМНАТУ", _host_online)
    ip_input = LineEdit.new()
    ip_input.placeholder_text = "IP второго компьютера (например, 192.168.1.10)"
    ip_input.text = "127.0.0.1"
    vb.add_child(ip_input)
    _add_button(vb, "ПОДКЛЮЧИТЬСЯ К ОНЛАЙН PvP", _join_online)
    _add_button(vb, "ЛОКАЛЬНЫЙ PvP — 2 ИГРОКА", _start_local)
    _add_button(vb, "PvB — ПРОТИВ БОТА", _start_bot)
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
    status_label.text = "Локальная игра работает без интернета."
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status_label.add_theme_color_override("font_color", Color("#e7c98f"))
    vb.add_child(status_label)
    _add_button(vb, "ВЫХОД", func(): get_tree().quit())
    game_layer = CanvasLayer.new()
    add_child(game_layer)
    game_layer.visible = false
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
    top.add_child(hp1_bar)
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
    top.add_child(hp2_bar)
    var back = Button.new()
    back.text = "В МЕНЮ"
    back.position = Vector2(18, 820)
    back.pressed.connect(_back_menu)
    game_layer.add_child(back)

func _add_button(parent: VBoxContainer, caption: String, action: Callable):
    var b = Button.new()
    b.text = caption
    b.custom_minimum_size = Vector2(0, 48)
    b.add_theme_font_size_override("font_size", 18)
    b.pressed.connect(action)
    parent.add_child(b)

func _start_local():
    _start_game(Mode.LOCAL)

func _start_bot():
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
    projectiles.clear()
    status_text = "Игрок 1: WASD + ПРОБЕЛ     Игрок 2: СТРЕЛКИ + ENTER"
    menu_panel.visible = false
    game_layer.visible = true
    queue_redraw()

func _host_online():
    _start_game(Mode.ONLINE)
    peer = ENetMultiplayerPeer.new()
    var err = peer.create_server(2456, 1)
    if err != OK:
        status_label.text = "Не удалось открыть порт 2456: " + str(err)
        _back_menu()
        return
    multiplayer.multiplayer_peer = peer
    status_text = "Комната создана. Сообщи другу свой IP; порт 2456 UDP."
    status_label.text = status_text

func _join_online():
    var address = ip_input.text.strip_edges()
    if address.is_empty():
        address = "127.0.0.1"
    _start_game(Mode.ONLINE)
    peer = ENetMultiplayerPeer.new()
    var err = peer.create_client(address, 2456)
    if err != OK:
        status_label.text = "Не удалось подключиться: " + str(err)
        _back_menu()
        return
    multiplayer.multiplayer_peer = peer
    status_text = "Подключение к " + address
    multiplayer.connected_to_server.connect(func(): status_text = "Подключено! Играй за синего бойца.", CONNECT_ONE_SHOT)
    multiplayer.connection_failed.connect(func(): status_text = "Ошибка подключения. Проверь IP и порт.", CONNECT_ONE_SHOT)

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
    queue_redraw()

func _process(delta):
    if mode == Mode.MENU:
        return
    if hp1 <= 0 or hp2 <= 0 or round_time <= 0:
        if round_time > 0:
            status_text = "Победил " + ("Игрок 2" if hp1 <= 0 else "Игрок 1") + "!"
        else:
            status_text = "Время вышло!"
        _draw_hud()
        return
    round_time = max(0.0, round_time - delta)
    cooldown1 = max(0.0, cooldown1 - delta)
    cooldown2 = max(0.0, cooldown2 - delta)
    var move1 = Vector2(
        Input.get_action_strength("ui_right") * 0.0 + float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
        float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
    )
    if move1.length() > 0:
        p1 += move1.normalized() * 260 * delta
    p1 = _clamp_player(p1)
    if mode == Mode.LOCAL:
        var move2 = Vector2(float(Input.is_key_pressed(KEY_RIGHT))-float(Input.is_key_pressed(KEY_LEFT)), float(Input.is_key_pressed(KEY_DOWN))-float(Input.is_key_pressed(KEY_UP)))
        if move2.length() > 0:
            p2 += move2.normalized() * 260 * delta
        if Input.is_key_pressed(KEY_ENTER) and cooldown2 <= 0:
            _shoot(2)
    elif mode == Mode.BOT:
        _bot_update(delta)
    elif mode == Mode.ONLINE:
        if multiplayer.is_server():
            pass
        else:
            _send_remote_state()
    if Input.is_key_pressed(KEY_SPACE) and cooldown1 <= 0:
        _shoot(1)
    _update_projectiles(delta)
    p2 = _clamp_player(p2)
    hp1_bar.value = hp1
    hp2_bar.value = hp2
    timer_label.text = "%02d:%02d" % [int(round_time)/60, int(round_time)%60]
    queue_redraw()

func _clamp_player(p: Vector2) -> Vector2:
    return Vector2(clamp(p.x, 235, 1365), clamp(p.y, 270, 690))

func _bot_update(delta):
    var dir = p1 - p2
    if dir.length() > 230:
        p2 += dir.normalized() * (150 + bot_level * 55) * delta
    elif dir.length() < 155:
        p2 -= dir.normalized() * (90 + bot_level * 35) * delta
    if cooldown2 <= 0 and dir.length() < 620:
        _shoot(2)

func _shoot(player: int):
    if player == 1:
        cooldown1 = 0.55
        var dir = (p2-p1).normalized()
        projectiles.append({"pos":p1+dir*50,"vel":dir*620,"owner":1,"life":1.3,"damage":10})
    else:
        cooldown2 = 0.8 - bot_level*0.12
        var dir2 = (p1-p2).normalized()
        projectiles.append({"pos":p2+dir2*50,"vel":dir2*560,"owner":2,"life":1.4,"damage":10})

func _update_projectiles(delta):
    for i in range(projectiles.size()-1,-1,-1):
        var pr = projectiles[i]
        pr.pos += pr.vel * delta
        pr.life -= delta
        var target = p2 if pr.owner == 1 else p1
        if pr.pos.distance_to(target) < 48:
            if pr.owner == 1: hp2 = max(0,hp2-pr.damage)
            else: hp1 = max(0,hp1-pr.damage)
            projectiles.remove_at(i)
        elif pr.life <= 0:
            projectiles.remove_at(i)
        else:
            projectiles[i] = pr

func _send_remote_state():
    net_send_timer += get_process_delta_time()
    if net_send_timer > 0.05:
        net_send_timer = 0
        rpc_id(1, "_receive_remote_position", p1)

@rpc("any_peer","call_remote","unreliable")
func _receive_remote_position(pos: Vector2):
    if multiplayer.is_server():
        p2 = _clamp_player(pos)

func _draw():
    draw_texture_rect(ARENA, Rect2(0,0,1600,900), false)
    if mode == Mode.MENU:
        return
    draw_circle(p1+Vector2(0,32),45,Color(0.65,0.12,0.10,0.22))
    draw_circle(p2+Vector2(0,32),45,Color(0.12,0.38,0.78,0.22))
    draw_texture(HERO_RED, p1-Vector2(96,96))
    draw_texture(BOT if mode == Mode.BOT else HERO_BLUE, p2-Vector2(96,96))
    for pr in projectiles:
        var col = Color("#ff9a36") if pr.owner == 1 else Color("#74cfff")
        draw_circle(pr.pos,15,col)
        draw_circle(pr.pos,25,Color(col.r,col.g,col.b,0.25))
    if status_text != "":
        draw_string(ThemeDB.fallback_font,Vector2(460,850),status_text,HORIZONTAL_ALIGNMENT_CENTER,700,18,Color("#fff0d0"))

func _draw_hud():
    if timer_label:
        timer_label.text = "00:00"
