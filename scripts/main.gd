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
var timer_label: Label
var status_label: Label
var menu_panel: PanelContainer
var bot_option: OptionButton
var ip_input: LineEdit
var char1_option: OptionButton
var char2_option: OptionButton

func _ready():
    _build_ui()
    set_process(true)
    queue_redraw()

func _build_ui():
    menu_layer = CanvasLayer.new()
    add_child(menu_layer)
    menu_panel = PanelContainer.new()
    menu_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    menu_panel.custom_minimum_size = Vector2(520, 690)
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
    var help = Label.new()
    help.text = "P1: WASD / геймпад • SPACE меч • Q способность     P2: стрелки / геймпад • ENTER меч • SHIFT способность"
    help.position = Vector2(245, 820)
    help.add_theme_font_size_override("font_size", 16)
    game_layer.add_child(help)
    var back = Button.new()
    back.text = "В МЕНЮ"
    back.position = Vector2(18, 820)
    back.pressed.connect(_back_menu)
    game_layer.add_child(back)

func _add_button(parent: VBoxContainer, caption: String, action: Callable):
    var b = Button.new()
    b.text = caption
    b.custom_minimum_size = Vector2(0, 42)
    b.add_theme_font_size_override("font_size", 17)
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
    status_text = "Меч: SPACE / ENTER     Способность: Q / SHIFT"
    menu_panel.visible = false
    game_layer.visible = true
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
    queue_redraw()

func _process(delta):
    if mode == Mode.MENU: return
    if hp1 <= 0 or hp2 <= 0 or round_time <= 0:
        if hp1 <= 0: status_text = "Победил " + CHAR_NAMES[char2] + "!"
        elif hp2 <= 0: status_text = "Победил " + CHAR_NAMES[char1] + "!"
        else: status_text = "Время вышло!"
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
    if pads_for_move.size() > 1:
        var joy0 = _joy_move(0)
        if joy0.length() > 0.2: m1 = joy0
    if m1.length() > 0.1:
        p1 += m1.normalized() * _speed(char1) * (1.3 if _is_dark_prince_empowered(0) else 1.0) * delta
        facing[0] = m1.normalized()
    p1 = _clamp_player(p1)

    if mode == Mode.LOCAL:
        var m2 = _keyboard_move_2()
        var connected = Input.get_connected_joypads()
        if connected.size() > 0:
            var joy_index = 1 if connected.size() > 1 else 0
            var jm = _joy_move(joy_index)
            if jm.length() > 0.2: m2 = jm
        if roots[1] <= 0 and m2.length() > 0.1:
            p2 += m2.normalized() * _speed(char2) * (1.3 if _is_dark_prince_empowered(1) else 1.0) * delta
            facing[1] = m2.normalized()
        if _p2_attack_pressed(): _melee(1)
        if _p2_ability_pressed(): _ability(1)
    elif mode == Mode.BOT:
        _bot_update(delta)
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
    return Input.is_key_pressed(KEY_SPACE) or (pads.size() > 1 and Input.is_joy_button_pressed(0, JOY_BUTTON_A))

func _p1_ability_pressed() -> bool:
    var pads = Input.get_connected_joypads()
    return Input.is_key_pressed(KEY_Q) or (pads.size() > 1 and Input.is_joy_button_pressed(0, JOY_BUTTON_X))

func _p2_attack_pressed() -> bool:
    var pads = Input.get_connected_joypads()
    var j = 1 if pads.size() > 1 else 0
    return Input.is_key_pressed(KEY_ENTER) or (pads.size() > 0 and Input.is_joy_button_pressed(j, JOY_BUTTON_A))

func _p2_ability_pressed() -> bool:
    var pads = Input.get_connected_joypads()
    var j = 1 if pads.size() > 1 else 0
    return Input.is_key_pressed(KEY_SHIFT) or (pads.size() > 0 and Input.is_joy_button_pressed(j, JOY_BUTTON_X))

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
    if mode == Mode.MENU: return
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
