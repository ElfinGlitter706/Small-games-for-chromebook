extends SceneTree

var g
var checks := 0
var errors := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	checks+=1
	if not condition:
		errors+=1
		push_error(label)

func stand_at(kind: String) -> Dictionary:
	for item in g.sector.stations:
		if item.kind!=kind: continue
		for n in 24:
			var p: Vector3=item.pos+Vector3(cos(n*TAU/24),0,sin(n*TAU/24))*1.62
			if g.sector.nav.clear_at(p) and g.nearby(p)==item:
				g.player.position=p+Vector3.UP*1.65
				return item
	return {}

func target(p: Vector3):
	var enemy=g.Stray.new()
	g.sector.add_child(enemy)
	enemy.assemble(g.sector.art,1)
	enemy.set_meta("type","armored")
	enemy.position=p
	enemy.mode="hunt"
	enemy.hp=80
	g.enemies.append(enemy)
	return enemy

func tower_ride() -> void:
	g=load("res://remake.tscn").instantiate()
	g.set_meta("test_run",true)
	root.add_child(g)
	g.set_physics_process(false)
	g.select_map(true)
	g.deploy()
	for gate in g.sector.gates:
		gate.open=true
		gate.mesh.hide()
	g.sector.reachability()
	g.sector.nav.rebuild()
	g.completed[0]=true
	var call_point:=stand_at("up")
	check(not call_point.is_empty(),"Lobby call panel usable")
	var shaft:Vector3=call_point.pos
	g.player.position=shaft+Vector3(0,1.65,1.75)
	check(g.sector.stair_height(g.player.position)>0,"Landing steps lift the player's walking surface")
	g.interact()
	var rounds:int=g.ammo
	g.fire()
	check(g.lift_wait>0 and g.ammo==rounds-1,"Lift call leaves the player able to defend the lobby")
	for i in 10:g._physics_process(1./60)
	var lobby_spawn:=false
	for enemy in g.enemies:
		if g.sector.lanes[enemy.lane].cell==g.sector.cell_at(shaft): lobby_spawn=true
	check(lobby_spawn,"Attackers enter through a lobby opening during the wait")
	for i in 225:g._physics_process(1./60)
	check(g.riding() and is_instance_valid(g.cabin),"Board the moving elevator interior")
	var h:float=g.player.global_position.y
	for i in 40:g._physics_process(1./60)
	check(g.player.global_position.y>h+.2,"Elevator moves the camera through the real shaft")
	for i in 90:g._physics_process(1./60)
	check(g.level==1 and g.player.get_parent()==g.floors[1],"Elevator delivers player to the next playable floor")
	g.equip("marksman",true)
	var mouse:=InputEventMouseButton.new()
	mouse.button_index=MOUSE_BUTTON_RIGHT
	mouse.pressed=true
	Input.parse_input_event(mouse)
	Input.flush_buffered_events()
	for i in 25:g._physics_process(1./60)
	check(not g.ui.scope.visible and g.gun.visible and not g.ui.dots[0].visible and g.camera.fov<g.options.fov*.50,"ADS uses the gun sights and hides the HUD crosshair")
	check(absf(g.gun.position.y+g.Models.SIGHT_LINE)<.004,"Front bead stays below aim ray")
	check(not g.armory.toggle("marksman",0),"Unranked weapon cannot equip attachments")
	g.armory.credit("marksman",100)
	check(g.armory.toggle("marksman",0) and not g.armory.toggle("marksman",1),"Level two has one attachment slot")
	g.equip("marksman",true)
	check(g.capacity()==12 and g.armory.rank("gun")==1,"Weapon progression applies to the selected gun only")
	g.armory.credit("marksman",900)
	for i in [1,2,3]:g.armory.toggle("marksman",i)
	check(g.armory.equipped("marksman").size()==4 and not g.armory.toggle("marksman",4),"Four attachment maximum")
	mouse=mouse.duplicate()
	mouse.pressed=false
	Input.parse_input_event(mouse)
	Input.flush_buffered_events()
	g.free()

func run() -> void:
	g=load("res://remake.tscn").instantiate()
	g.set_meta("test_run",true)
	root.add_child(g)
	g.set_physics_process(false)
	g.deploy()
	check(g.intro>0 and g.preview_camera.current,"Map intro takes the camera")
	for i in 115: g._physics_process(1./60)
	check(g.camera.current,"Intro returns control to first person")
	var c:Vector3=g.sector.center_of(g.sector.route.front())
	g.player.position=c+Vector3(-2.4,1.65,1.5)
	var first=target(c+Vector3(1,0,1.5))
	var second=target(c+Vector3(2.7,0,1.5))
	g.equip("shotgun",true)
	g.camera.look_at(g.sector.to_global(first.position+Vector3.UP*1.16))
	g.fire()
	check(first.hp<80 and second.hp<80 and first.hp<second.hp,"Pellets spread and penetrate a second target with damage falloff")
	check(g.shots==1 and g.hits==1,"Shotgun accuracy counts trigger pulls")
	first.armor(g.sector.art)
	check(first.strike("head",5,false)==3 and not first.plates.head.visible and first.plates.torso.visible,"Helmet breaks independently of chest armor")
	first.strike("leg",1,false)
	first.animate(.03,true)
	check(first.stagger>0 and first.torso.position.y<0,"Leg hit stumbles without killing")
	g.player.position=first.position+Vector3(-1.3,1.65,0)
	g.camera.look_at(g.sector.to_global(first.position+Vector3.UP*1.2))
	var original:Vector3=first.position
	g.cooldown=0
	g.fire(true)
	check(first.position.distance_to(original)>.1 and g.action.shove>0,"Melee connects and pushes")
	for enemy in g.enemies: enemy.queue_free()
	g.enemies.clear()
	g.equip("lmg",true)
	g.cooldown=0
	var full: int=g.ammo
	g.fire()
	check(g.action.winding and g.ammo==full,"LMG winds up before spending ammunition")
	for i in 18: g._physics_process(1./60)
	check(g.ammo==full-1 and g.action.spin>0,"LMG fires after spin-up")
	g.points=14000
	var generator:=stand_at("power")
	check(not generator.is_empty(),"Generator usable")
	g.interact()
	check(g.power and g.sector.powered_lamps[0].visible,"Generator visibly changes the base")
	var forge:=stand_at("forge")
	var spent: int=g.spent
	for i in 3: g.interact()
	check(g.upgrades.lmg==2 and g.choice==forge,"Forge requests a final branch before charging")
	var event:=InputEventKey.new()
	event.pressed=true
	event.physical_keycode=g.options.bindings.get(KEY_Q,KEY_Q)
	g._unhandled_input(event)
	g.interact()
	check(g.specialty.get("lmg")=="handling" and g.upgrades.lmg==3 and g.spent-spent==forge.price*6,"Handling purchased at displayed tier prices")
	g.equip("shotgun",true)
	for i in 4: g.interact()
	check(g.specialty.get("shotgun")=="arc","Arc branch retained independently per weapon")
	g.perks.assign(["vital","quick","light","recovery"])
	g.max_hp=150
	g.health=150
	var next:=stand_at("deadeye")
	spent=g.spent
	g.interact()
	check(g.choice==next and g.perks.size()==4 and g.spent==spent,"Full perk inventory asks which perk to trade")
	g.interact()
	check(g.perks.size()==4 and "deadeye" in g.perks and "vital" not in g.perks and g.max_hp==100 and g.spent==spent+next.price,"Replacement removes the old effect and charges once")
	var tape:=stand_at("lore")
	check(not tape.is_empty(),"Field recorder reachable")
	g.interact()
	g.tick_mission(.1)
	check(g.ui.subtitle.visible and g.sub_time>2 and g.sound.recorder.stream!=null,"Recording plays with captions")
	g.wave=1
	g.director.open(g)
	var cash: int=g.points
	for i in 5:g.director.record_shot(g,true)
	check(g.points==cash+175,"Headshot contract pays once")
	g.wave=2
	g.director.open(g)
	cash=g.points
	for i in 3:g.director.repaired(g)
	check(g.points==cash+175,"Repair contract pays once")
	g.wave=3
	g.director.open(g)
	cash=g.points
	g.wave_clear()
	check(g.points==cash+175 and "WAVE 03 CLEAR" in g.director.scorecard,"Clean round pays and posts a scoreboard")
	g.wave=4
	g.director.open(g)
	g.reserve=0
	cash=g.points
	g.wave_clear()
	g.wave_clear()
	check(g.points==cash+300 and g.reserve>0 and g.director.challenge,"Challenge bonus and resupply cannot be collected twice")
	g.director.wounded(g,40)
	check(g.director.recovery>0 and g.director.damage_total==40,"Incoming pressure earns a short spawning break")
	g.finish(false)
	check("HP lost" in g.ui.end_detail.text and g.director.worst_room in g.ui.end_detail.text,"Debrief explains where damage happened")
	g.free()
	tower_ride()
	await create_timer(.5).timeout
	print("DISPATCH FEATURES ",checks," checks, ",errors," failures")
	quit(1 if errors else 0)
