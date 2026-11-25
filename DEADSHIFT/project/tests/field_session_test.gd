extends SceneTree

var failures:=0
var checks:=0

func _initialize() -> void:
	call_deferred("run")

func check(ok:bool,title:String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(title)

func game():
	var g=load("res://remake.tscn").instantiate()
	g.set_meta("test_run",true)
	root.add_child(g)
	g.set_physics_process(false)
	return g

func key(g,code:int) -> void:
	var e:=InputEventKey.new()
	e.keycode=code
	e.physical_keycode=code
	e.pressed=true
	g._unhandled_input(e)

func type_code(g) -> void:
	for letter in "TEMAMILA".to_ascii_buffer():key(g,letter)

func run() -> void:
	var g=game()
	type_code(g)
	check(not g.session.masked,"Menu ignores code")
	g.options.config.set_value("prefs","Fast pursuit",1)
	g.deploy()
	g.spawn_one()
	var original=g.enemies.front()
	key(g,KEY_ESCAPE)
	type_code(g)
	check(not g.session.masked,"Pause ignores code")
	g.menu_command("resume")
	type_code(g)
	check(g.session.masked and original.head_pivot.has_node("Portrait"),"Code changes current head")
	g.spawn_one()
	check(g.enemies.back().head_pivot.has_node("Portrait"),"Later breach wears portrait")
	check(g.records.get_value("discoveries","found",[])==["Temamila"],"Settings lists only discovered egg")
	key(g,KEY_P)
	check(g.monitor.visible,"Letter toggles performance panel")
	key(g,KEY_P)
	check(not g.monitor.visible,"Second press hides panel")
	var ev:=InputEventKey.new()
	ev.physical_keycode=KEY_RIGHT
	ev.pressed=true
	Input.parse_input_event(ev)
	Input.flush_buffered_events()
	var yaw:float=g.player.rotation.y
	g._physics_process(.1)
	check(g.player.rotation.y<yaw,"Right arrow turns the camera")
	ev=ev.duplicate()
	ev.pressed=false
	Input.parse_input_event(ev)
	Input.flush_buffered_events()
	g.power=true
	g.session.interact(g,{"kind":"dispatch"})
	check(g.session.train_wave==1,"Dispatch starts three full rounds")
	g.begin_wave()
	check(g.queued>9,"Train call increases reinforcements")
	g.wave_clear()
	g.begin_wave()
	g.wave_clear()
	check(not g.session.freight_ready,"Second completed wave is too early to board")
	g.begin_wave()
	g.wave_clear()
	check(g.session.freight_ready,"Third wave releases relief train")
	var balance:int=g.points
	g.session.interact(g,{"kind":"battery"})
	g.session.interact(g,{"kind":"dispatch"})
	check(g.session.delivery and g.points==balance+600,"Freight quest delivered")
	var wallet:int=g.points
	g.session.interact(g,{"kind":"plate","price":0})
	check(g.session.kit=="Armor plate" and g.points==wallet-250,"Armor plate charges its displayed price")
	g.session.use_kit(g)
	check(g.buffs.get("shield",0)>0 and g.session.kit=="","Equipment consumed once")
	g.armory.advance("sidearm",3,true)
	check(g.armory.mastered("sidearm") and not g.armory.mastered("gun"),"Mastery finish belongs to one weapon")
	g.Checkpoint.capture(g)
	var serialized:String=g.records.encode_to_text()
	var next=game()
	check(next.records.parse(serialized)==OK,"Checkpoint survives serialization")
	next.Checkpoint.resume(next)
	check(next.wave==4 and next.points==g.points and next.session.masked and next.session.delivery and next.session.freight_ready and next.session.mods==g.session.mods,"Continue restores purchases, challenges, code and train")
	next.spawn_one()
	if next.enemies.size()>0:check(next.enemies[0].head_pivot.has_node("Portrait"),"Restored mask affects resumed spawns")
	next.session.tick(next,5)
	next.session.interact(next,{"kind":"carriage"})
	check(next.state=="ended" and next.records.get_value("runs","history",[]).size()==1,"Boarding finishes run and records history")
	check(not next.records.has_section_key("solo","checkpoint"),"Finished checkpoint retired")
	g.free()
	next.free()
	var tower=game()
	tower.select_map(true)
	tower.deploy()
	tower.wave=3
	tower.session.open_wave(tower)
	check(tower.session.condition!="" and tower.session.condition_floor==0,"Tower gets localized room state")
	tower.session.condition="Voltage surge"
	tower.session.affected=tower.sector.cell_at(tower.player.position)
	check(tower.session.jammed(tower,{"kind":"forge","pos":tower.player.position}),"Electrical room disrupts forge")
	tower.options.config.set_value("prefs","Daily seed",1)
	tower.session.begin(tower)
	var seed_used:int=tower.session.seed_value
	tower.session.begin(tower)
	check(tower.session.seed_value==seed_used,"Daily challenge seed repeatable")
	tower.free()
	var practice=game()
	practice.menu_command("practice")
	key(practice,KEY_G)
	key(practice,KEY_Y)
	check(practice.session.practice and practice.loadout=="gun" and practice.upgrades.gun==1,"Practice allows cycling weapons and forge tiers")
	practice.wave_clear()
	check(not practice.records.has_section_key("solo","checkpoint"),"Practice cannot replace solo checkpoint")
	practice.free()
	await create_timer(.4).timeout
	print("FIELD SESSION ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
