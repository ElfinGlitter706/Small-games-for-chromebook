extends RefCounted

const RULES := ["Fast pursuit","Scarce drops","Armored elites","Two perks","Starting room only"]
var mods: Array=[]
var seed_value:=0
var daily:=false
var practice:=false
var masked:=false
var letters:=""
var train_wave:=-1
var freight_ready:=false
var condition:=""
var affected:=Vector2i.ZERO
var condition_floor:=-1
var time_left:=0.0
var event:=""
var slow:=0.0
var interference:=0.0
var kit:=""
var carried:=false
var delivery:=false
var usage:Dictionary={}
var cause:="Overrun"
var roster:Array=[]
var rng:=RandomNumberGenerator.new()

func gate_funds(g) -> int:
	var available:int=g.points
	for mate in roster:
		if mate!=g and is_instance_valid(mate) and mate.sector==g.sector:available+=mate.points
	return available

func pay_gate(g,price:int) -> void:
	var paid:=mini(g.points,price)
	g.points-=paid
	g.spent+=paid
	var remaining:=price-paid
	for mate in roster:
		if remaining==0:break
		if mate==g or not is_instance_valid(mate) or mate.sector!=g.sector:continue
		paid=mini(mate.points,remaining)
		mate.points-=paid
		mate.spent+=paid
		remaining-=paid

func revive_nearby(g) -> bool:
	for mate in roster:
		if mate!=g and is_instance_valid(mate) and mate.state=="downed" and mate.sector==g.sector and mate.player.position.distance_to(g.player.position)<2.2:
			mate.health=mate.max_hp/2
			mate.hurt_lock=3.0
			mate.state="play"
			mate.refresh()
			return true
	return false

func target(local, enemy):
	var best=local
	var distance:=INF
	for member in roster:
		if not is_instance_valid(member) or member.health<=0 or member.sector!=local.sector:continue
		var d:float=enemy.position.distance_squared_to(member.player.position)
		if d<distance:
			best=member
			distance=d
	return best

func begin(g) -> void:
	roster=[g]
	daily=g.options.pref("Daily seed",0)==1
	seed_value=hash(Time.get_date_string_from_system(true)+str(g.tower)) if daily else randi()
	for name in RULES:
		if g.options.pref(name,0):mods.append(name)

func multiplier() -> float:
	return 1.0+.15*mods.size()

func open_wave(g) -> void:
	rng.seed=hash([seed_value,g.wave])
	time_left=0
	event=""
	condition=""
	if practice:
		g.queued=1
		return
	if train_wave>=0 and not freight_ready and g.wave>train_wave:
		g.queued+=ceili(g.queued*.45)
	if g.wave>=3:
		event=["","Supply discount","Supply delivery","Mountain squall" if not g.tower else "Grid fault"][rng.randi_range(0,3)]
		if event=="Supply delivery":
			var pos:Vector3=g.player.position+Vector3.UP*.3
			var box=g.sector.art.piece("box",pos+Vector3.RIGHT*1.4,Vector3(.5,.43,.52),"+90c9ae",Vector3.ZERO,g.sector)
			g.supplies.append({"mesh":box,"life":18.0,"kind":"ammo"})
		if g.tower and g.wave%2==1:
			condition=["Emergency lighting","Coolant fog","Voltage surge","Overrun"][rng.randi_range(0,3)]
			var cells:Array=g.sector.accessible.keys()
			affected=cells[rng.randi_range(0,cells.size()-1)]
			condition_floor=g.level
		time_left=22
		if not event.is_empty():g.announce(event,2.1)

func in_condition(g) -> bool:
	return g.tower and time_left>0 and g.level==condition_floor and g.sector.cell_at(g.player.position)==affected

func tick(g,dt:float) -> void:
	time_left=maxf(0,time_left-dt)
	slow=maxf(0,slow-dt)
	interference=maxf(0,interference-dt)
	var active:=in_condition(g)
	var wash:Color=Color.TRANSPARENT
	if active:
		match condition:
			"Emergency lighting": wash=Color(.08,.01,.0,.45)
			"Coolant fog": wash=Color(.56,.68,.72,.32)
			"Voltage surge": wash=Color(.23,.40,.55,.07+.12*absf(sin(time_left*5)))
	if not g.tower and event=="Mountain squall" and time_left>0 and g.sector.outdoor_cells.has(g.sector.cell_at(g.player.position)):
		wash=Color(.64,.71,.73,.22)
	g.ui.climate.color=wash
	var lines:=PackedStringArray()
	if active:lines.append(condition+"   ·   "+str(ceili(time_left))+"s")
	elif g.tower and time_left>0 and condition!="" and g.level==condition_floor:lines.append(condition+"   ·   "+str(g.sector.room_names.get(affected,"")))
	if event=="Grid fault" and time_left>0:lines.append("Grid fault   ·   Forge and cache offline")
	if event=="Supply discount" and time_left>0:lines.append("Wall supply sale   −25%")
	if train_wave>=0:
		lines.append("Transit depot   ·   Board the train" if freight_ready else "Relief train   ·   Clear wave %d" % (train_wave+3))
	if carried:lines.append("Relay battery   ·   Deliver to Transit depot")
	if kit!="":lines.append(kit+"   ["+OS.get_keycode_string(g.options.bindings.get(KEY_G,KEY_G))+"]")
	if practice:lines.append("Practice   ·   G next gun   ·   T next target   ·   Y forge tier")
	g.ui.field_status.text="\n".join(lines)
	if not g.tower and is_instance_valid(g.sector.train):
		g.sector.train.visible=freight_ready
		if freight_ready:g.sector.train.position.z=move_toward(g.sector.train.position.z,g.sector.platform.z,dt*5)

func discover(g,name:String) -> void:
	var entries:Array=g.records.get_value("discoveries","found",[])
	if not entries.has(name):
		entries.append(name)
		g.records.set_value("discoveries","found",entries)
		if not g.has_meta("test_run") and not practice:g.records.save("user://deadshift_records.cfg")

func type_key(g,key:int) -> void:
	if key<KEY_A or key>KEY_Z:
		letters=""
		return
	letters+=String.chr(key).to_lower()
	while not letters.is_empty() and not "temamila".begins_with(letters):letters=letters.substr(1)
	if letters=="temamila" and not masked:
		masked=true
		for z in g.enemies+g.fallen:z.wear_portrait()
		discover(g,"Temamila")
		g.announce("Signal intercepted")

func jammed(g,item:Dictionary) -> bool:
	if item.kind not in ["forge","cache"]:return false
	if time_left>0 and (event=="Grid fault" or (in_condition(g) and condition=="Voltage surge")):return true
	for enemy in g.enemies:
		if enemy.get_meta("type")=="lineman" and enemy.position.distance_squared_to(item.pos)<16:return true
	return false

func interact(g,item:Dictionary) -> bool:
	match item.kind:
		"dispatch":
			if carried:
				carried=false
				delivery=true
				g.award(600)
				g.announce("Relay battery delivered   +600 cr")
			elif freight_ready:
				g.announce("Board at the green carriage door")
			elif train_wave>=0:g.announce("Train inbound   /   Clear wave %d" % (train_wave+3))
			elif not g.power:g.announce("Restore generator power to call the train")
			else:
				train_wave=g.wave
				g.sound.cue("radio")
				g.announce("Train called   /   Hold through wave %d" % (train_wave+3),4)
		"carriage":
			if freight_ready and absf(g.sector.train.position.z-g.sector.platform.z)<.1:
				cause="Relief train"
				g.finish(true)
			else:g.announce("Await the relief train")
		"battery":
			if delivery:g.announce("Relay battery delivered")
			elif not carried:
				carried=true
				g.announce("Carry the battery to Transit depot")
		"medical","plate","beacon":
			if kit!="":g.announce("Use your carried equipment first")
			elif g.charge(g.price(item)):
				kit={"medical":"Medkit","plate":"Armor plate","beacon":"Pulse beacon"}[item.kind]
				g.announce(kit+" packed")
		_: return false
	return true

func use_kit(g) -> void:
	match kit:
		"Medkit":
			if g.health>=g.max_hp:return
			g.health=mini(g.max_hp,g.health+65)
		"Armor plate":g.buffs["shield"]=12.
		"Pulse beacon":
			for z in g.enemies:
				if z.position.distance_to(g.player.position)<7:z.stagger=2.0
		_:return
	kit=""
	g.sound.cue("purchase")
	g.refresh()
