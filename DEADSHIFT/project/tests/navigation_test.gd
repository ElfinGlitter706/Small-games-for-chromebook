extends SceneTree

func _initialize() -> void:
	call_deferred("run_checks")

func verify(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		quit(1)
		assert(condition, message)

func run_checks() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game._begin_game()
	var nav = game.navigation
	verify(not nav.clear_at(Vector3(-8, 0, -8)), "Pillar must block movement")
	var stopped: Vector3 = nav.move(Vector3(-8, 1.7, -6), Vector3(0, 0, -5))
	verify(stopped.z > -7.3, "Swept movement must stop at pillar")
	verify(nav.blocked_ray(Vector3(-4, 0.7, 0), Vector3(-4, 0.7, -6)), "Crate must block shots")
	verify(nav.path(Vector3(10, 0, 0), Vector3(16, 0, 0)).is_empty(), "Locked room must be unreachable")
	verify(nav.blocked_ray(Vector3(10, 1.7, 0), Vector3(16, 1.7, 0)), "Barricade blocks bullets")
	game.player.position = Vector3(10, 1.7, 0)
	game.points = 299
	verify(not game._try_door(), "Cannot buy door without points")
	game.points = 600
	verify(game._try_door(), "Door purchase succeeds nearby")
	verify(game.points == 300, "Door charges exactly 300")
	verify(not game._try_door(), "Door cannot be purchased twice")
	verify(not nav.path(Vector3(10, 0, 0), Vector3(16, 0, 0)).is_empty(), "Open room is reachable")
	var crossed: Vector3 = nav.move(Vector3(10, 1.7, 0), Vector3(6, 0, 0))
	verify(crossed.x > 15, "Player can cross purchased doorway")
	var enemy: Node3D = game.zombies[0]
	for other in game.zombies.duplicate():
		if other != enemy:
			game.zombies.erase(other)
			other.queue_free()
	enemy.position = Vector3(-4, 0, 0)
	enemy.set_meta("repath", 0.0)
	game.player.position = Vector3(-4, 1.7, -6)
	for frame in range(600):
		game._process(1.0 / 60.0)
		verify(nav.clear_at(enemy.position), "Zombie must not enter solid geometry")
	verify(Vector2(enemy.position.x + 4, enemy.position.z + 6).length() < 1.5, "Zombie must navigate around crate to player")
	verify(game.health < 100, "Zombie must wind up and attack player")
	game.health = 100
	game.game_over = false
	enemy.position = Vector3(9, 0, 0)
	enemy.set_meta("repath", 0.0)
	game.player.position = Vector3(16, 1.7, 0)
	for frame in range(360): game._process(1.0 / 60.0)
	verify(enemy.position.x > 13, "Zombie must follow player through bought door")
	game.player.position = Vector3(0, 1.7, 6)
	game.player.rotation = Vector3.ZERO
	game.camera.rotation = Vector3.ZERO
	enemy.position = Vector3(0, 0, 3)
	game.cooldown = 0.0
	game._shoot()
	verify(game.hit_time > 0 and game.recoil > 0, "Hit must trigger marker and recoil")
	game.reload_time = 1.2
	game.ammo = 0
	game._process(0.6)
	verify(game.ammo == 0, "Reload must take time")
	game._process(0.6)
	verify(game.ammo == game.magazine, "Reload completes after delay")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	game._unhandled_input(click)
	verify(game.ammo == game.magazine - 1, "Mouse capture fallback must still fire")
	print("COLLISION_DOORS_NAVIGATION_ATTACKS_RECOIL_PASSED")
	quit(0)
