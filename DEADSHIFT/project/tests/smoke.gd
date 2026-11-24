extends SceneTree

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var scene: PackedScene = load("res://main.tscn")
	var game: Node3D = scene.instantiate()
	root.add_child(game)
	await process_frame
	assert(not game.started)
	assert(game.round_number == 0)
	game._begin_game()
	assert(game.started and game.round_number == 1)
	assert(game.zombies.size() == 3)
	game._open_shop()
	assert(not game._buy_magazine())
	game._close_shop()
	for expected_round in range(1, 4):
		assert(game.round_number == expected_round)
		assert(game.zombies.size() == expected_round + 2)
		for zombie in game.zombies.duplicate():
			game.cooldown = 0.0
			zombie.position = Vector3(0, 0, 3)
			game._shoot()
		assert(game.zombies.is_empty())
		assert(game.next_round > 0)
		if expected_round == 1:
			assert(game.points == 300)
			game._open_shop()
			var shop_box: VBoxContainer = game.shop.get_child(0)
			var magazine_button: Button = shop_box.get_child(2)
			magazine_button.pressed.emit()
			assert(game.magazine == 18 and game.points == 100)
			game.health = 60
			var medkit_button: Button = shop_box.get_child(1)
			medkit_button.pressed.emit()
			assert(game.health == 100 and game.points == 0)
			game._close_shop()
		if expected_round < 3: game._start_round()
	assert(game.kills == 12)
	assert(game.round_number == 3)
	print("THREE_ROUNDS_AND_PURCHASES_PASSED")
	quit(0)
