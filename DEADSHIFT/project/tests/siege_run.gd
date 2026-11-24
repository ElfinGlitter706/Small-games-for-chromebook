extends SceneTree

var g
var failures:=0
var checks:=0
var clock:=0

func _initialize() -> void:
	call_deferred("run")

func verify(ok: bool,msg: String) -> bool:
	checks+=1
	if not ok:
		failures+=1
		push_error(msg)
	return ok

func tick() -> void:
	g._physics_process(1./60)
	clock+=1
	# Aim independently from walking. Respect collisions, ammunition and cadence.
	var nearest=null
	var closest:=INF
	for e in g.enemies:
		if e.mode!="hunt": continue
		var point:Vector3=e.position+Vector3.UP*1.79*e.scale.y
		var distance:float=g.player.position.distance_squared_to(e.position)
		if distance>=closest or g.sector.nav.blocked_ray(g.sector.to_local(g.camera.global_position),point): continue
		nearest=e
		closest=distance
	if nearest!=null:
		var target:Vector3=nearest.position+Vector3.UP*1.79*nearest.scale.y
		g.camera.look_at(g.sector.to_global(target))
		g.fire(g.ammo==0 and g.reserve==0 and closest<4)
	if g.ammo==0: g.start_reload()
	if g.reserve==0 and g.ammo==0 and g.inventory.size()>1:
		var spare:String=g.inventory[1-g.inventory.find(g.loadout)]
		if g.stored[spare][0]+g.stored[spare][1]>0:g.equip(spare,false)

func walk(destination:Vector3,reach:=.38) -> bool:
	var path:PackedVector2Array=g.sector.nav.path(g.player.position,destination)
	if path.is_empty(): return false
	var i:=0
	var key:=InputEventKey.new()
	key.physical_keycode=g.options.bindings.get(KEY_W,KEY_W)
	key.pressed=true
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	for f in 4000:
		var at:=Vector2(g.player.position.x,g.player.position.z)
		while i<path.size() and at.distance_to(path[i])<.16: i+=1
		if i==path.size() or at.distance_to(Vector2(destination.x,destination.z))<reach or g.state!="play": break
		var d:=path[i]-at
		g.player.rotation.y=atan2(-d.x,-d.y)
		tick()
	key=key.duplicate()
	key.pressed=false
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	return Vector2(g.player.position.x-destination.x,g.player.position.z-destination.z).length()<.75

func use_item(entry:Dictionary) -> bool:
	var pos:Vector3=entry.pos
	var best:=INF
	var place:=Vector3.ZERO
	for d in [Vector3.FORWARD,Vector3.BACK,Vector3.LEFT,Vector3.RIGHT,Vector3(-.7,0,-1),Vector3(.7,0,-1),Vector3(-.7,0,1),Vector3(.7,0,1)]:
		var p:Vector3=pos+d*1.55
		if not g.sector.nav.clear_at(p) or g.nearby(p)!=entry:continue
		var path:PackedVector2Array=g.sector.nav.path(g.player.position,p)
		if not path.is_empty() and path.size()<best:
			place=p
			best=path.size()
	if not verify(best<INF and walk(place),"No interaction approach for %s at %s from %s (target %s)" % [entry.title,pos,g.player.position,place]):return false
	if not verify(g.nearby()==entry,"Expected %s at %s, got %s from %s on floor %d" % [entry.title,pos,g.nearby().get("title","no prompt"),g.player.position,g.level]):return false
	g.interact()
	while g.lift_time>0:tick()
	return true

func station(kind:String) -> Dictionary:
	for item in g.sector.stations:
		if item.kind==kind and not item.get("dormant",false):return item
	return {}

func earn(cost:int) -> bool:
	for i in 16000:
		if g.points>=cost:return true
		if g.state!="play":break
		tick()
	return verify(false,"Could not earn "+str(cost)+" at wave "+str(g.wave))

func visit_cell(target:Vector2i) -> bool:
	for index in range(1,g.sector.route.find(target)+1):
		var cell:Vector2i=g.sector.route[index]
		if g.sector.accessible.has(cell):continue
		var link_index:int=g.sector.links.find([g.sector.route[index-1],cell])
		if not verify(link_index>=0,"Missing route passage"):return false
		var gate:Dictionary=g.sector.gates[link_index]
		if not earn(gate.price) or not use_item(gate):return false
	return verify(g.sector.accessible.has(target),"Route failed to open")

func use_kind(kind:String) -> bool:
	var item:=station(kind)
	if not verify(not item.is_empty(),"Missing "+kind):return false
	if not visit_cell(g.sector.cell_at(item.pos)):return false
	return earn(item.price) and use_item(item)

func campaign() -> void:
	for floor_id in 6:
		if not verify(g.level==floor_id,"Wrong stage at "+str(floor_id)):return
		if not verify(g.sector.cell_at(g.player.position)==g.sector.route.front(),"Arrive at starting end"):return
		var entry:Vector2i=g.sector.route.front()
		var exit_cell:Vector2i=g.sector.route.back()
		verify(signi(exit_cell.x-entry.x)==(1 if floor_id%2==0 else -1),"Alternating floor direction")
		verify(not g.sector.accessible.has(exit_cell),"Locked exit")
		if floor_id==0 and not use_kind("gun"):return
		if floor_id==0 and not use_kind("recovery"):return
		if floor_id==1 and not use_kind("quick"):return
		if floor_id==2 and not use_kind("vital"):return
		if floor_id==2 and not use_kind("heavy"):return
		if floor_id==3 and not use_kind("lmg"):return
		if floor_id==4 and not use_kind("marksman"):return
		if floor_id==4 and not use_kind("deadeye"):return
		if floor_id==5 and not use_kind("gun"):return
		if not use_kind("objective"):return
		if floor_id==4:
			for f in 5000:
				tick()
				if g.completed.has(4) or g.state!="play":break
			if not verify(g.completed.has(4),"Lockdown failed"):return
		if floor_id<5:
			var shaft:Vector3=g.sector.to_global(g.sector.lift_pad)
			if not use_kind("up"):return
			verify((shaft+Vector3.UP*g.Sector.STOREY_HEIGHT).is_equal_approx(g.sector.to_global(g.sector.shaft_position(0))),"Continuous lift shaft")
			print("ASCENT ",g.level," wave=",g.wave," kills=",g.kills)
		else:
			if not visit_cell(g.sector.cell_at(station("board").pos)):return
			for f in 6500:
				tick()
				if g.boarding>0 or g.state!="play":break
			if not verify(g.boarding>0,"Helicopter failed to arrive"):return
			if not walk(g.sector.landing_pad+Vector3.BACK*2.60): return
			g.interact()
			verify(g.state=="play","Pad interaction alone cannot extract")
			walk(g.sector.landing_pad+Vector3.BACK*.72,.10)
			verify(g.ui.end_title.text=="EXTRACTED","Extraction failed")
		var doors:=0
		for id in g.bought:
			if str(id).begins_with(str(floor_id)+"/"):doors+=1
		verify(doors==3,"Three barricades crossed on floor "+str(floor_id))

func survival() -> void:
	if not use_kind("gun"):return
	var service_return: Dictionary={}
	for gate in g.sector.gates:
		if gate.shortcut and gate.release_cell==g.sector.route[5]:service_return=gate
	var balance:int=g.spent
	if not use_item(service_return):return
	verify(g.spent==balance and not service_return.open,"Service return cannot skip unexplored rooms")
	if not use_kind("power") or not use_kind("vital"):return
	if not earn(service_return.price) or not use_item(service_return):return
	verify(service_return.open,"Service return unlocks after reaching the far side")
	if not use_kind("forge"):return
	verify(g.upgrades.get("gun",0)==1,"Forge did not upgrade carbine")
	if not use_kind("cache"):return
	for i in 120:tick()
	var result:String=g.offered
	g.interact()
	verify(not result.is_empty() and g.loadout==result,"Cache claim failed")
	if not use_kind("lore") or not use_kind("lore_b") or not use_kind("secret"):return
	verify(g.level==0 and g.loadout=="relic","Ground-level relay quest")
	if not use_kind("lmg"):return
	verify(g.loadout=="lmg","Wall-mounted LMG purchase")
	# Discharge one round after the LMG motor reaches firing speed.
	for frame in 80:
		g.fire()
		tick()
		if g.ammo<g.capacity(): break
	verify(g.ammo<g.capacity(),"LMG discharged before reloading")
	g.start_reload()
	for frame in 220:tick()
	if not earn(100):return
	var spent_before_refill:int=g.spent
	if not use_item(station("lmg")):return
	verify(g.spent==spent_before_refill+100,"Charged the posted ammo price")
	verify(g.reserve==g.WEAPONS.lmg.reserve,"Purchased wall ammunition")

func run() -> void:
	for tower in [false,true]:
		g=load("res://remake.tscn").instantiate()
		g.set_meta("test_run",true)
		root.add_child(g)
		g.set_physics_process(false)
		g.ui.map_buttons[int(tower)].pressed.emit()
		while g.ui.busy: await process_frame
		g.ui.deploy_button.pressed.emit()
		verify(g.level==0 and g.wave==1,"Deployment")
		if tower:campaign()
		else:survival()
		print("RESULT tower=",tower," wave=",g.wave," kills=",g.kills," earned=",g.earned," spent=",g.spent," hp=",g.health," state=",g.state," failures=",failures)
		g.free()
		await process_frame
	await create_timer(1.0).timeout
	print("SIEGE RUN ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)


