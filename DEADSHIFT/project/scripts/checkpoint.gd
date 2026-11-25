extends RefCounted

const GAME_KEYS := ["wave","health","max_hp","points","perks","inventory","loadout","ammo","reserve","stored","upgrades","specialty","bought","completed","power","revive_used","sequence","rolls","earned","spent","downs","kills","shots","hits","heads","sim_time","perk_buys","gun_buys","buffs","run_id"]
const SESSION_KEYS := ["seed_value","mods","daily","masked","train_wave","freight_ready","kit","carried","delivery","usage"]
const DIRECTOR_KEYS := ["contracts","wounds","worst_room","damage_total"]

static func values(obj,keys:Array) -> Dictionary:
	var result:={}
	for key in keys:
		var v=obj.get(key)
		result[key]=v.duplicate(true) if v is Dictionary or v is Array else v
	return result

static func apply_values(obj,fields:Dictionary,keys:Array) -> void:
	for key in keys:
		if fields.has(key):obj.set(key,fields[key])

static func capture(g) -> void:
	if g.session.practice or g.training_transition() or g.state!="play":return
	var lanes:=[]
	for floor_map in g.floors:
		var armed:=[]
		for lane in floor_map.lanes:armed.append(lane.armed)
		lanes.append(armed)
	var save:={"version":1,"tower":g.tower,"level":g.level,"position":g.player.position,"yaw":g.player.rotation.y,"pitch":g.camera.rotation.x,"lanes":lanes,"game":values(g,GAME_KEYS),"session":values(g.session,SESSION_KEYS),"director":values(g.director,DIRECTOR_KEYS),"performance":g.monitor.summary()}
	g.records.set_value("solo","checkpoint",save)
	if not g.has_meta("test_run"):g.records.save("user://deadshift_records.cfg")

static func resume(g) -> void:
	var save:Dictionary=g.records.get_value("solo","checkpoint",{})
	if g.state!="menu" or save.get("version")!=1:return
	g.bought=save.game.bought.duplicate()
	g.select_map(save.tower)
	g.deploy()
	if save.level!=0:g.travel(save.level)
	apply_values(g,save.game,GAME_KEYS)
	apply_values(g.session,save.session,SESSION_KEYS)
	apply_values(g.director,save.director,DIRECTOR_KEYS)
	g.monitor.restore(save.get("performance",{}))
	for i in mini(g.floors.size(),save.lanes.size()):
		var floor_map=g.floors[i]
		for j in mini(floor_map.lanes.size(),save.lanes[i].size()):
			var lane:Dictionary=floor_map.lanes[j]
			lane.armed=save.lanes[i][j]
			lane.brace.visible=lane.armed
	g.player.position=save.position
	g.player.rotation.y=save.yaw
	g.camera.rotation.x=save.pitch
	g.intro=0
	g.camera.current=true
	g.show_play_floor()
	g.queued=0
	g.wave_scored=g.wave
	g.intermission=4
	g.update_cache()
	g.model()
	g.refresh()
	g.announce("Checkpoint restored   /   Wave %02d cleared" % g.wave)

static func retire(g) -> void:
	var saved:Dictionary=g.records.get_value("solo","checkpoint",{})
	if saved.get("game",{}).get("run_id",-1)==g.run_id:g.records.erase_section_key("solo","checkpoint")
