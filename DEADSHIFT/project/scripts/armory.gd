extends RefCounted

const SAVE := "user://weapon_armory.cfg"
const STEPS := [0,100,250,450,700,1000]
const PARTS := ["Extended magazine","Speed loader","Stabilizer","Pulse core","Cycle tuner","Precision lens"]
const UNLOCK := [2,2,3,4,5,6]
const INFO := ["+25% magazine","20% faster reload","35% less kick","Extra hit power","12% faster fire","Deeper ADS zoom"]
var data := ConfigFile.new()
var testing := false

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
	if not testing and data.save(SAVE)!=OK: push_warning("Weapon progress could not be saved")
