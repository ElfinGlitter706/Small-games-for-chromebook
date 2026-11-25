extends RefCounted

const SAVE := "user://weapon_armory.cfg"
# Costs for levels 2–6 are 100, 250, 500, 850 and 1,300 XP.
const STEPS := [0,100,350,850,1700,3000]
const OLD_STEPS := [0,100,250,450,700,1000]
const PARTS := ["Extended magazine","Speed loader","Stabilizer","Pulse core","Cycle tuner","Precision lens"]
const UNLOCK := [2,2,3,4,5,6]
const INFO := ["+25% magazine","20% faster reload","35% less kick","Extra hit power","12% faster fire","Deeper ADS zoom"]
const TASKS := {"sidearm":["Headshot streak",3],"gun":["One magazine",8],"shotgun":["Close range",18],"smg":["One magazine",9],"lmg":["One magazine",16],"heavy":["Elite kills",8],"marksman":["Headshot streak",5],"relic":["Penetrations",10]}

func mastered(key:String) -> bool:
	return int(data.get_value(key,"mastery",0))>=int(TASKS[key][1])

func advance(key:String,value:int,personal_best:=false) -> void:
	var current:=int(data.get_value(key,"mastery",0))
	var goal:int=TASKS[key][1]
	if current>=goal:return
	var next:=mini(goal,maxi(current,value) if personal_best else current+value)
	if next!=current:
		data.set_value(key,"mastery",next)
		save()

var data := ConfigFile.new()
var testing := false

func load_progress() -> void:
	if data.load(SAVE)==OK: migrate_progress()

func migrate_progress() -> void:
	if data.get_value("profile","curve",1)>=2: return
	for key in data.get_sections():
		if not data.has_section_key(key,"xp"): continue
		var earned:=xp(key)
		var level:=0
		for i in range(1,OLD_STEPS.size()):
			if earned>=OLD_STEPS[i]: level=i
		data.set_value(key,"xp",STEPS[level]+earned-OLD_STEPS[level])
	save()

func xp(key:String) -> int:
	return maxi(0,int(data.get_value(key,"xp",0)))

func rank(key:String) -> int:
	var result:=1
	for i in range(1,STEPS.size()):
		if xp(key)>=STEPS[i]: result=i+1
	return result

func slots(key:String) -> int:
	return clampi(rank(key)-1,0,4)

func equipped(key:String) -> Array:
	var parts:Array=[]
	for part in data.get_value(key,"parts",[]):
		if part is int and part>=0 and part<PARTS.size() and part not in parts and UNLOCK[part]<=rank(key) and parts.size()<slots(key):
			parts.append(part)
	return parts

func toggle(key:String,part:int) -> bool:
	var parts:=equipped(key)
	if part in parts: parts.erase(part)
	elif part>=0 and part<PARTS.size() and rank(key)>=UNLOCK[part] and parts.size()<slots(key): parts.append(part)
	else:return false
	data.set_value(key,"parts",parts)
	save()
	return true

func credit(key:String,amount:int) -> bool:
	var before:=rank(key)
	data.set_value(key,"xp",xp(key)+amount)
	save()
	return rank(key)>before

func save() -> void:
	data.set_value("profile","curve",2)
	if not testing and data.save(SAVE)!=OK: push_warning("Weapon progress could not be saved")
