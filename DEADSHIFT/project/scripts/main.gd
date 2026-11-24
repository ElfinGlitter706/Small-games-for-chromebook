extends Node3D

@onready var player: Node3D = $Player
@onready var camera: Camera3D = $Player/Camera3D
var zombies: Array[Node3D] = []
var health := 100
var ammo := 12
var round_number := 0
var kills := 0
var points := 0
var magazine := 12
var started := false
var shop_open := false
var cooldown := 0.0
var damage_cooldown := 0.0
var next_round := -1.0
var game_over := false
var hud: Label
var hint: Label
var menu: PanelContainer
var shop: PanelContainer
var shop_status: Label
var navigation = preload("res://scripts/navigation.gd").new()
var doors: Array[Dictionary] = []
var weapon := Node3D.new()
var hit_marker: Label
var interaction: Label
var recoil := 0.0
var hit_time := 0.0
var reload_time := 0.0
var elapsed := 0.0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for x in [-12.0, 12.0]:
		for z in [-7.0, 7.0]: _box(Vector3(0.4, 3, 10), Vector3(x, 1.4, z), Color.DARK_SLATE_GRAY)
		var gate := _box(Vector3(0.4, 2.8, 4), Vector3(x, 1.4, 0), Color(0.65, 0.32, 0.12))
		doors.append({"mesh": gate, "position": Vector3(x, 0, 0), "cost": 300, "open": false})
		var side: float = signf(x)
		_box(Vector3(12, 0.2, 12), Vector3(side * 18, 0, 0), Color(0.22, 0.26, 0.29), null, false)
		_box(Vector3(0.4, 3, 12), Vector3(side * 24, 1.4, 0), Color.DARK_SLATE_GRAY)
		for z in [-6.0, 6.0]: _box(Vector3(12, 3, 0.4), Vector3(side * 18, 1.4, z), Color.DARK_SLATE_GRAY)
		_box(Vector3(1.4, 2, 1.4), Vector3(side * 18, 1, 2), Color(0.18, 0.35, 0.4))
	for z in [-12.0, 12.0]: _box(Vector3(24, 3, 0.4), Vector3(0, 1.4, z), Color.DARK_SLATE_GRAY)
	_box(Vector3(2, 1, 2), Vector3(-4, 0.5, -3), Color.SADDLE_BROWN)
	_box(Vector3(2, 1, 2), Vector3(4, 0.5, 2), Color.SADDLE_BROWN)
	for spot in [Vector3(-8, 0, -8), Vector3(8, 0, -8), Vector3(-8, 0, 8), Vector3(8, 0, 8)]:
		_box(Vector3(0.7, 3.6, 0.7), spot + Vector3(0, 1.8, 0), Color(0.14, 0.17, 0.2))
		_box(Vector3(0.9, 0.25, 0.9), spot + Vector3(0, 3.7, 0), Color(0.7, 0.22, 0.08))
	camera.add_child(weapon)
	_box(Vector3(0.35, 0.22, 0.6), Vector3(0.35, -0.28, -0.7), Color(0.16, 0.19, 0.22), weapon)
	_box(Vector3(0.1, 0.1, 0.5), Vector3(0.35, -0.17, -0.9), Color(0.42, 0.43, 0.4), weapon)
	navigation.rebuild()
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(20, 16)
	hud.add_theme_font_size_override("font_size", 24)
	layer.add_child(hud)
	hint = Label.new()
	hint.position = Vector2(20, 55)
	hint.text = "WASD move  |  Click shoot  |  R reload  |  E buy nearby barricade  |  B upgrades  |  Esc pause"
	layer.add_child(hint)
	var crosshair := Label.new()
	crosshair.text = "+"
	crosshair.position = Vector2(630, 342)
	crosshair.add_theme_font_size_override("font_size", 30)
	layer.add_child(crosshair)
	hit_marker = Label.new()
	hit_marker.text = "×"
	hit_marker.position = Vector2(629, 345)
	hit_marker.add_theme_font_size_override("font_size", 32)
	hit_marker.modulate = Color(1, 0.3, 0.15)
	hit_marker.visible = false
	layer.add_child(hit_marker)
	interaction = Label.new()
	interaction.position = Vector2(400, 640)
	interaction.add_theme_font_size_override("font_size", 22)
	layer.add_child(interaction)
	menu = _panel(layer, "DEADSHIFT\n\nSURVIVE THE OUTPOST", "START GAME", _begin_game)
	shop = _panel(layer, "SUPPLY STATION", "BUY MEDKIT — 100 POINTS", _buy_medkit)
	shop.visible = false
	var shop_box: VBoxContainer = shop.get_child(0)
	var upgrade := Button.new()
	upgrade.text = "BIGGER MAGAZINE — 200 POINTS"
	upgrade.pressed.connect(_buy_magazine)
	shop_box.add_child(upgrade)
	shop_status = Label.new()
	shop_box.add_child(shop_status)
	var close := Button.new()
	close.text = "BACK TO GAME"
	close.pressed.connect(_close_shop)
	shop_box.add_child(close)
	_update_hud()

func _panel(layer: CanvasLayer, title: String, button_text: String, action: Callable) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(420, 190)
	panel.custom_minimum_size = Vector2(440, 260)
	layer.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)
	var heading := Label.new()
	heading.text = title
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 30)
	box.add_child(heading)
	var button := Button.new()
	button.text = button_text
	button.custom_minimum_size.y = 52
	button.pressed.connect(action)
	box.add_child(button)
	return panel

func _begin_game() -> void:
	if not started:
		started = true
		menu.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_start_round()
	else:
		menu.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _open_shop() -> void:
	if not started or game_over or menu.visible: return
	shop_open = true
	shop.visible = true
	shop_status.text = "POINTS: %d" % points
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _close_shop() -> void:
	shop_open = false
	shop.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _buy_medkit() -> bool:
	if not shop_open or points < 100 or health >= 100: return false
	points -= 100
	health = mini(100, health + 40)
	shop_status.text = "MEDKIT BOUGHT  •  POINTS: %d" % points
	_update_hud()
	return true

func _buy_magazine() -> bool:
	if not shop_open or points < 200 or magazine >= 24: return false
	points -= 200
	magazine += 6
	ammo = magazine
	shop_status.text = "MAGAZINE UPGRADED  •  POINTS: %d" % points
	_update_hud()
	return true

func _box(size: Vector3, location: Vector3, color: Color, parent: Node3D = null, solid: bool = true) -> MeshInstance3D:
	var box := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	box.mesh = mesh
	box.position = location
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	box.material_override = material
	if parent == null:
		add_child(box)
		if solid: navigation.add_obstacle(box, size, location)
	else: parent.add_child(box)
	return box

func _start_round() -> void:
	round_number += 1
	next_round = -1.0
	ammo = magazine
	for i in range(round_number + 2): _spawn_zombie(i)
	_update_hud()

func _spawn_zombie(index: int) -> void:
	var zombie := Node3D.new()
	var angle := TAU * float(index) / float(round_number + 2)
	zombie.position = Vector3(cos(angle) * 9, 0, sin(angle) * 9)
	for attempt in range(64):
		if navigation.clear_at(zombie.position, 0.6): break
		var safe_angle := angle + attempt * 0.15
		zombie.position = Vector3(cos(safe_angle) * 9, 0, sin(safe_angle) * 9)
	_box(Vector3(0.7, 0.9, 0.4), Vector3(0, 1.15, 0), Color(0.16, 0.27, 0.22), zombie)
	_box(Vector3(0.42, 0.42, 0.42), Vector3(0, 1.82, 0), Color(0.38, 0.55, 0.36), zombie)
	for side in [-1.0, 1.0]:
		_box(Vector3(0.22, 0.75, 0.22), Vector3(side * 0.49, 1.05, 0), Color(0.36, 0.52, 0.34), zombie)
		_box(Vector3(0.25, 0.7, 0.28), Vector3(side * 0.2, 0.35, 0), Color(0.13, 0.16, 0.2), zombie)
		_box(Vector3(0.1, 0.09, 0.05), Vector3(side * 0.13, 1.85, -0.23), Color(0.95, 0.17, 0.08), zombie)
	add_child(zombie)
	zombies.append(zombie)
	zombie.set_meta("path", PackedVector2Array())
	zombie.set_meta("repath", 0.0)
	zombie.set_meta("attack", 0.0)

func _update_hud() -> void:
	hud.text = "ROUND %d    HEALTH %d    AMMO %d/%d    ZOMBIES %d    POINTS %d" % [round_number, health, ammo, magazine, zombies.size(), points]
	if game_over: hint.text = "GAME OVER — Press Enter to restart"

func _shoot() -> void:
	if not started or shop_open or menu.visible or game_over or ammo == 0 or cooldown > 0 or reload_time > 0: return
	ammo -= 1
	cooldown = 0.18
	recoil = 1.0
	var origin := camera.global_position
	var direction := -camera.global_basis.z
	var target: Node3D = null
	var nearest := 60.0
	for zombie in zombies:
		var center := zombie.global_position + Vector3.UP
		var distance := (center - origin).dot(direction)
		if distance > 0 and distance < nearest and (center - origin - direction * distance).length() < 0.9 and not navigation.blocked_ray(origin, center):
			target = zombie
			nearest = distance
	if target != null:
		hit_time = 0.18
		zombies.erase(target)
		target.queue_free()
		kills += 1
		points += 100
		if zombies.is_empty(): next_round = 2.0
	_update_hud()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		player.rotate_y(-event.relative.x * 0.0025)
		camera.rotate_x(-event.relative.y * 0.0025)
		camera.rotation.x = clampf(camera.rotation.x, -1.4, 1.4)
	elif event is InputEventMouseButton and event.pressed:
		if started and not shop_open and not menu.visible and not game_over:
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			if event.button_index == MOUSE_BUTTON_LEFT: _shoot()
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if shop_open: _close_shop()
			elif started and not game_over:
				menu.visible = not menu.visible
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if menu.visible else Input.MOUSE_MODE_CAPTURED
		elif event.keycode == KEY_B:
			if shop_open: _close_shop()
			else: _open_shop()
		elif event.keycode == KEY_R and not game_over:
			if started and not menu.visible and not shop_open and ammo < magazine and reload_time == 0: reload_time = 1.2
		elif event.keycode == KEY_E:
			_try_door()
		elif event.keycode == KEY_ENTER and game_over: get_tree().reload_current_scene()

func _process(delta: float) -> void:
	if game_over or not started or shop_open or menu.visible: return
	elapsed += delta
	recoil = move_toward(recoil, 0, delta * 7)
	weapon.position.z = recoil * 0.13
	weapon.rotation.x = recoil * 0.18
	hit_time = maxf(0, hit_time - delta)
	hit_marker.visible = hit_time > 0
	if reload_time > 0:
		reload_time = maxf(0, reload_time - delta)
		weapon.rotation.z = sin(reload_time / 1.2 * PI) * 0.7
		if reload_time == 0:
			ammo = magazine
			_update_hud()
	interaction.text = "RELOADING…" if reload_time > 0 else ""
	for door in doors:
		if not door.open and player.position.distance_to(door.position + Vector3(0, 1.7, 0)) < 3:
			interaction.text = "E — OPEN ROOM: %d POINTS" % door.cost
	cooldown = maxf(0, cooldown - delta)
	damage_cooldown = maxf(0, damage_cooldown - delta)
	if game_over or not started or shop_open or menu.visible: return
	var axis := Vector2.ZERO
	if Input.is_key_pressed(KEY_W): axis.y -= 1
	if Input.is_key_pressed(KEY_S): axis.y += 1
	if Input.is_key_pressed(KEY_A): axis.x -= 1
	if Input.is_key_pressed(KEY_D): axis.x += 1
	player.position = navigation.move(player.position, (player.basis * Vector3(axis.x, 0, axis.y)).normalized() * 6 * delta)
	for zombie in zombies:
		var toward := player.position - zombie.position
		toward.y = 0
		var repath: float = zombie.get_meta("repath") - delta
		if repath <= 0:
			zombie.set_meta("path", navigation.path(zombie.position, player.position))
			repath = 0.4
		zombie.set_meta("repath", repath)
		var route: PackedVector2Array = zombie.get_meta("path")
		var movement := Vector3.ZERO
		while route.size() > 0 and Vector2(zombie.position.x, zombie.position.z).distance_to(route[0]) < 0.2: route.remove_at(0)
		if toward.length() > 1.15 and route.size() > 0:
			movement = Vector3(route[0].x - zombie.position.x, 0, route[0].y - zombie.position.z).normalized()
			zombie.position = navigation.move(zombie.position, movement * minf(2.8, 1.6 + round_number * 0.08) * delta)
			zombie.rotation.y = lerp_angle(zombie.rotation.y, atan2(-movement.x, -movement.z), delta * 8)
			var separation := Vector3.ZERO
			for neighbor in zombies:
				if neighbor == zombie: continue
				var away := zombie.position - neighbor.position
				away.y = 0
				if away.length() > 0.01 and away.length() < 0.85: separation += away.normalized() * (0.85 - away.length())
			zombie.position = navigation.move(zombie.position, separation * delta * 2)
		zombie.set_meta("path", route)
		var attack: float = zombie.get_meta("attack")
		if toward.length() < 1.4 and not navigation.blocked_ray(zombie.position + Vector3.UP, player.position): attack += delta
		else: attack = 0
		var swing := sin(elapsed * 8 + zombie.get_instance_id()) * 0.4 if movement.length() > 0 else 0.0
		zombie.get_child(2).rotation.x = -minf(attack, 0.65) * 1.6 + swing
		zombie.get_child(5).rotation.x = -minf(attack, 0.65) * 1.6 - swing
		zombie.get_child(3).rotation.x = -swing
		zombie.get_child(6).rotation.x = swing
		zombie.get_child(0).position.y = 1.15 + absf(swing) * 0.08
		zombie.set_meta("attack", attack)
		if attack >= 0.65 and damage_cooldown == 0:
			zombie.set_meta("attack", 0.0)
			health = maxi(0, health - 10)
			damage_cooldown = 0.8
			if health == 0:
				game_over = true
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			_update_hud()
	if next_round > 0:
		next_round -= delta
		if next_round <= 0: _start_round()

func _try_door() -> bool:
	if not started or game_over or menu.visible or shop_open: return false
	for door in doors:
		if door.open or player.position.distance_to(door.position + Vector3(0, 1.7, 0)) >= 3: continue
		if points < door.cost:
			interaction.text = "NOT ENOUGH POINTS"
			return false
		points -= door.cost
		door.open = true
		door.mesh.visible = false
		navigation.rebuild()
		_update_hud()
		return true
	return false
