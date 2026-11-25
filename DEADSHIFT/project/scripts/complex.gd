extends "res://scripts/sector.gd"

const FLOORS := ["Lobby","Offices","Commercial","Maintenance","Executive","Rooftop"]
const JOBS := ["Restore mains power","Collect the security badge","Recover a lift coupling","Repair the service elevator","Override executive security","Signal extraction"]
const TOWER_ROOMS := [
	["Reception","Coat check","Gallery","Security","Switchgear","Atrium","East lifts"],
	["Mail room","Open office","Copy room","Conference","Records","West hall","West lifts"],
	["Arcade","Shops","Food court","Cold store","Freight depot","Loading bay","East lifts"],
	["Pump room","Filters","Boiler room","Workshop","Lift motor","Service bay","West lifts"],
	["Sky lounge","Archives","Boardroom","Skybridge","Control vault","East hall","East lifts"],
	["Roof access","Fan bank","Array deck","Floodlights","Radio shack","Flight deck","Pad approach","Helipad"]]
const OUTPOST := [
	["Guardhouse","Intake bridge","Barracks","Generator","Motor pool","Mess hall","Infirmary","Crane walk","Transit depot"],
	["Ridge gate","Signal bridge","Armoury","Watch office","Observatory","Signals","Relay lab","Ridge walk","Magazine"]]
const OUTPOST_ROUTE := [Vector2i(-3,0),Vector2i(-2,0),Vector2i(-1,0),Vector2i(-1,-1),Vector2i(0,-1),Vector2i(0,0),Vector2i(1,0),Vector2i(2,0),Vector2i(3,0)]
const TOWER_ROUTE := [Vector2i(-2,0),Vector2i(-1,0),Vector2i(-1,1),Vector2i(0,1),Vector2i(1,1),Vector2i(1,0),Vector2i(2,0)]
const TINTS := ["4b6971","45626b","836a51","596757","614f62","3c5565"]
const STOREY_HEIGHT := 5.1
const RIDGE_START := 16
const CROSSING := [Vector2i(4,0),Vector2i(5,0),Vector2i(6,0),Vector2i(6,1),Vector2i(6,2),Vector2i(5,2),Vector2i(4,2)]
var powered_lamps: Array[MeshInstance3D] = []
var beacons: Array[MeshInstance3D] = []
var outdoor_cells := {}
var weather: CPUParticles3D
var weather_time := 0.0
var storm_flash: MeshInstance3D
var weather_audio := 0.0
var stairs: Array[Vector3] = []
var last_power := false
var level := 0
var links: Array = []
var accessible := {}
var room_names := {}
var route: Array[Vector2i] = []
var lift_pad := Vector3.ZERO
var landing_pad := Vector3.ZERO
var rotor: Node3D
var helicopter: Node3D
var caches: Array = []
var active_cache := 0
var lift_accents: Array = []

func build_floor(is_tower: bool, number: int, bought: Dictionary) -> void:
	tower = is_tower
	level = number
	art = Art.new(self)
	shade = TINTS[level] if tower else ("465a52" if level==0 else "526375")
	glow = "+8be3d3" if tower else "+ffbf78"
	city_elevation=6.-level*2.6 if tower else 0.
	if level==0: lighting()
	var names: Array
	if tower:
		names=TOWER_ROOMS[level]
		for cell:Vector2i in TOWER_ROUTE:
			route.append(Vector2i(-cell.x if level%2 else cell.x,cell.y))
		if level==5: route.append(route.back()+Vector2i.LEFT)
	else:
		names=OUTPOST[0]+["Loading dock","Warehouse","Machine hall","Cable yard","Switch house","Depot annex","Ridge approach"]+OUTPOST[1]
		route.append_array(OUTPOST_ROUTE)
		route.append_array(CROSSING)
		for cell:Vector2i in OUTPOST_ROUTE:
			route.append(Vector2i(0,2)-cell)
	for i in route.size():
		nav.rooms[route[i]] = true
		room_names[route[i]] = names[i]
	if level==0: vista()
	if level==0:
		art.piece("box",Vector3(15,-4.1,10),Vector3(210,3,150),"635c50" if not tower else "424857")
	var deck := ShaderMaterial.new()
	deck.shader = preload("res://scripts/deck.gdshader")
	deck.set_shader_parameter("lightweight",OS.has_feature("web"))
	deck.set_shader_parameter("steel",Color(shade))
	for i in route.size():
		var cell: Vector2i = route[i]
		var center := center_of(cell)
		var bridge := not tower and i in [1,7,RIDGE_START+1,RIDGE_START+7]
		var shaft_room := tower and ((i==0 and level>0) or (i==route.size()-1 and level<5))
		if shaft_room:
			cut_deck(center,shaft_position(i)+Vector3.BACK*1.30,-.13,deck)
		else:
			var slab:=art.piece("box",center+Vector3.DOWN*.13,Vector3(12,.24,4.8 if bridge else 12.),shade,Vector3.ZERO,self)
			slab.material_override=deck
		if not bridge and level==0:
			art.piece("box",center+Vector3.DOWN*1.46,Vector3(11.9,2.65,11.9),"485354")
		var indoor := not bridge and not (tower and level==5) and (tower or (i%3!=1))
		if not indoor: outdoor_cells[cell]=true
		if bridge: trestle(center)
		if indoor:
			if shaft_room: cut_deck(center,shaft_position(i)+Vector3.BACK*1.30,4.65,null)
			else: art.piece("box",center+Vector3.UP*4.65,Vector3(12,.24,12),"38434b")
			for x in [-3,3]:
				art.piece("box",center+Vector3(x,4.48,0),Vector3(.18,.12,4),glow)
		for d: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			if bridge and d.y!=0: continue
			var adjacent := cell+d
			var internal: bool = nav.rooms.has(adjacent)
			if internal and (d==Vector2i.LEFT or d==Vector2i.UP): continue
			var lateral := Vector3(-d.y,0,d.x)
			var wall_center := center+Vector3(d.x,0,d.y)*6
			var across := Vector3(absf(lateral.x),0,absf(lateral.z))
			var thickness := Vector3(absf(d.x)*.32,0,absf(d.y)*.32)
			var pad_cell:=tower and level==5 and i>=6
			if pad_cell:
				if internal and route.find(adjacent)>=6:
					passage(i,route.find(adjacent),wall_center,across,thickness,bought)
					continue
				if not internal:
					solid(wall_center+Vector3.UP*.42,across*12+Vector3.UP*.84+thickness,"47575f")
					art.piece("box",wall_center+Vector3.UP*.87,across*11.90+Vector3.UP*.08+thickness,glow)
					continue
			if tower and not internal:
				art.piece("box",wall_center+Vector3.DOWN*.17,across*12+Vector3.UP*.38+thickness*2.3,"353e50")
				art.piece("box",wall_center+Vector3.DOWN*.07,across*11.6+Vector3.UP*.065+thickness*2.5,glow)
				if level<5:
					for side:float in [-1,1]:
						art.piece("box",wall_center+lateral*side*5.8+Vector3.UP*2.5,Vector3(.38,5.1,.38),"526579")
			for side in [-1.,1.]:
				solid(wall_center+lateral*side*3.8+Vector3.UP*1.7,across*4.4+Vector3.UP*3.4+thickness,shade)
			if internal:
				passage(i,route.find(adjacent),wall_center,across,thickness,bought)
			else:
				solid(wall_center+Vector3.UP*.57,across*3.2+Vector3.UP*1.14+thickness,shade)
				for slat in [-.96,.96]: art.beam(wall_center+lateral*slat+Vector3.UP,wall_center+lateral*slat+Vector3.UP*3.4,.09,"798582")
				var approach := wall_center-Vector3(d.x,0,d.y)*1.1
				if i==0 or (not tower and i==4) or (i+d.x+d.y)%2==0 or tower:
					window_lane(approach,wall_center,cell)
		var room_sign := art.signpost(names[i].to_upper(),center+Vector3(-3.4,3.45,-1.8 if bridge else -3.9),29,"cde6dc")
		room_sign.visibility_range_end=13
		if not bridge and not (tower and level==5 and i>=6):
			dress(center,i)
			furnish(center,names[i],indoor)
		if i+1<route.size():
			route_marks(center,center_of(route[i+1])-center)
	hatch(center_of(route[0])+Vector3(-3.8,0,-3.8),-1)
	lanes.back().cell = route[0]
	place_equipment()
	if not tower: build_ridge()
	if not tower or level==5: build_weather()
	for lane in lanes:
		lane.disabled=not nav.clear_at(lane.pos,.48)
	art.finish()
	reachability()
	nav.rebuild()

func center_of(cell: Vector2i) -> Vector3:
	return Vector3(cell.x*12,0,cell.y*12)

func passage(a: int, b: int, pos: Vector3, across: Vector3, thickness: Vector3, bought: Dictionary) -> void:
	var first := mini(a,b)
	var next := maxi(a,b)
	var shortcut := next-first>1
	var cost := 0
	if shortcut:
		cost = 500
	elif next%2==1 and not (tower and level==5 and next==7):
		cost = 450 + 150*floori(next/2.) + (75*level if tower else 0)
	var id := "%d/%d/%d" % [level,first,next]
	var opened := cost==0 or bought.has(id)
	var gate := solid(pos+Vector3.UP*1.54,across*3.25+Vector3.UP*3.08+thickness,"76614b" if not shortcut else "426664",true)
	gate.visible = not opened
	for y in [-.31,0.,.31]:
		art.piece("box",Vector3(0,y,0),Vector3(1.035,.04,1.035),glow,Vector3.ZERO,gate)
	links.append([route[first],route[next]])
	gates.append({"kind":"gate","id":id,"price":cost,"title":"OPEN PASSAGE","pos":pos,"open":opened,"mesh":gate,"shortcut":shortcut,"release_cell":route[next]})
	for side in [-1.,1.]:
		var jamb:Vector3 = pos+across*(1.74*side)
		art.piece("box",jamb+Vector3.UP*1.55,Vector3(.24,3.1,.24),"39464b")
		art.piece("box",jamb+Vector3.UP*2.76,Vector3(.26,.38,.26),glow)
	if cost>0:
		var plaque := art.signpost("SERVICE RETURN" if shortcut else "%d CR" % cost,pos+Vector3.UP*3.43,32,"ead1aa")
		plaque.visibility_range_end=12
		plaque.visible=not opened
		gates.back().plaque=plaque

func route_marks(center: Vector3, outgoing: Vector3) -> void:
	var forward := outgoing.normalized()
	var side := Vector3(-forward.z,0,forward.x)
	for distance in [2.1,3.1,4.1]:
		var tip: Vector3 = center+forward*distance+Vector3.UP*.025
		for sign_value in [-1.,1.]:
			art.beam(tip-forward*.42+side*.34*sign_value,tip,.07,"c7a363" if not tower else "72bbbc")

func trestle(center: Vector3) -> void:
	for side in [-1.,1.]:
		var edge := center+Vector3(0,0,2.4*side)
		var rail := art.piece("box",edge+Vector3.UP*1.07,Vector3(12,.12,.12),"ab9169",Vector3.ZERO,self)
		nav.add_obstacle(rail,Vector3(12,1.15,3.75),center+Vector3(0,.575,4.225*side))
		art.piece("box",edge+Vector3.DOWN*.42,Vector3(12,.62,.26),"45514e")
		for x in range(-5,6,2):
			art.beam(edge+Vector3(x,-.55,0),edge+Vector3(x,1.06,0),.12,"7e8c82")
			art.beam(edge+Vector3(x-1,-1.3,0),edge+Vector3(x+1,-.25,0),.13,"657870")
			art.piece("box",edge+Vector3(x,1.15,0),Vector3(.19,.12,.19),glow)

func cell_at(pos: Vector3) -> Vector2i:
	return Vector2i(floori((pos.x+6)/12),floori((pos.z+6)/12))

func window_lane(pos: Vector3, sill: Vector3, cell: Vector2i) -> void:
	var latch := art.piece("box",sill+Vector3.UP*1.6,Vector3(2.7,.23,.12) if absf(pos.z-sill.z)>.1 else Vector3(.12,.23,2.7),"a9855d",Vector3.ZERO,self)
	lanes.append({"kind":"seal","title":"BOARD WINDOW","price":0,"pos":pos,"gate":-1,"brace":latch,"armed":true,"occupied":false,"cell":cell,"outside":sill+(sill-pos)*.85})

func reachability() -> void:
	accessible = {}
	accessible[route[0]]=true
	for pass_index in nav.rooms.size():
		for i in links.size():
			if not gates[i].open: continue
			var link: Array = links[i]
			if accessible.has(link[0]) or accessible.has(link[1]):
				accessible[link[0]]=true
				accessible[link[1]]=true

func dress(c: Vector3, i: int) -> void:
	var p := c+Vector3(3,0,-2)
	match (level if tower else i%6):
		0,1,4:
			solid(p+Vector3.UP*.55,Vector3(2.5,1.1,1),"544b43" if level==4 else "596669")
			art.piece("box",p+Vector3.UP*1.47,Vector3(.88,.57,.095),"17313b")
			art.piece("box",p+Vector3(0,1.5,.056),Vector3(.72,.34,.01),"+699d9a")
			art.piece("oval",p+Vector3(1.55,1.3,.55),Vector3(.67,.85,.62),"496451")
		2:
			solid(p+Vector3.UP*.78,Vector3(2.8,1.55,1.3),"745f50")
			for k in 5: art.piece("taper",p+Vector3(-1+k*.48,1.73,0),Vector3(.25,.35,.24),"bd9b6e")
		3,5:
			solid(p+Vector3.UP*.72,Vector3(2,1.44,1.8),"43555f")
			for k in 6: art.piece("box",p+Vector3(0,.3+k*.16,.93),Vector3(1.7,.065,.04),"889b97")
			art.piece("pipe",p+Vector3.UP*1.55,Vector3(1.45,.24,1.45),"677774")

const STOCK := {
	"gun":["FEN CARBINE",350,"+6bdfc9"], "heavy":["ARC DRIVER",650,"+ffba75"],
	"vital":["SECOND PULSE",450,"+ff939a"], "quick":["QUICK CURRENT",400,"+9ad7ef"],
	"forge":["INDUCTION FORGE",700,"+ffab76"], "cache":["DRIFT CACHE",450,"+b99aec"],
	"recovery":["RAPID RECOVERY",500,"+b2d298"], "deadeye":["DEADEYE",550,"+b2d298"],
	"light":["LIGHTWEIGHT",600,"+b2d298"], "revive":["SECOND CHANCE",650,"+b2d298"]}
const TOWER_STOCK := [
	{"gun":1,"recovery":3}, {"quick":1,"cache":[3,6]}, {"vital":2,"heavy":5},
	{"forge":2,"light":5}, {"deadeye":2,"revive":5}, {"gun":2,"heavy":5}]
const OUTPOST_STOCK := [
	{"gun":2,"cache":[4,10],"vital":6,"forge":8},
	{"recovery":0,"heavy":2,"deadeye":3,"quick":4,"light":6,"revive":8}]
const RIDGE_COUNTERS := {0:Vector2(3.35,3.9),2:Vector2(3.35,-4.55),3:Vector2(3.35,3.9),
	4:Vector2(-3.35,-4.55),6:Vector2(-3.35,-4.55),8:Vector2(3.35,3.9)}

func shaft_position(index: int) -> Vector3:
	var center := center_of(route[index])
	return center+Vector3(signf(center.x)*3.7,0,-2.65)

func arrival_position(at_exit: bool) -> Vector3:
	var index := route.size()-1 if at_exit else 0
	var center := center_of(route[index])
	return center+Vector3(signf(center.x)*2.3,1.65,.55)

func route_heading(at_exit: bool) -> float:
	var index := route.size()-1 if at_exit else 0
	var adjacent := index-1 if at_exit else 1
	var aim := center_of(route[adjacent])-center_of(route[index])
	return atan2(-aim.x,-aim.z)

func stock_room(kind: String, index: int) -> void:
	if kind in ["gun","heavy"]: return
	var spec: Array = STOCK[kind]
	var offset := Vector3(3.35,0,3.9) if index%2==0 else Vector3(-3.4,0,-4.65)
	if not tower and kind=="cache" and index==4: offset=Vector3(4.15,0,4.25)
	if not tower and index>=RIDGE_START:
		var counter: Vector2 = RIDGE_COUNTERS[index-RIDGE_START]
		offset=Vector3(counter.x,0,counter.y)
	station(kind,spec[0],spec[1],center_of(route[index])+offset,spec[2],offset.z>0)
	if kind=="cache":
		var item: Dictionary = stations.back()
		item.dormant = not caches.is_empty()
		if item.dormant: item.label.text="DRIFT CACHE  /  OFFLINE"
		caches.append(item)

const WALL_PRICES := {"sidearm":200,"gun":350,"smg":550,"shotgun":700,"heavy":850,"marksman":950,"lmg":1200}
const WALL_NAMES := {"sidearm":"ROOK","gun":"FEN CARBINE","smg":"FINCH SMG","shotgun":"KILN SCATTERGUN","heavy":"ARC DRIVER","marksman":"VESPER MARKSMAN","lmg":"BREAKWATER LMG"}

func mount_rack(kind: String) -> void:
	var best := -INF
	var anchor := Vector3.ZERO
	var inward := Vector3.FORWARD
	var fixed:Dictionary={"gun":1 if tower else 2,"heavy":5 if tower else RIDGE_START+2,"sidearm":0}
	if tower and level==5: fixed.gun=2
	for i in route.size():
		if fixed.has(kind) and i!=fixed[kind]:continue
		if not tower and i in [1,7,RIDGE_START+1,RIDGE_START+7]:continue
		for normal in [Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK]:
			var lateral:=Vector3(normal.z,0,-normal.x)
			for along:float in [-4.75,-3.6,-2.96,2.96,3.6,4.75]:
				var point:Vector3=center_of(route[i])+normal*5.76+lateral*along
				if kind=="sidearm" and not tower and normal!=Vector3.LEFT:continue
				if not nav.clear_at(point-normal*1.5):continue
				var gap:=100.0
				for item in stations:
					var distance:=point.distance_to(item.pos)
					if item.price==0 and distance>3.5:continue
					gap=minf(gap,distance)
				if gap>best:
					best=gap
					anchor=point
					inward=-normal
	var rack:=Node3D.new()
	add_child(rack)
	rack.position=anchor+Vector3.UP*1.54
	rack.rotation.y=atan2(inward.x,inward.z)
	art.piece("box",Vector3.ZERO,Vector3(2.62,1.04,.12),"233640",Vector3.ZERO,rack)
	art.piece("box",Vector3(0,-.47,.08),Vector3(2.50,.045,.04),"+87dbc6",Vector3.ZERO,rack)
	var length:float={"sidearm":.6,"smg":1.1,"gun":1.55,"shotgun":1.75,"marksman":1.95,"heavy":1.3,"lmg":1.8}[kind]
	art.piece("box",Vector3(-length*.13,.08,.13),Vector3(length*.62,.18,.12),"bcd7c9",Vector3.ZERO,rack)
	art.piece("pipe",Vector3(length*.32,.13,.14),Vector3(.10,length*.49,.10),"d6dfcd",Vector3(0,0,PI/2),rack)
	art.piece("box",Vector3(-length*.27,-.09,.14),Vector3(.14,.28,.12),"988b70",Vector3(0,0,-.27),rack)
	if kind!="sidearm":
		art.piece("box",Vector3(-length*.49,.015,.13),Vector3(.27,.21,.13),"8e9b94",Vector3(0,0,.14),rack)
		art.piece("box",Vector3(0,-.07,.14),Vector3(.18,.25,.13),"afaf92",Vector3.ZERO,rack)
	if kind=="marksman":art.piece("box",Vector3(-.12,.24,.15),Vector3(.38,.12,.1),"88a7a0",Vector3.ZERO,rack)
	match kind:
		"lmg": art.piece("box",Vector3(.03,-.15,.15),Vector3(.45,.36,.15),"858e75",Vector3.ZERO,rack)
		"shotgun": art.piece("pipe",Vector3(.40,.04,.17),Vector3(.13,.55,.13),"ab8059",Vector3(0,0,PI/2),rack)
		"smg": art.piece("taper",Vector3(.04,-.15,.16),Vector3(.15,.33,.12),"586e6f",Vector3(0,0,.26),rack)
		"heavy":
			for i in 3: art.piece("pipe",Vector3(.19+i*.13,.14,.15),Vector3(.20,.07,.20),"+7bc6bb",Vector3(0,0,PI/2),rack)
	var title:String=WALL_NAMES[kind]
	var label:=art.signpost("%s   /   %d CR" % [title,WALL_PRICES[kind]],anchor+Vector3.UP*2.38+inward*.15,31,"a4eddf")
	label.visibility_range_end=14
	stations.append({"kind":kind,"price":WALL_PRICES[kind],"title":title,"pos":anchor,"label":label,"rack":true})

func place_equipment() -> void:
	var stock: Dictionary = TOWER_STOCK[level] if tower else OUTPOST_STOCK[level]
	for kind in stock:
		if kind=="cache":
			for index in stock[kind]: stock_room(kind,index)
		else: stock_room(kind,stock[kind])
	lift_pad = shaft_position(route.size()-1)
	if tower:
		var side := 1 if level%2==0 else -1
		var objective := center_of(route[4])+Vector3(3.65*side,0,4.4)
		station("objective",JOBS[level].to_upper(),0,objective,"+ffcc68",true)
		if level<5: station("up","LIFT TO "+FLOORS[level+1].to_upper(),0,lift_pad,"+94cfee")
		else:
			landing_pad=center_of(route.back())+Vector3.RIGHT*2.0
			var pad_label:=art.signpost("H1   /   AIR RESCUE",landing_pad+Vector3(0,1.2,-5.4),35,"e5ce8a")
			stations.append({"kind":"board","title":"Helicopter boarding","price":0,"pos":landing_pad+Vector3.BACK*2.8,"label":pad_label})
			for i in 48:
				var a:=TAU*i/48
				var next:=TAU*(i+1)/48
				art.beam(landing_pad+Vector3(cos(a)*4.8,.075,sin(a)*4.8),landing_pad+Vector3(cos(next)*4.8,.075,sin(next)*4.8),.18,"e5d8ac")
				if i%4==0:art.piece("oval",landing_pad+Vector3(cos(a)*5.15,.11,sin(a)*5.15),Vector3(.24,.14,.24),"+80dac4")
			for x in [-1.3,1.3]:art.piece("box",landing_pad+Vector3(x,.065,0),Vector3(.51,.04,4.7),"f2ead2")
			art.piece("box",landing_pad+Vector3.UP*.065,Vector3(2.8,.045,.52),"f2ead2")
			build_aircraft()
	else:
		for kind in OUTPOST_STOCK[1]: stock_room(kind,RIDGE_START+int(OUTPOST_STOCK[1][kind]))
		station("power","START GENERATOR",0,center_of(route[3])+Vector3(3.6,0,3.85),"+ffcc68",true)
		station("secret","DECODE RELAY",0,center_of(route[RIDGE_START+6])+Vector3(-3.5,0,3.8),"+d9adf2",true)
		for index in [5,RIDGE_START+4]:
			station("lore" if index==5 else "lore_b","FIELD RECORDER",0,center_of(route[index])+Vector3(-3.5,0,3.8),"+d9adf2",true)
	if tower and level>0: station("down","LIFT / DESCEND",0,shaft_position(0),"+94cfee")
	var racks:Array = [["gun"],["sidearm","smg"],["heavy","shotgun"],["lmg"],["marksman"],["gun","heavy"]][level] if tower else ["sidearm","gun","heavy","smg","shotgun","marksman","lmg"]
	for kind in racks: mount_rack(kind)
	for item in stations:
		if item.kind not in ["up","down"]:continue
		var p:Vector3=item.pos
		build_shaft(p)
		art.piece("box",p+Vector3(0,3.1,0),Vector3(2.7,.19,1.5),"586575")
		for x in [-1.18,1.18]:
			art.piece("pipe",p+Vector3(x,1.5,-.33),Vector3(.14,3,.14),"869395")
			art.piece("box",p+Vector3(x,1.55,-.24),Vector3(.04,2.7,.045),"+84c1bb")

func furnish(c:Vector3,room:String,indoor:bool) -> void:
	var p:=c+Vector3(-2.8,0,-2.65)
	if room in ["Barracks","Infirmary","Ridge gate"]:
		solid(p+Vector3.UP*.48,Vector3(1.12,.94,2.12),"525f5f")
		art.piece("box",p+Vector3.UP,Vector3(1.04,.18,2.05),"81978e")
		art.piece("oval",p+Vector3(0,1.13,-.64),Vector3(.75,.17,.44),"b7b8a4")
	elif room in ["Office levels","Open office","Conference","Boardroom","Sky lounge","Archives","Watch office","Map room"]:
		solid(p+Vector3.UP*.55,Vector3(2.25,1.1,1.13),"6c594e")
		for x in [-.74,.74]:
			art.piece("box",p+Vector3(x,1.38,0),Vector3(.61,.37,.11),"293742")
			art.piece("box",p+Vector3(x,1.4,.062),Vector3(.51,.24,.02),"+66b8c7")
	elif room in ["Workshop","Switchgear","Lift motor","Generator","Boiler room","Signals","Refinery"]:
		for x in [-.68,.68]:
			var tank:=art.piece("pipe",p+Vector3(x,1.32,0),Vector3(.95,2.65,.95),"63777a",Vector3.ZERO,self)
			nav.add_obstacle(tank,Vector3(.95,2.65,.95),tank.position)
			art.piece("oval",p+Vector3(x,2.62,0),Vector3(.94,.34,.94),"8b958c")
			art.piece("pipe",p+Vector3(x,1.68,0),Vector3(.98,.17,.98),"c5915c")
	elif room in ["Shops","Food court","Arcade","Mess hall","Stores","Freight depot"]:
		solid(p+Vector3.UP*.8,Vector3(2.6,1.6,.72),"745447")
		art.piece("box",p+Vector3.UP*2.6,Vector3(2.8,.18,1.32),"b28f63")
		for x in [-1.12,1.12]:art.beam(p+Vector3(x,1.6,0),p+Vector3(x,2.6,0),.08,"9f9a87")
	if indoor:
		for x in [-.20,.20]:art.beam(c+Vector3(x,4.21,-5.8),c+Vector3(x,4.21,5.8),.12,"778681")
	if tower and level<5:
		# Floor numbers and emergency strips identify identical-looking lift landings.
		art.signpost(["G","02","03","04","05"][level],c+Vector3(4.3,2.7,-4.7),57,"b4a484",false)

func build_aircraft() -> void:
	helicopter = Node3D.new()
	add_child(helicopter)
	helicopter.position = landing_pad+Vector3(0,19,-28)
	art.piece("box",Vector3(0,-.66,.19),Vector3(2.35,.24,3.72),"596660",Vector3.ZERO,helicopter)
	art.piece("box",Vector3(0,.99,.20),Vector3(2.38,.23,3.7),"4c5954",Vector3.ZERO,helicopter)
	for side in [-1.,1.]:
		art.piece("box",Vector3(side*1.08,.09,.27),Vector3(.17,1.63,3.43),"515e58",Vector3.ZERO,helicopter)
		art.piece("box",Vector3(side*.95,.09,1.99),Vector3(.08,1.64,.10),"+a4d9ae",Vector3.ZERO,helicopter)
	art.piece("box",Vector3(0,-.81,2.25),Vector3(1.88,.11,1.13),"948a69",Vector3(.20,0,0),helicopter)
	art.piece("oval",Vector3(0,.27,-1.52),Vector3(1.92,1.29,1.92),"28424c",Vector3.ZERO,helicopter)
	art.piece("taper",Vector3(0,1.22,3.1),Vector3(.75,3.7,.69),"55675f",Vector3(PI/2,0,0),helicopter)
	for x in [-.8,.8]: art.piece("pipe",Vector3(x,-1,0),Vector3(.11,3.7,.11),"343d40",Vector3(PI/2,0,0),helicopter)
	rotor=Node3D.new()
	helicopter.add_child(rotor)
	rotor.position.y=1.05
	for a in [0.,PI/2]: art.piece("box",Vector3.ZERO,Vector3(6.8,.06,.18),"3a4347",Vector3(0,a,0),rotor)
	for side in [-1.,1.]:
		art.piece("oval",Vector3(side*1.03,.28,-.38),Vector3(.09,.72,1.58),"203942",Vector3.ZERO,helicopter)
		art.piece("oval",Vector3(side*1.16,.21,.54),Vector3(.14,.15,.15),"+ed766a" if side<0 else "+79e7ac",Vector3.ZERO,helicopter)
		art.piece("pipe",Vector3(side*.75,-.73,-.53),Vector3(.09,.65,.09),"7e8580",Vector3(0,0,side*.4),helicopter)
	art.piece("taper",Vector3(0,1.66,4.6),Vector3(.18,1.65,.84),"58645b",Vector3(-.3,0,0),helicopter)
	art.piece("oval",Vector3(0,-.52,-1.97),Vector3(.52,.32,.26),"+ffdc98",Vector3.ZERO,helicopter)
	helicopter.hide()

func secure_landed_cabin() -> void:
	for side in [-1.,1.]:
		solid(landing_pad+Vector3(side*1.12,1.04,.28),Vector3(.15,1.64,3.40),"515e58")
	solid(landing_pad+Vector3(0,1.0,-1.40),Vector3(2.02,1.7,.24),"364b51")
	nav.rebuild()

func cut_deck(c:Vector3, hole:Vector3, y:float, material:Material) -> void:
	var left:=hole.x-1.43
	var right:=hole.x+1.43
	var front:=hole.z-1.38
	var back:=hole.z+1.38
	for bounds:Vector4 in [Vector4(c.x-6,c.z-6,left,c.z+6),Vector4(right,c.z-6,c.x+6,c.z+6),Vector4(left,c.z-6,right,front),Vector4(left,back,right,c.z+6)]:
		var p:=Vector3((bounds.x+bounds.z)*.5,y,(bounds.y+bounds.w)*.5)
		var size:=Vector3(bounds.z-bounds.x,.24,bounds.w-bounds.y)
		if material:
			art.piece("box",p,size,shade,Vector3.ZERO,self).material_override=material
		else: art.piece("box",p,size,"38434b")

func build_shaft(p:Vector3) -> void:
	var center:=p+Vector3.BACK*1.30
	stairs.append(center)
	art.piece("box",center+Vector3.UP*.34,Vector3(2.75,.65,2.65),"536575")
	for i in 4:
		var h:=.16*(4-i)
		art.piece("box",center+Vector3(0,h*.5,1.45+i*.32),Vector3(2.65,h,.34),"687680")
		art.piece("box",center+Vector3(0,h,1.59+i*.32),Vector3(2.55,.022,.038),"+d0a96d")
	for x in [-1.42,1.42]:
		art.beam(center+Vector3(x,0,-1.30),center+Vector3(x,5.10,-1.30),.14,"a3afab")
		for y in [1.,2.7,4.4]:
			art.beam(center+Vector3(x,y,-1.26),center+Vector3(x,y+.76,.56),.11,"566471")
	art.signpost("L %02d" % (level+1),center+Vector3(0,3.35,-1.3),38,"a4e7db",false)

func stair_height(at:Vector3) -> float:
	for center in stairs:
		var local:=at-center
		if absf(local.x)>1.37 or local.z < -1.3 or local.z>2.57: continue
		if local.z<1.31:return .65
		return .16*clampf(4-floorf((local.z-1.31)/.32),0,4)
	return 0

func build_car(parent:Node3D) -> Node3D:
	var car:=Node3D.new()
	parent.add_child(car)
	art.piece("box",Vector3(0,.31,0),Vector3(2.75,.62,2.65),"536575",Vector3.ZERO,car)
	art.piece("box",Vector3(0,3.12,0),Vector3(2.75,.11,2.65),"364750",Vector3.ZERO,car)
	for x in [-1.30,1.30]:
		art.piece("box",Vector3(x,1.29,0),Vector3(.11,1.4,2.65),"586a73",Vector3.ZERO,car)
		art.piece("pipe",Vector3(x*.94,1.72,0),Vector3(.075,2.51,.075),"bdada1",Vector3(PI/2,0,0),car)
		art.piece("box",Vector3(x,2.0,-1.22),Vector3(.11,2.1,.14),"+87cfbd",Vector3.ZERO,car)
	for i in 5:
		art.piece("box",Vector3(-.98+i*.49,1.79,1.26),Vector3(.038,2.45,.038),"9ea79f",Vector3.ZERO,car)
	art.piece("box",Vector3(0,2.96,0),Vector3(.24,.06,1.28),"+f5e3bb",Vector3.ZERO,car)
	return car

func build_ridge() -> void:
	var previous:=Vector3.ZERO
	for idx in [0,3,8,12,17,21,24]:
		var c:=center_of(route[idx])+Vector3(2.6,0,-5.35)
		var top: Vector3=c+Vector3.UP*(8.8+idx%3)
		for x in [-.67,.67]:
			art.beam(c+Vector3(x,4.5,0),top,.13,"718487")
		for rung in 5:
			art.beam(c+Vector3(-.5+rung*.07,4.8+rung*.72,0),c+Vector3(.5-rung*.07,5.4+rung*.72,0),.075,"81908f")
		art.piece("oval",top-Vector3.UP*.90,Vector3(1.62,.25,1.28),"afb9ba",Vector3(.55,0,.2))
		beacons.append(art.piece("oval",top,Vector3(.24,.30,.24),"+eb6958",Vector3.ZERO,self))
		if idx>0:
			var mid:Vector3=(top+previous)*.5-Vector3.UP*1.1
			art.beam(previous,mid,.061,"36434a")
			art.beam(mid,top,.061,"36434a")
		previous=top
		var lamp:=art.piece("box",c+Vector3(-2.6,3.42,1.8),Vector3(3.3,.15,.15),"+96ecd8",Vector3.ZERO,self)
		lamp.hide()
		powered_lamps.append(lamp)
	for i in 7:
		var far:=Vector3(-86+i*29,6+i%3*4,-61-i%2*15)
		art.beam(far-Vector3.UP*9,far,.38,"74828b")
		beacons.append(art.piece("oval",far,Vector3(.43,.39,.43),"+f36f5e",Vector3.ZERO,self))
	var yard:=center_of(route[4])
	solid(yard+Vector3(-2.6,.56,2.4),Vector3(2.45,1.12,.58),"677574")
	art.signpost("MOTOR POOL   /   MUSTER POINT",yard+Vector3(0,3.3,-4),26,"eacf9f")
	var gen:=center_of(route[3])+Vector3(-3.7,0,2.9)
	solid(gen+Vector3.UP*.76,Vector3(2.20,1.52,1.24),"63756e")
	for i in 6:art.piece("box",gen+Vector3(-.8+i*.30,.83,.64),Vector3(.11,.80,.06),"283a3e")
	var strip:=art.piece("box",gen+Vector3(0,1.48,.65),Vector3(1.93,.08,.07),"+8cf5c7",Vector3.ZERO,self)
	strip.hide()
	powered_lamps.append(strip)

func build_weather() -> void:
	weather=CPUParticles3D.new()
	weather.emitting=false
	weather.amount=96 if tower else 70
	weather.lifetime=1.25 if tower else 2.8
	weather.local_coords=false
	weather.emission_shape=CPUParticles3D.EMISSION_SHAPE_BOX
	weather.emission_box_extents=Vector3(8,.5,8)
	weather.direction=Vector3(.40,-1,.13)
	weather.spread=7
	weather.initial_velocity_min=9 if tower else 1.7
	weather.initial_velocity_max=13 if tower else 2.4
	weather.gravity=Vector3(1,-2,.2)
	var flake:=BoxMesh.new()
	flake.size=Vector3(.021,.33,.021) if tower else Vector3(.037,.035,.037)
	flake.material=art.surface("abbec7" if tower else "d2dedb")
	weather.mesh=flake
	add_child(weather)
	if tower:
		storm_flash=art.piece("box",Vector3(2,35,-86),Vector3(.50,26,.50),"+d9e7ec",Vector3(.22,0,-.3),self)
		storm_flash.hide()

func update_weather(delta:float, at:Vector3, live:bool) -> void:
	if not weather:return
	weather_time+=delta
	weather.position=at+Vector3(-1,4,-.4)
	weather.emitting=outdoor_cells.has(cell_at(at)) and DisplayServer.get_name()!="headless"
	if live!=last_power:
		last_power=live
		for lamp in powered_lamps:lamp.visible=live
	for i in beacons.size(): beacons[i].visible=fmod(weather_time+i*.47,2.8)<.7
	if storm_flash:storm_flash.visible=fmod(weather_time,13.0)<.12
	weather_audio-=delta
	if weather_audio<=0 and outdoor_cells.has(cell_at(at)):
		get_parent().sound.cue("thunder" if tower else "wind",-20)
		weather_audio=13.0 if tower else 4.5



