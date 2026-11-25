extends Node3D

const Sector = preload("res://scripts/complex.gd")
const Stray = preload("res://scripts/stray.gd")
const Dispatch = preload("res://scripts/dispatch_ui.gd")
const Audio = preload("res://scripts/field_audio.gd")
const WEAPONS := {
	"sidearm":{"title":"Rook", "mag":12,"reserve":72,"power":1,"cycle":.22,"reload":1.1},
	"gun":{"title":"Fen Carbine","mag":24,"reserve":120,"power":2,"cycle":.13,"reload":1.35},
	"heavy":{"title":"Arc Driver","mag":8,"reserve":48,"power":4,"cycle":.38,"reload":1.55},
	"smg":{"title":"Finch SMG","mag":32,"reserve":160,"power":2,"cycle":.085,"reload":1.1},
	"shotgun":{"title":"Kiln Scattergun","mag":6,"reserve":54,"power":7,"cycle":.6,"reload":1.65},
	"lmg":{"title":"Breakwater LMG","mag":72,"reserve":216,"power":3,"cycle":.15,"reload":2.6},
	"marksman":{"title":"Vesper Marksman","mag":9,"reserve":72,"power":5,"cycle":.38,"reload":1.45},
	"relic":{"title":"Aurora Coil","mag":16,"reserve":80,"power":9,"cycle":.24,"reload":1.65}}
const PERKS := {"vital":"Second Pulse · +50 maximum HP","quick":"Quick Current · 44% faster reload","light":"Lightweight · 26% faster movement","deadeye":"Deadeye · triple headshot damage","recovery":"Rapid Recovery · heal after 2.4s","revive":"Second Chance · revive once this run"}
const Models = preload("res://scripts/weapon_models.gd")
var armory := preload("res://scripts/armory.gd").new()
var fitted: Array=[]
var previous_board_pos := Vector3.ZERO
var specialty := {}
var choice := {}
var choice_index := 0
var director := preload("res://scripts/round_director.gd").new()
var action := preload("res://scripts/weapon_action.gd").new()
var lift_wait := 0.0
var lift_ready := false
var cabin: Node3D
var ride_origin := Vector3.ZERO
var intro := 0.0
var intro_start := Transform3D.IDENTITY
var intro_focus := Vector3.ZERO
var sub_time := 0.0
var rotor_audio := 0.0
var level := 0
var bought := {}
var completed := {}
var power := false
var lockdown := 0.0
var defense := -1.0
var boarding := -1.0
var must_defeat := false
var boss_defeated := false
var inventory: Array[String] = ["sidearm"]
var stored := {}
var upgrades := {}
var buffs := {}
var roll_time := 0.0
var offered := ""
var rolls := 0
var roll_item := {}
var jump_y := 0.0
var jump_speed := 0.0
var slide := 0.0
var slide_dir := Vector3.ZERO
var sliding_ready := true
var regen := 0.0
var safe_time := 0.0
var shots := 0
var hits := 0
var heads := 0
var earned := 0
var spent := 0
var downs := 0
var gun_buys := 0
var perk_buys := 0
var records := ConfigFile.new()
const Options = preload("res://scripts/field_options.gd")
var options: Options
var damage_time := 0.0
var extraction_active := false
var toggle_aim := false
var lift_time:=0.
var lift_target:=0
var revive_used:=false
var last_entrance:=-1
var sector
var floors:Array[Node3D]=[]
var preview_camera:=Camera3D.new()
var preview_clock:=0.0
var ui := Dispatch.new()
var sound := Audio.new()
var player := Node3D.new()
var camera := Camera3D.new()
var gun := Node3D.new()
var reload_part: Node3D
var flash: MeshInstance3D
var state := "menu"
var tower := false
var enemies: Array = []
var fallen: Array = []
var wave := 0
var queued := 0
var spawn_clock := 0.0
var intermission := 0.0
var sequence := 0
var points := 100
var health := 100
var max_hp := 100
var perks: Array[String] = []
var loadout := "sidearm"
var ammo := 12
var reserve := 72
var wave_scored := 0
var kills := 0
var cooldown := 0.0
var hurt_lock := 0.0
var reload_left := 0.0
var recoil := 0.0
var hit := 0.0
var sim_time := 0.0
var notice := ""
var note_time := 0.0
var reload_click := false
var walking := false
var step_clock := 0.0
var supplies: Array[Dictionary] = []

func _ready() -> void:
	armory.testing=has_meta("test_run")
	if not armory.testing: armory.load_progress()
	records.load("user://deadshift_records.cfg")
	add_child(preview_camera)
	add_child(player)
	player.add_child(camera)
	camera.add_child(gun)
	camera.current = true
	camera.fov = 75
	add_child(sound)
	add_child(ui)
	options = preload("res://scripts/field_options.gd").new()
	add_child(options)
	options.build(self)
	ui.selected.connect(select_map)
	ui.deployed.connect(deploy)
	ui.command.connect(menu_command)
	select_map(false)

func select_map(choice: bool) -> void:
	if state != "menu": return
	tower = choice
	if player.get_parent()!=self:player.reparent(self,false)
	for old in floors:
		remove_child(old)
		old.queue_free()
	floors.clear()
	level=0
	for number in (6 if tower else 1):
		var floor_map:=Sector.new()
		floor_map.position.y=number*Sector.STOREY_HEIGHT
		add_child(floor_map)
		floor_map.build_floor(tower,number,bought)
		floors.append(floor_map)
	sector=floors[0]
	player.reparent(sector,false)
	options.apply_quality()
	enter_landing(false)
	preview_clock=0
	preview_camera.current=true
	pan_preview(0)
	ui.preview(tower)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	gun.hide()

func pan_preview(delta:float) -> void:
	preview_clock=fmod(preview_clock+delta,90.)
	var phase:=TAU*preview_clock/90.
	var focus:Vector3
	if tower:
		focus=Vector3(0,13+5*sin(phase),6)
		preview_camera.position=focus+Vector3(58*sin(.6+phase),20+5*cos(phase),58*cos(.6+phase))
	else:
		focus=Vector3(12-31*cos(phase),0,12+9*sin(phase))
		preview_camera.position=focus+Vector3(12*sin(phase+.5),34,34)
	preview_camera.look_at(focus)
	preview_camera.h_offset=-8

func model() -> void:
	for old in gun.get_children():
		gun.remove_child(old)
		old.queue_free()
	var art = sector.art
	var length: float = action.MOTION[loadout].w
	var metal: String=["43535e","845e49","748d9a"][options.pref("Weapon finish",0)]
	if upgrades.get(loadout,0)>0: metal="9c8565"
	if loadout=="relic": metal="5e8889"
	art.piece("taper",Vector3(0,.01,0),Vector3(.18,length,.17),metal,Vector3(PI/2,0,0),gun)
	art.piece("pipe",Vector3(0,.038,-length*.55),Vector3(.10,length*.62,.10),"253137",Vector3(PI/2,0,0),gun)
	art.piece("box",Vector3(0,.112,-.055),Vector3(.073,.043,length*.70),"19282f",Vector3.ZERO,gun)
	art.piece("box",Vector3(0,.14,-length*.36),Vector3(.032,.031,.043),"+e6b16c",Vector3.ZERO,gun)
	for side in [-1,1]:
		art.piece("box",Vector3(side*.077,.038,.045),Vector3(.019,.063,length*.6),"657880",Vector3.ZERO,gun)
		for slot in 4:
			art.piece("box",Vector3(side*.089,.038,.035+slot*.022),Vector3(.006,.06,.008),"2b343c",Vector3(.21,0,0),gun)
	art.piece("oval",Vector3(.015,-.13,.09),Vector3(.18,.28,.24),"6d6151",Vector3(.28,0,0),gun)
	art.piece("oval",Vector3(.05,-.25,.24),Vector3(.21,.22,.45),["424e50","7f503e","728593"][options.pref("Sleeves",0)],Vector3(.30,-.14,0),gun)
	fitted=armory.equipped(loadout)
	Models.detail(art,gun,loadout,length,fitted)
	reload_part=Node3D.new()
	gun.add_child(reload_part)
	match loadout:
		"lmg": art.piece("box",Vector3(.035,-.13,0),Vector3(.26,.25,.24),metal,Vector3.ZERO,reload_part)
		"shotgun": art.piece("pipe",Vector3(.06,-.06,-.17),Vector3(.052,.14,.052),"c79963",Vector3(PI/2,0,0),reload_part)
		"heavy","relic": art.piece("pipe",Vector3(.04,-.055,-.17),Vector3(.125,.24,.125),"+83bfbd",Vector3(PI/2,0,0),reload_part)
		_: art.piece("taper",Vector3(0,-.13,.04),Vector3(.11,.22,.14),metal,Vector3(-.17,0,0),reload_part)
	if loadout in ["shotgun","relic"]:
		art.piece("pipe",Vector3(.07,.05,-.25),Vector3(.08,.65,.08),"+75d3be" if loadout=="relic" else metal,Vector3(PI/2,0,0),gun)
	if loadout!="sidearm":
		for i in 4:
			art.piece("pipe",Vector3(0,.034,-.17-i*.048),Vector3(.15,.026,.15),"998373",Vector3(PI/2,0,0),gun)
	var tier: int=upgrades.get(loadout,0)
	for band in tier:
		var ink: String=["+efad69","+85ded8","+d6a2f2"][band]
		art.piece("pipe",Vector3(0,.038,-length*(.46+.13*band)),Vector3(.15,.035,.15),ink,Vector3(PI/2,0,0),gun)
	if tier>=2:
		art.piece("box",Vector3(-.094,.022,-.075),Vector3(.045,.11,.32),"546f79",Vector3.ZERO,gun)
	if tier==3:
		var arc: bool=specialty.get(loadout,"")=="arc"
		art.piece("pipe" if arc else "taper",Vector3(.074,.0,-.13),Vector3(.068,.31,.068),"+82ded1" if arc else "c79962",Vector3(PI/2,0,0),gun)
	flash = art.piece("cone",Vector3(0,.038,-length*.92),Vector3(.13,.30,.13),"+ffe4ac",Vector3(-PI/2,0,0),gun)
	flash.hide()
	gun.position = Vector3(.29,-.23,-.60)

func deploy() -> void:
	if state!="menu": return
	state = "play"
	intro=1.85
	intro_start=preview_camera.global_transform.orthonormalized()
	intro_focus=Vector3(0,16,5) if tower else sector.center_of(sector.route[0])
	preview_camera.h_offset=0
	enter_landing(false)
	model()
	gun.show()
	ui.menu.hide()
	ui.play.show()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	begin_wave()
	spawn_clock+=intro

func begin_wave() -> void:
	wave += 1
	queued = director.open(self)
	spawn_clock = 1.1
	intermission = 0
	sound.cue("round")
	announce(("BREACH RUSH   /   WAVE %02d" if director.challenge else "WAVE %02d") % wave,1.9)
	refresh()

func announce(message: String, duration := 1.8) -> void:
	notice = message
	note_time = duration
	ui.banner.text = message

func refresh() -> void:
	ui.location.text = ("VERTIGO  /  "+Sector.FLOORS[level] if tower else "OUTPOST  /  "+("Upper" if level else "Ground"))+"   ·   "+str(sector.room_names.get(sector.cell_at(player.position),""))
	ui.wave.text = "Wave %02d    ·    %d remaining" % [wave,queued+enemies.size()]
	ui.vitals.text = "%d HP     %d credits" % [health,points]
	ui.ammo.text = "%s     %02d  /  %03d" % [WEAPONS[loadout].title,ammo,reserve]
	ui.ammo.text+="   Lv%d" % armory.rank(loadout)
	if upgrades.get(loadout,0)>0: ui.ammo.text += "  +%d" % upgrades[loadout]
	ui.perk_line.text = "PERKS  %d/4   %s" % [perks.size(),"   ".join(perks).to_upper()]

func spawn_one() -> void:
	var options: Array[int] = []
	for i in sector.lanes.size():
		var lane: Dictionary = sector.lanes[i]
		if lane.get("disabled",false):continue
		if not sector.accessible.has(lane.cell): continue
		if lane.gate >= 0 and not sector.gates[lane.gate].open: continue
		if lane.pos.distance_to(player.position) < 4: continue
		var occupied := false
		for enemy in enemies:
			if enemy.mode=="opening" and enemy.lane==i: occupied = true
		if not occupied: options.append(i)
	if options.is_empty(): return
	# Nearby unlocked rooms feed the horde even after the complex is fully open.
	options.sort_custom(func(a,b):return sector.lanes[a].pos.distance_squared_to(player.position)<sector.lanes[b].pos.distance_squared_to(player.position))
	if lift_wait>0:
		var lobby: Vector2i=sector.cell_at(sector.shaft_position(0 if lift_target<level else sector.route.size()-1))
		var entrances:=options.filter(func(id):return sector.lanes[id].cell==lobby)
		if not entrances.is_empty(): options.assign(entrances)
	if options.size()>6:options.resize(6)
	if options.size()>1:options.erase(last_entrance)
	var idx := options[sequence % options.size()]
	last_entrance=idx
	var origin: Vector3 = sector.lanes[idx].pos
	var enemy := Stray.new()
	sector.add_child(enemy)
	enemy.lane = idx
	enemy.landing = origin
	enemy.entry = origin-Vector3.UP*2.15
	var lane: Dictionary = sector.lanes[idx]
	if lane.has("outside"): enemy.entry = lane.outside+Vector3.UP*.65
	enemy.entry_duration = 2.35 if lane.armed else 1.45
	lane.occupied = true
	lane.armed = false
	enemy.position = enemy.entry
	enemy.rotation.y = atan2(origin.x-player.position.x, origin.z-player.position.z)
	enemy.gait = sequence*.84
	enemy.hp = 2 + floori((wave-1)*.9)
	enemy.assemble(sector.art,sequence)
	var variant := "walker"
	if wave>=2 and sequence%4==1: variant="runner"
	if wave>=3 and sequence%6==0: variant="armored"
	if wave>=4 and sequence%8==3: variant="brute"
	if director.challenge and sequence%3!=0: variant="runner"
	if must_defeat:
		variant="warden"
		must_defeat=false
	enemy.set_meta("type",variant)
	if variant=="runner":
		enemy.hp=maxi(1,enemy.hp-1)
		enemy.scale=Vector3(.85,1,.85)
	if variant in ["brute","warden"]:
		enemy.scale=Vector3.ONE*(1.29 if variant=="brute" else 1.48)
		enemy.hp=enemy.hp*2+(16 if variant=="warden" else 3)
	if variant in ["armored","warden"]:
		enemy.armor(sector.art)
	enemies.append(enemy)
	sequence += 1
	queued -= 1
	sound.at("breach",sector.to_global(origin),-9)
	refresh()

func track(enemy, delta: float) -> void:
	var offset: Vector3 = player.position - enemy.position
	offset.y = 0
	var near: bool = offset.length() <= 1.28 and not sector.nav.blocked_ray(enemy.position+Vector3.UP,player.position)
	enemy.repath -= delta
	if not near and enemy.repath <= 0:
		enemy.route = sector.nav.path(enemy.position,player.position)
		enemy.repath = .50
		# The first node is the quantized current position. Re-targeting it every
		# refresh can pull a moving zombie backward at corners.
		if enemy.route.size()>1: enemy.route.remove_at(0)
	var motion := Vector3.ZERO
	if not near:
		var here := Vector2(enemy.position.x,enemy.position.z)
		while not enemy.route.is_empty() and here.distance_to(enemy.route[0]) < .18:
			enemy.route.remove_at(0)
		if not enemy.route.is_empty():
			var point: Vector2 = enemy.route[0]
			motion = Vector3(point.x-here.x,0,point.y-here.y).normalized()
			var repel := Vector3.ZERO
			for neighbor in enemies:
				if neighbor==enemy or neighbor.mode!="hunt": continue
				var away: Vector3 = enemy.position-neighbor.position
				if away.length_squared()<.47: repel += away.normalized()*(.69-away.length())
			var pace := minf(4.2,1.9+.22*wave)
			if enemy.get_meta("type")=="runner": pace*=1.6
			if enemy.get_meta("type") in ["brute","warden"]: pace*=.8
			enemy.position = sector.nav.move(enemy.position,(motion+repel*.45)*pace*delta*(.18 if enemy.stagger>0 else 1.0))
	var face := offset if near or motion==Vector3.ZERO else motion
	enemy.rotation.y = lerp_angle(enemy.rotation.y,atan2(-face.x,-face.z),minf(1,delta*8))
	enemy.windup = enemy.windup+delta if near and enemy.stagger<=0 else 0.0
	enemy.animate(delta,not near)
	if enemy.windup >= .66:
		enemy.windup = 0
		if hurt_lock <= 0:
			var before := health
			health = maxi(0,health-(32 if enemy.get_meta("type") in ["brute","warden"] else 19))
			director.wounded(self,before-health)
			hurt_lock = .52
			safe_time=0
			damage_time=.35
			sound.cue("hurt")
			refresh()
			if health==0:
				downs+=1
				if "revive" in perks:
					perks.erase("revive")
					revive_used=true
					health=max_hp
					hurt_lock=4
					announce("Second Chance activated")
				else: finish(false)

func start_reload() -> void:
	if state!="play" or riding() or reload_left>0 or ammo>=capacity() or reserve==0: return
	reload_left = reload_duration()
	reload_click=false
	sound.cue("rack")

func reload_duration() -> float:
	return WEAPONS[loadout].reload * (.80 if 1 in fitted else 1.0) * (.56 if "quick" in perks else 1.) * (.76 if specialty.get(loadout,"")=="handling" else 1.) / (1+.12*upgrades.get(loadout,0))

func capacity() -> int:
	return ceili(WEAPONS[loadout].mag*(1.25 if 0 in fitted else 1.0))+4*upgrades.get(loadout,0)

func show_play_floor() -> void:
	if not OS.has_feature("web") or not tower: return
	for floor_map in floors:
		floor_map.visible=floor_map==sector or floor_map==floors[0]

func riding() -> bool:
	return lift_time>0 and lift_wait<=0

func fire(melee := false) -> void:
	if state!="play" or riding() or cooldown>0 or reload_left>0: return
	if not melee and ammo==0:
		start_reload()
		return
	if not melee and loadout=="lmg" and action.spin<=0 and not action.winding:
		action.winding=true
		cooldown=.24
		sound.cue("spool",-14)
		return
	action.winding=false
	if not melee:
		ammo-=1
		if loadout=="lmg": action.spin=.47
		sound.cue(loadout)
		action.eject(self)
	else:
		action.shove=1.0
		sound.cue("swipe",-13)
	cooldown=.70 if melee else WEAPONS[loadout].cycle*(.88 if 4 in fitted else 1.)
	recoil=1.0
	action.shoot(self,melee)
	refresh()

func kill_enemy(victim, head: bool, gun_kill:bool=true) -> void:
	if gun_kill and armory.credit(loadout,30 if head else 20):
		announce("%s reached weapon level %d" % [WEAPONS[loadout].title,armory.rank(loadout)],2.4)
	enemies.erase(victim)
	fallen.append(victim)
	victim.mode="dying"
	victim.age=0
	kills+=1
	if victim.get_meta("type")=="warden": boss_defeated=true
	if head: heads+=1
	award((120 if head else 100)*(2 if buffs.get("double",0)>0 else 1))
	if kills%6==0:
		var bundle=sector.art.piece("taper",victim.position+Vector3.UP*.45,Vector3(.39,.47,.39),"+69d7bf",Vector3.ZERO,sector)
		var kind: String=["ammo","double","overload","bonus","haste","pulse"][(kills/6-1)%6]
		supplies.append({"mesh":bundle,"life":14.0,"kind":kind})
	sound.at("fall",victim.global_position,-10)

func wave_clear() -> void:
	if wave_scored==wave:
		intermission=4.0
		return
	wave_scored=wave
	intermission=director.close(self)
	announce("Resupply",1.2)

func nearby(at: Vector3 = player.position) -> Dictionary:
	var closest := 2.75
	var item := {}
	var room: Vector2i=sector.cell_at(at)
	for collection in [sector.gates,sector.stations]:
		for entry in collection:
			if entry.get("open",false) or entry.get("dormant",false): continue
			if entry.kind=="gate":
				if room not in sector.links[sector.gates.find(entry)]: continue
			elif sector.cell_at(entry.pos)!=room: continue
			var distance := Vector2(at.x-entry.pos.x,at.z-entry.pos.z).length()
			if distance < closest:
				item = entry
				closest = distance
	if item.is_empty():
		for lane in sector.lanes:
			if lane.armed or lane.occupied: continue
			if Vector2(at.x-lane.pos.x,at.z-lane.pos.z).length()<1.8: return lane
	return item

func price(item: Dictionary) -> int:
	if item.kind=="forge": return item.price*(1+mini(2,upgrades.get(loadout,0)))
	return 100 if item.get("rack",false) and item.kind in inventory else item.price

func interact() -> void:
	if state!="play" or riding(): return
	var item := nearby()
	if item.is_empty(): return
	if not choice.is_empty():
		if choice==item: confirm_choice()
		choice={}
		return
	if item.kind=="revive" and revive_used:
		announce("Second Chance already expended this run")
		return
	if item.get("rack",false):
		var weapon:String=item.kind
		if weapon in inventory:
			var remaining:int=reserve if weapon==loadout else stored[weapon][1]
			if remaining>=WEAPONS[weapon].reserve:
				announce("Reserve already full")
				return
			if not charge(price(item)):return
			if weapon==loadout:reserve=WEAPONS[weapon].reserve
			else:stored[weapon][1]=WEAPONS[weapon].reserve
			announce(WEAPONS[weapon].title+" ammo refilled")
		else:
			if not charge(price(item)):return
			equip(weapon,true)
			gun_buys+=1
			announce(WEAPONS[weapon].title+" equipped")
		sound.cue("purchase")
		refresh()
		return
	if special_interact(item): return
	if item.get("shortcut",false) and not sector.accessible.has(item.release_cell):
		announce("Release the service return from "+str(sector.room_names[item.release_cell]))
		return
	if item.kind=="seal":
		item.armed = true
		item.brace.show()
		award(20)
		director.repaired(self)
		sound.cue("rack")
		announce("Hatch braced   +20")
		refresh()
		return
	if item.kind=="exit":
		if wave>3 or (wave==3 and queued==0 and enemies.is_empty()): finish(true)
		else: announce("Beacon offline until wave 3 is clear")
		return
	if item.kind in perks:
		announce("Buff already active")
		return
	if item.kind==loadout and reserve>=WEAPONS[loadout].reserve:
		announce("Reserve already full")
		return
	var cost := price(item)
	if points<cost:
		announce("Need %d more credits" % (cost-points))
		return
	if PERKS.has(item.kind) and perks.size()>=4:
		choice=item
		choice_index=0
		return
	points -= cost
	spent+=cost
	match item.kind:
		"gate":
			item.open = true
			item.mesh.hide()
			if item.has("plaque"):item.plaque.hide()
			bought[item.id]=true
			sector.reachability()
			sector.nav.rebuild()
		"quick","vital","deadeye","recovery","revive","light":
			perks.append(item.kind)
			perk_buys+=1
			if item.kind=="vital":
				max_hp = 150
				health = max_hp
		"gun","heavy":
			if loadout!=item.kind:
				equip(item.kind,true)
				gun_buys+=1
			reserve = WEAPONS[loadout].reserve
	sound.cue("purchase")
	announce("Access granted" if item.kind=="gate" else "Supply acquired")
	refresh()

func finish(escaped: bool) -> void:
	if state=="ended": return
	state = "ended"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if escaped: sound.cue("escape")
	ui.scope.hide()
	var mode := "Vertigo" if tower else "Outpost"
	records.set_value(mode,"best",maxi(wave,records.get_value(mode,"best",0)))
	if escaped: records.set_value(mode,"fastest",minf(sim_time,records.get_value(mode,"fastest",INF)))
	records.set_value(mode,"last",{"wave":wave,"kills":kills,"headshots":heads,"shots":shots,"hits":hits,"earned":earned,"spent":spent,"time":sim_time,"downs":downs,"weapons":gun_buys,"perks":perk_buys,"contracts":director.contracts,"damage":director.damage_total,"worst_room":director.worst_room})
	var scores: Array=records.get_value(mode,"leaderboard",[])
	scores.append(wave)
	scores.sort()
	scores.reverse()
	records.set_value(mode,"leaderboard",scores.slice(0,5))
	var medals: Array=records.get_value("medals","unlocked",[])
	for pair in [[wave>=10,"Hold the Line"],[heads>=20,"Sharpshooter"],[escaped,"Last Flight"],[completed.has("cipher"),"Ghost Signal"]]:
		if pair[0] and pair[1] not in medals: medals.append(pair[1])
	records.set_value("medals","unlocked",medals)
	if not has_meta("test_run"): records.save("user://deadshift_records.cfg")
	ui.modal("EXTRACTED" if escaped else "SIGNAL LOST","Wave %d   ·   %d kills   ·   %d headshots   ·   %.0f%% accuracy\n%d earned   ·   %d spent   ·   %ds survived   ·   Best wave %d" % [wave,kills,heads,100.*hits/maxi(shots,1),earned,spent,int(sim_time),records.get_value(mode,"best",0)]+"\n"+director.debrief(self),false)

func menu_command(action: String) -> void:
	if action=="menu":
		get_tree().reload_current_scene()
	elif state=="paused":
		state = "play"
		ui.overlay.hide()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if options.panel.visible: return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
		if state=="paused": menu_command("resume")
		elif state=="play":
			state = "paused"
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			ui.modal("PAUSED","WASD move    ·    Mouse aim    ·    R reload    ·    E interact    ·    F shove",true)
		return
	if state!="play": return
	if intro>0 and event is InputEventMouseButton and event.pressed:
		intro=0
		show_play_floor()
		camera.current=true
		ui.transit.color.a=0
		ui.intro_card.hide()
		return
	if event is InputEventKey and event.pressed and not event.echo and not choice.is_empty() and options.action(event.physical_keycode) in [KEY_Q,KEY_1,KEY_2]:
		var count := 2 if choice.kind=="forge" else perks.size()
		choice_index=posmod(choice_index+( -1 if options.action(event.physical_keycode)==KEY_1 else 1),count)
		return
	if event is InputEventMouseMotion:
		if Input.mouse_mode==Input.MOUSE_MODE_CAPTURED or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			var sens: float = options.sensitivity*.0024*([.42,.65,1.][options.pref("ADS sensitivity",1)] if aiming() else 1.)
			player.rotate_y(-event.relative.x*sens)
			camera.rotation.x = clampf(camera.rotation.x-event.relative.y*sens,-1.4,1.4)
	elif event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT:
		toggle_aim=not toggle_aim
	elif event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		if Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED: Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
		fire()
	elif event is InputEventKey and event.pressed and not event.echo:
		match options.action(event.physical_keycode):
			KEY_E: interact()
			KEY_F: fire(true)
			KEY_R: start_reload()
			KEY_Q,KEY_1,KEY_2:
				if inventory.size()==2: equip(inventory[1-inventory.find(loadout)],false)
			KEY_SPACE:
				if jump_y<=0: jump_speed=5.2

func _physics_process(delta: float) -> void:
	var music := "calm"
	if state=="play" and intermission<=0:
		music="extraction" if extraction_active else ("boss" if lockdown>0 or director.challenge else "combat")
	sound.score(delta,music)
	if state=="menu":pan_preview(delta)
	if state!="play": return
	sim_time += delta
	if intro>0:
		intro=maxf(0,intro-delta)
		var elapsed:=1.85-intro
		if elapsed<1.14:
			preview_camera.position=intro_start.origin-intro_start.basis.x*elapsed*3.4
			preview_camera.look_at(intro_focus)
			ui.transit.color.a=smoothstep(.85,1.14,elapsed)
		else:
			camera.current=true
			ui.transit.color.a=1.0-smoothstep(1.14,1.66,elapsed)
		if intro==0:
			ui.transit.color.a=0
			show_play_floor()
	action.tick(delta)
	director.update(delta)
	sector.update_weather(delta,player.position,power)
	if riding():
		lift_time=maxf(0,lift_time-delta)
		var u:=smoothstep(0.0,1.0,1.0-lift_time/1.8)
		cabin.position.y=ride_origin.y+(lift_target-level)*Sector.STOREY_HEIGHT*u
		player.global_position=cabin.global_position+Vector3.UP*2.29
		if lift_time==0:
			cabin.queue_free()
			travel(lift_target)
		return
	if lift_wait>0:
		lift_wait=maxf(0,lift_wait-delta)
		if lift_wait==0:
			lift_ready=true
			lift_time=0
			announce("Car on station   /   Board at the lift",3)
			if player.position.distance_to(sector.shaft_position(0 if lift_target<level else sector.route.size()-1))<3.4: board_lift()
	tick_mission(delta)
	ui.show_directory(self)
	if state!="play": return
	var axis := Vector2(int(options.down(KEY_D))-int(options.down(KEY_A)),int(options.down(KEY_S))-int(options.down(KEY_W)))
	walking = axis.length_squared()>0
	step_clock -= delta
	if walking and step_clock<=0:
		sound.cue("step",-22)
		step_clock = .37
	var direction := player.basis*Vector3(axis.x,0,axis.y).normalized()
	var sprint := options.down(KEY_SHIFT) and walking and not aiming()
	var crouch := options.down(KEY_CTRL) or Input.is_physical_key_pressed(KEY_C)
	if crouch and sprint and sliding_ready and jump_y==0:
		slide=.55
		slide_dir=direction
		sliding_ready=false
	if not crouch: sliding_ready=true
	var speed := 7.4 if sprint else (2.9 if crouch or aiming() else 5.2)
	if "light" in perks or buffs.get("haste",0)>0: speed*=1.26
	if loadout=="lmg": speed*=.82
	if slide>0:
		speed=8.8
		direction=slide_dir
		slide-=delta
	player.position = sector.nav.move(player.position,direction*speed*delta)
	var step_height: float=sector.stair_height(player.position)
	jump_speed-=14*delta
	jump_y=maxf(0,jump_y+jump_speed*delta)
	if jump_y<=0: jump_speed=0
	player.position.y=lerpf(player.position.y,(1.02 if crouch or slide>0 else 1.65)+jump_y+step_height,minf(1,delta*18))
	camera.fov=lerpf(camera.fov,options.fov*(((.41 if loadout=="marksman" else .67)*(.80 if 5 in fitted else 1.0)) if aiming() else 1.),minf(1,delta*14))
	gun.position.x=lerpf(gun.position.x,0. if aiming() else .29,minf(1,delta*14))
	cooldown = maxf(0,cooldown-delta)
	hurt_lock = maxf(0,hurt_lock-delta)
	recoil = move_toward(recoil,0,delta*6.5)
	hit = maxf(0,hit-delta)
	ui.marker.visible = hit>0
	if reload_left>0:
		reload_left = maxf(0,reload_left-delta)
		if not reload_click and reload_left<reload_duration()*.32:
			reload_click=true
			sound.cue("rack",-16)
		if reload_left==0:
			var rounds := mini(reserve,capacity()-ammo)
			ammo += rounds
			reserve -= rounds
			refresh()
	action.pose(self)
	for dot in ui.dots: dot.visible=not aiming() and options.pref("Crosshair",1)==1
	gun.visible=true
	if action.winding and cooldown<=0: fire()
	if loadout in ["gun","smg","lmg","relic"] and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): fire()
	var item := nearby()
	ui.prompt.text = ""
	if choice!=item: choice={}
	if not item.is_empty():
		var title: String = "REFILL "+str(item.title)+" AMMO" if item.get("rack",false) and item.kind in inventory else item.title
		if item.kind=="gate":
			var pair:Array=sector.links[sector.gates.find(item)]
			var far=pair[1] if sector.cell_at(player.position)==pair[0] else pair[0]
			title="OPEN "+str(sector.room_names[far]).to_upper()
			if item.shortcut: title="OPEN SERVICE RETURN"
		var use_key := OS.get_keycode_string(options.bindings.get(KEY_E,KEY_E))
		var swap_key := OS.get_keycode_string(options.bindings.get(KEY_Q,KEY_Q))
		var icon := "◇"
		var detail := ""
		if item.get("rack",false):
			icon="⌖"
			var spec: Dictionary=WEAPONS[item.kind]
			detail="%d dmg%s · %d mag · %.0f/min · %.2fs reload" % [ceili(spec.power/4.) if item.kind=="shotgun" else spec.power," ×7" if item.kind=="shotgun" else "",spec.mag,60./spec.cycle,spec.reload]
		elif PERKS.has(item.kind): detail=PERKS[item.kind]
		elif item.kind=="gate": icon="▥"
		elif item.kind=="forge": detail=["I · induction core, damage + capacity","II · feed assembly, capacity + reload","III · choose arc ammo or tuned handling","Fully upgraded"][upgrades.get(loadout,0)]
		if not choice.is_empty():
			title=("Tune: "+("Arc ammo · penetrates" if choice_index==0 else "Handling · faster reload, less recoil")) if item.kind=="forge" else "Replace "+str(PERKS[perks[choice_index]]).get_slice(" ·",0)
			detail=swap_key+" cycle    ·    "+use_key+" confirm    ·    Move away to cancel"
		if item.kind=="seal": title="Brace entrance   +20 cr"
		if item.kind=="cache" and offered!="": title="Take "+str(WEAPONS[offered].title)
		if item.kind in ["up","down"] and lift_ready: title="Board waiting car"
		var shown_price:=price(item) if not (item.kind=="cache" and offered!="") else 0
		ui.prompt.text="%s  [%s]   %s%s" % [icon,use_key,title,("   ·   %d cr" % shown_price) if shown_price>0 else ""]
		if detail!="": ui.prompt.text+="\n"+detail
		if item.get("shortcut",false) and not sector.accessible.has(item.release_cell):
			ui.prompt.text="▥   Release from "+str(sector.room_names[item.release_cell])
	elif reload_left>0: ui.prompt.text = "Reloading"
	elif ammo==0: ui.prompt.text = "R   /   Reload" if reserve>0 else "F   /   Shove   ·   Find a wall supply"
	elif sim_time<8: ui.prompt.text = "Tab directory   ·   Shift sprint   ·   RMB aim   ·   E use   ·   Q swap   ·   Esc controls"
	note_time -= delta
	if note_time<=0: ui.banner.text = ""
	if queued>0 and director.recovery<=0 and enemies.size()<mini(options.active_cap,4+wave):
		spawn_clock -= delta
		if spawn_clock<=0:
			spawn_one()
			spawn_clock = director.cadence(self)
	for enemy in enemies:
		if enemy.mode=="opening":
			enemy.transition(delta)
			var lane: Dictionary = sector.lanes[enemy.lane]
			if enemy.age>enemy.entry_duration*.35: lane.brace.hide()
			if enemy.mode=="hunt": lane.occupied = false
		else: track(enemy,delta)
		if state!="play": break
	for corpse in fallen.duplicate():
		corpse.transition(delta)
		if corpse.is_queued_for_deletion(): fallen.erase(corpse)
	for supply in supplies.duplicate():
		supply.life -= delta
		supply.mesh.rotation.y += delta*1.8
		supply.mesh.position.y = .48+.10*sin(sim_time*3.4)
		if player.position.distance_to(supply.mesh.position)<1.95:
			apply_drop(supply.kind)
			sound.cue("purchase",-14)
			announce(str(supply.kind).to_upper()+" recovered")
			refresh()
		elif supply.life>0: continue
		supply.mesh.queue_free()
		supplies.erase(supply)
	if intermission>0:
		intermission -= delta
		if intermission<=0: begin_wave()

func award(amount: int) -> void:
	points+=amount
	earned+=amount

func charge(amount: int) -> bool:
	if points<amount:
		announce("Need %d more credits" % (amount-points))
		return false
	points-=amount
	spent+=amount
	return true

func aiming() -> bool:
	return state=="play" and (toggle_aim if options.pref("Aim mode",0) else Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT))

func equip(key: String, fresh: bool) -> void:
	stored[loadout]=[ammo,reserve]
	if not inventory.has(key):
		if inventory.size()==2: inventory.erase(loadout)
		inventory.append(key)
	loadout=key
	fitted=armory.equipped(key)
	action.winding=false
	action.spin=0
	var saved: Array=stored.get(key,[capacity(),WEAPONS[key].reserve])
	ammo=capacity() if fresh else mini(capacity(),saved[0])
	reserve=WEAPONS[key].reserve if fresh else saved[1]
	reload_left=0
	model()
	refresh()

func apply_drop(kind: String) -> void:
	match kind:
		"ammo": reserve=WEAPONS[loadout].reserve
		"bonus": award(300)
		"pulse":
			for e in enemies.duplicate():
				if e.mode!="hunt" or e.get_meta("type")=="warden": continue
				enemies.erase(e)
				fallen.append(e)
				e.mode="dying"
				e.age=0
				kills+=1
				award(50)
			if queued==0 and enemies.is_empty() and intermission<=0: wave_clear()
		_: buffs[kind]=12.0

func enter_landing(at_exit: bool) -> void:
	player.position=sector.arrival_position(at_exit)
	player.rotation=Vector3(0,sector.route_heading(at_exit),0)
	camera.rotation=Vector3.ZERO

func travel(to: int) -> void:
	# Requeue surviving attackers. Riding a lift never clears a wave for free.
	queued+=enemies.size()
	for enemy in enemies+fallen:enemy.queue_free()
	for supply in supplies:supply.mesh.queue_free()
	for lane in sector.lanes:lane.occupied=false
	enemies.clear()
	fallen.clear()
	supplies.clear()
	roll_item={}
	offered=""
	roll_time=0
	var descending := to<level
	level=to
	sector=floors[level]
	show_play_floor()
	choice={}
	lift_ready=false
	player.reparent(sector,false)
	enter_landing(descending)
	spawn_clock=.6
	jump_y=0
	update_cache()
	options.apply_quality()
	announce(Sector.FLOORS[level] if tower else ("Upper galleries" if level else "Ground floor"))
	refresh()

func ride(to:int) -> void:
	if lift_time>0: return
	if lift_ready and lift_target==to:
		board_lift()
		return
	lift_target=to
	lift_wait=3.8
	lift_time=lift_wait+1.8
	queued+=2
	intermission=0
	spawn_clock=0
	announce("Lift called   /   Hold the lobby",3.4)
	sound.cue("spool")

func board_lift() -> void:
	lift_ready=false
	lift_wait=0
	lift_time=1.8
	ride_origin=sector.to_global(sector.shaft_position(0 if lift_target<level else sector.route.size()-1))+Vector3(0,0,1.30)
	cabin=sector.build_car(self)
	cabin.global_position=ride_origin
	player.rotation.y=PI
	camera.rotation=Vector3.ZERO
	sound.cue("purchase",-14)

func confirm_choice() -> void:
	if choice.kind=="forge":
		if upgrades.get(loadout,0)!=2 or not charge(price(choice)): return
		specialty[loadout]="arc" if choice_index==0 else "handling"
		finish_forge(3)
	else:
		if not charge(price(choice)): return
		var old:=perks[choice_index]
		perks[choice_index]=choice.kind
		perk_buys+=1
		if old=="vital":
			max_hp=100
			health=mini(health,max_hp)
		if choice.kind=="vital":
			max_hp=150
			health=max_hp
		announce("Equipped   /   "+str(PERKS[choice.kind]))
	sound.cue("purchase")
	refresh()

func finish_forge(tier: int) -> void:
	upgrades[loadout]=tier
	ammo=capacity()
	model()
	announce("%s   /   Induction tier %d" % [WEAPONS[loadout].title,tier])
	sound.cue("purchase")

func update_cache() -> void:
	for i in sector.caches.size():
		var c: Dictionary=sector.caches[i]
		c.dormant=i!=(rolls/3)%sector.caches.size()
		c.label.text="DRIFT CACHE  /  OFFLINE" if c.dormant else "DRIFT CACHE"

func special_interact(item: Dictionary) -> bool:
	match item.kind:
		"objective":
			if completed.has(level):
				announce("Security released   /   proceed to lift")
			elif level==5:
				if defense<0 and not extraction_active:
					extraction_active=true
					defense=30
					queued+=10
					intermission=0
					must_defeat=true
					boss_defeated=false
					sound.cue("round")
					announce("Radio live   /   Defend the helipad")
			elif level==4:
				if lockdown<=0:
					lockdown=16
					queued+=6
					intermission=0
					must_defeat=true
					boss_defeated=false
					announce("Security lockdown   /   Defeat the Warden")
			else:
				completed[level]=true
				if level==0: power=true
				sound.cue("purchase")
				announce(["Power restored","Security badge acquired","Lift coupling secured","Elevator repaired"][level])
		"up":
			if (tower and not completed.has(level)) or (not tower and not power):
				announce(Sector.JOBS[level]+" first" if tower else "Start the generator first")
			else: ride(level+1)
		"down":
			if lockdown>0 or extraction_active: announce("Emergency lockdown")
			else: ride(level-1)
		"board":
			announce("Enter through the open rear of the helicopter" if boarding>0 else "Signal the roof radio and hold the pad")
		"power":
			power=true
			sector.update_weather(0,player.position,true)
			sound.cue("spool")
			announce("Generator online   /   Induction forge powered")
		"lore","lore_b":
			completed["tape0" if item.kind=="lore" else "tape1"]=true
			var tape_a: bool=item.kind=="lore"
			sub_time=sound.tape(tape_a)
			ui.subtitle.text="MESS HALL   /   Ridgeline, this is mess hall. The ridge is repeating our signal.\nCheck the observatory tape." if tape_a else "OBSERVATORY   /   The answer is below the relay lab console.\nDecode it before the signal fades."
		"secret":
			if not completed.has("tape0") or not completed.has("tape1"):
				announce("Two field recordings needed: mess hall and observatory",4)
			elif not completed.has("cipher"):
				completed.cipher=true
				award(500)
				equip("relic",true)
				announce("Relay cipher decoded   /   Aurora Coil unlocked")
			else: announce("Relay cipher archived")
		"forge":
			var tier: int=upgrades.get(loadout,0)
			if not power: announce("Requires generator power")
			elif tier>=3: announce("Maximum induction tier")
			elif tier==2:
				choice=item
				choice_index=0
			elif charge(price(item)): finish_forge(tier+1)
		"cache":
			if roll_time>0: return true
			if offered!="" and roll_item==item:
				equip(offered,true)
				gun_buys+=1
				offered=""
				rolls+=1
				update_cache()
			elif charge(item.price):
				roll_item=item
				roll_time=1.8
				sound.cue("rack")
		_: return false
	refresh()
	return true

func tick_mission(delta: float) -> void:
	for key in buffs: buffs[key]=maxf(0,buffs[key]-delta)
	safe_time+=delta
	if safe_time>(2.4 if "recovery" in perks else 5.) and health<max_hp:
		regen+=delta*(14 if "recovery" in perks else 7)
		if regen>=1:
			health=mini(max_hp,health+int(regen))
			regen=fmod(regen,1.)
			refresh()
	damage_time=maxf(0,damage_time-delta)
	ui.damage.color.a=damage_time*.68
	if roll_time>0:
		roll_time-=delta
		var choices:=["smg","shotgun","lmg","marksman","heavy"]
		roll_item.label.text=WEAPONS[choices[int(roll_time*10)%5]].title
		if roll_time<=0:
			offered="relic" if randf()<.08 else choices.pick_random()
			roll_item.label.text="TAKE   /   "+str(WEAPONS[offered].title)
			buffs["offer"]=12
	elif offered!="" and buffs.get("offer",0)<=0:
		offered=""
		rolls+=1
		update_cache()
	if lockdown>0:
		lockdown=maxf(.01,lockdown-delta)
		if lockdown<=.02 and boss_defeated:
			lockdown=0
			completed[level]=true
			announce("Lockdown lifted   /   Rooftop access granted")
	if defense>=0 or boarding>0:
		rotor_audio-=delta
		if rotor_audio<=0:
			sound.cue("rotors",-20 if defense>12 else -12)
			rotor_audio=.30
	if defense>=0:
		defense=maxf(0,defense-delta)
		sector.helicopter.show()
		sector.rotor.rotate_y(delta*26)
		var u:=1.-defense/30.
		sector.helicopter.position=sector.landing_pad+Vector3(sin(u*TAU)*2.2,lerpf(19,.97,u)+sin(sim_time*2)*.13*(1.-u),lerpf(-28,0.,u))
		sector.helicopter.rotation.z=sin(u*TAU)*.12
		if defense==0 and boss_defeated and not must_defeat:
			defense=-1
			sector.secure_landed_cabin()
			boarding=25
			previous_board_pos=player.position-sector.helicopter.position
			announce("Aircraft on station   /   Board now",4)
	elif boarding>0:
		sector.rotor.rotate_y(delta*26)
		var local:Vector3=player.position-sector.helicopter.position
		if previous_board_pos.z>=1.25 and local.z<1.25 and local.z>.40 and absf(local.x)<.85 and local.y>.0 and local.y<1.7:
			finish(true)
			return
		previous_board_pos=local
		boarding-=delta
		if boarding<=0: finish(false)
	var task: String
	if tower:
		task = "Use the marked lift" if completed.has(level) else Sector.JOBS[level]
		if lockdown>0: task="Security lockdown  %ds   /   Eliminate Warden" % ceili(lockdown)
		if defense>=0: task="Hold the roof  %ds   /   Eliminate Warden" % ceili(defense)
		if boarding>0: task="Enter rear cabin  ·  %ds" % ceili(boarding)
	else:
		task="Survive   /   Explore the ridge" if power else "Reach Generator   /   Restore power"
	ui.objective.text=("Hold lift lobby   %ds" % ceili(lift_wait)) if lift_wait>0 else task
	ui.contract.text=director.contract_text(wave)
	ui.card.text=director.scorecard if director.card_time>0 else ""
	sub_time=maxf(0,sub_time-delta)
	ui.subtitle.visible=sub_time>0
	ui.intro_card.visible=intro>0
	ui.intro_card.modulate.a=smoothstep(0,.3,intro)
	if intro>0: ui.intro_card.text="VERTIGO TOWER   /   Ground floor" if tower else "THE OUTPOST   /   Ridge perimeter"
	if Engine.get_physics_frames()%15==0: refresh()
