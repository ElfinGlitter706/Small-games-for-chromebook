extends SceneTree

var errors:=0
var checks:=0

func check(ok:bool,what:String) -> void:
	checks+=1
	if not ok:
		push_error(what)
		errors+=1

func _initialize() -> void:
	call_deferred("rules")

func inspect_floor(g) -> void:
	var floor_map=g.sector
	var start:Vector3=floor_map.arrival_position(false)
	var end:Vector3=floor_map.center_of(floor_map.route.back())
	check(floor_map.nav.path(start,end).is_empty(),"Exit physically sealed on arrival")
	var active_entrances:=0
	for lane in floor_map.lanes:
		if lane.cell==floor_map.route[0] and not lane.disabled:active_entrances+=1
	check(active_entrances>=2,"Multiple working zombie entrances at spawn")
	var counters:Array[Vector3]=[]
	for item in floor_map.stations:
		if item.price<=0:continue
		for other in counters:
			check(other.distance_to(item.pos)>=16,"Purchase spacing on floor %d for %s at %s near %s" % [g.level,item.title,item.pos,other])
		counters.append(item.pos)
	for gate in floor_map.gates:
		gate.open=true
		gate.mesh.hide()
	floor_map.reachability()
	floor_map.nav.rebuild()
	for cell in floor_map.route:
		check(not floor_map.nav.path(start,floor_map.center_of(cell)).is_empty(),"Traversable room "+floor_map.room_names[cell])
	for item in floor_map.stations:
		item.dormant=false
		var reachable:=false
		for i in 12:
			var angle:=TAU*i/12
			var p:Vector3=item.pos+Vector3(cos(angle),0,sin(angle))*1.7
			if floor_map.nav.clear_at(p) and g.nearby(p)==item and not floor_map.nav.path(start,p).is_empty():
				reachable=true
				break
		check(reachable,"Reachable use prompt for "+item.title)
	if not g.tower:
		var bridge:Vector3=floor_map.center_of(floor_map.route[1])
		check(absf(floor_map.nav.move(bridge,Vector3(0,0,5)).z-bridge.z)<2.4,"Bridge rail blocks the drop")

func rules() -> void:
	var g=load("res://remake.tscn").instantiate()
	g.set_meta("test_run",true)
	root.add_child(g)
	g.set_physics_process(false)
	g.ui.map_buttons[1].pressed.emit()
	while g.ui.busy: await process_frame
	g.ui.deploy_button.pressed.emit()
	var lift:Dictionary={}
	for item in g.sector.stations:
		if item.kind=="up":lift=item
	g.special_interact(lift)
	check(g.level==0 and g.lift_time==0,"Power required for lift")
	check(not g.sector.accessible.has(g.sector.route[1]),"Paid room starts locked")
	var cash:int=g.points
	check(not g.charge(cash+1) and g.points==cash,"No charge on denial")
	g.options.show_panel()
	check(g.options.panel.visible and not g.ui.menu.visible,"Settings entry")
	g.options.hide_panel()
	var jump:=InputEventKey.new()
	jump.physical_keycode=KEY_SPACE
	jump.pressed=true
	g._unhandled_input(jump)
	for i in 12:g._physics_process(1./60)
	check(g.player.position.y>1.75,"Jump changes eye height")
	g.health=40
	g.safe_time=7
	for i in 15:g.tick_mission(.1)
	check(g.health>40,"Passive regeneration")
	g.equip("smg",true)
	g.ammo=3
	g.equip("sidearm",false)
	g.equip("smg",false)
	check(g.ammo==3,"Weapon swap preserves ammunition")
	g.apply_drop("ammo")
	check(g.reserve==g.WEAPONS.smg.reserve,"Ammo pickup refills reserves")
	g.apply_drop("double")
	g.apply_drop("overload")
	g.apply_drop("haste")
	check(g.buffs.double>0 and g.buffs.overload>0 and g.buffs.haste>0,"Timed drops active")
	g.travel(5)
	g.extraction_active=true
	g.boarding=.1
	g.tick_mission(.11)
	check(g.state=="ended" and g.ui.end_title.text=="SIGNAL LOST","Missed aircraft ends run")
	for floor_id in 6:
		g.travel(floor_id)
		check(is_equal_approx(g.sector.global_position.y,floor_id*g.Sector.STOREY_HEIGHT),"Stacked storey elevation")
		inspect_floor(g)
	g.state="menu"
	g.select_map(false)
	check(g.floors.size()==1 and g.sector.route.size()==25,"Contiguous Outpost")
	var before:Vector3=g.preview_camera.position
	g.pan_preview(2)
	check(before.distance_to(g.preview_camera.position)>1,"Moving preview")
	inspect_floor(g)
	g.free()
	await create_timer(1.).timeout
	print("SIEGE RULES ",checks," checks, ",errors," failures")
	quit(1 if errors else 0)


