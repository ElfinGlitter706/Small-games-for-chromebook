extends Node3D

var mode := "opening"
var age := 0.0
var hp := 1
var lane := 0
var gait := 0.0
var route := PackedVector2Array()
var repath := 0.0
var windup := 0.0
var torso := Node3D.new()
var limbs: Array[Node3D] = []
var entry := Vector3.ZERO
var landing := Vector3.ZERO
var entry_duration := 1.45
var stagger := 0.0
var injury := "torso"
var fall_side := 1.0
var plates := {}
var plate_hp := {}
var head_pivot := Node3D.new()

func armor(art) -> void:
	for zone in ["head","torso"]:
		var head: bool = zone=="head"
		var p := Vector3(0,1.99,-.12) if head else Vector3(0,1.31,-.025)
		var s := Vector3(.52,.34,.49) if head else Vector3(.78,.55,.55)
		plates[zone] = art.piece("oval" if head else "taper",p,s,"718291",Vector3.ZERO,torso)
		if head: plates[zone].reparent(head_pivot,true)
		plate_hp[zone] = 3 if head else 4

func strike(zone: String, power: int, melee: bool) -> int:
	injury = zone
	fall_side = -1.0 if sin(gait)<0 else 1.0
	stagger = .43 if zone=="leg" or melee else (.24 if zone=="head" else .13)
	windup = 0
	if plate_hp.get(zone,0)>0:
		plate_hp[zone] -= power
		if plate_hp[zone]<=0: plates[zone].hide()
		return maxi(1,ceili(power*.55))
	return power

func assemble(art, variant: int) -> void:
	add_child(torso)
	head_pivot.position = Vector3(0,1.57,0)
	torso.add_child(head_pivot)
	var coat: String = ["324a4a","493c47","394457"][variant % 3]
	var skin := "a4aa88"
	art.piece("oval",Vector3(0,1.27,0),Vector3(.69,.82,.43),coat,Vector3(-.2,0,.06),torso)
	art.piece("taper",Vector3(0,.92,0),Vector3(.53,.36,.37),"352e37",Vector3.ZERO,torso)
	art.piece("oval",Vector3(.045,1.83,-.13),Vector3(.40,.49,.35),skin,Vector3(.16,0,.14),torso)
	art.piece("oval",Vector3(.03,1.94,-.09),Vector3(.42,.28,.37),"404242",Vector3.ZERO,torso)
	art.piece("oval",Vector3(.03,1.70,-.21),Vector3(.28,.16,.2),"656853",Vector3.ZERO,torso)
	art.piece("oval",Vector3(.03,1.75,-.269),Vector3(.23,.055,.045),"372e35",Vector3(0,0,.16),torso)
	art.piece("oval",Vector3(.025,1.81,-.291),Vector3(.069,.094,.08),"858777",Vector3.ZERO,torso)
	art.piece("oval",Vector3(-.115,1.87,-.244),Vector3(.15,.062,.09),"504a42",Vector3(0,0,.27),torso)
	art.piece("box",Vector3(-.04,1.28,-.208),Vector3(.10,.70,.036),"8b745c",Vector3(-.16,0,-.52),torso)
	art.piece("box",Vector3(.135,1.35,-.209),Vector3(.14,.075,.045),"+b19e66",Vector3.ZERO,torso)
	art.piece("oval",Vector3(-.25,1.52,0),Vector3(.27,.23,.46),"556364",Vector3(0,0,-.23),torso)
	if variant%3==1:
		art.piece("oval",Vector3(.035,2.01,-.10),Vector3(.48,.23,.43),"586975",Vector3(.12,0,.09),torso)
	for side: float in [-1.0,1.0]:
		art.piece("oval",Vector3(.04+side*.096,1.84,-.29),Vector3(.085,.042,.06),"+ff914d",Vector3.ZERO,torso)
		var arm := Node3D.new()
		arm.position = Vector3(side*.34,1.52,0)
		torso.add_child(arm)
		limbs.append(arm)
		art.piece("oval",Vector3(0,-.20,0),Vector3(.25,.47,.23),coat,Vector3.ZERO,arm)
		art.piece("taper",Vector3(0,-.52,-.09),Vector3(.16,.36,.17),skin,Vector3(.42,0,0),arm)
		art.piece("oval",Vector3(0,-.69,-.16),Vector3(.17,.22,.12),skin,Vector3.ZERO,arm)
		var leg := Node3D.new()
		leg.position = Vector3(side*.16,.91,0)
		torso.add_child(leg)
		limbs.append(leg)
		art.piece("taper",Vector3(0,-.35,0),Vector3(.24,.71,.25),"343942",Vector3.ZERO,leg)
		art.piece("oval",Vector3(0,-.74,-.08),Vector3(.25,.24,.4),"282b32",Vector3.ZERO,leg)

	# Move face pieces together around the neck.
	for part in torso.get_children():
		if part is MeshInstance3D and part.position.y>1.60: part.reparent(head_pivot,true)

func animate(delta: float, walking: bool) -> void:
	torso.rotation.z=move_toward(torso.rotation.z,0,delta*1.4)
	gait += delta * 7.4
	var stride := sin(gait) * .49 if walking else .05
	limbs[0].rotation.x = .53 + stride + windup
	limbs[2].rotation.x = .78 - stride + windup
	limbs[1].rotation.x = -stride
	limbs[3].rotation.x = stride
	var weight := minf(1,stagger*4.0)
	if mode=="hunt":
		torso.rotation.x = -weight*(.58 if injury=="leg" else -.24)
		torso.rotation.z = fall_side*weight*(.24 if injury=="torso" else .10)
		head_pivot.rotation.x = -weight*.68 if injury=="head" else 0.0
		if injury=="leg": limbs[1].rotation.x -= .95*weight
		stagger = maxf(0,stagger-delta)
	torso.position.y = absf(stride)*.075 - (.34*weight if injury=="leg" else 0.0)

func transition(delta: float) -> void:
	age += delta
	if mode == "opening":
		var u := clampf(age/entry_duration,0,1)
		position = entry.lerp(landing, smoothstep(0,1,u))
		if entry.y>0: position.y+=sin(PI*u)*.57
		torso.rotation.x = -.85*(1-u)
		animate(delta,true)
		if u >= 1: mode = "hunt"
	elif mode == "dying":
		var u := clampf(age/.85,0,1)
		var collapse := smoothstep(0,1,u)
		torso.rotation.x = (1.43 if injury!="leg" else -1.38)*collapse
		torso.rotation.z = fall_side*.42*collapse
		head_pivot.rotation.z = fall_side*.38*collapse
		for i in limbs.size():
			limbs[i].rotation.z = fall_side*(.65 if i%2==0 else -.29)*sin(u*PI*.68+i*.35)*collapse
			limbs[i].rotation.x = lerpf(limbs[i].rotation.x,(-.7 if i==1 else .48)*collapse,minf(1,delta*9))
		torso.position.y = .12*sin(PI*u) - maxf(age-1.05,0)*2.1
		if age >= 1.7: queue_free()
