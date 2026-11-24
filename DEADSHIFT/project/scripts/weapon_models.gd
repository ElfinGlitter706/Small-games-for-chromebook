extends RefCounted

const COLORS := {"sidearm":"b4b9b6","gun":"867353","heavy":"c27449","smg":"548082","shotgun":"9b6449","lmg":"81865d","marksman":"697e91","relic":"87d4c2"}
const WIDTH := {"sidearm":.023,"gun":.028,"heavy":.039,"smg":.025,"shotgun":.037,"lmg":.032,"marksman":.020,"relic":.033}
const SIGHT_LINE := .21

static func detail(art, root:Node3D, key:String, length:float, parts:Array) -> void:
	var color:String=COLORS[key]
	var w:float=WIDTH[key]
	match key:
		"sidearm":
			art.piece("box",Vector3(0,.063,-.035),Vector3(.14,.098,.37),color,Vector3.ZERO,root)
		"gun","marksman":
			art.piece("taper",Vector3(0,-.034,.18),Vector3(.13,.29,.19),color,Vector3(1.38,0,0),root)
			for x in [-.071,.071]:
				art.piece("box",Vector3(x,.019,-length*.39),Vector3(.025,.095,length*.48),color,Vector3.ZERO,root)
			if key=="marksman":
				for x in [-.075,.075]:art.piece("pipe",Vector3(x,-.054,-.41),Vector3(.024,.37,.024),"889297",Vector3(1.52,0,0),root)
		"smg":
			for x in [-.104,.104]:
				art.piece("pipe",Vector3(x,-.03,.16),Vector3(.025,.32,.025),color,Vector3(PI/2,0,0),root)
			art.piece("box",Vector3(0,-.05,.30),Vector3(.22,.11,.035),color,Vector3.ZERO,root)
		"shotgun":
			for i in 7:art.piece("pipe",Vector3(0,-.035,-.23-i*.034),Vector3(.145,.031,.145),color,Vector3(PI/2,0,0),root)
		"heavy","relic":
			for i in 5:
				var rad:=.18-.012*i
				art.piece("pipe",Vector3(0,.03,-.09-i*.075),Vector3(rad,.043,rad),color if i%2==0 else ("+66cfd1" if key=="relic" else "443e39"),Vector3(PI/2,0,0),root)
		"lmg":
			for i in 5:art.piece("pipe",Vector3(.105+i*.024,-.061,-.045),Vector3(.024,.12,.024),"c3a776",Vector3(PI/2,0,0),root)
			art.piece("box",Vector3(-.12,.05,-.14),Vector3(.055,.09,.36),color,Vector3.ZERO,root)
	# Both rear blades frame an empty channel. The front bead ends below the aim ray.
	for side in [-1,1]:
		art.piece("box",Vector3(side*w,SIGHT_LINE-.026,.10),Vector3(.012,.050,.028),color,Vector3(0,0,side*.08),root)
		art.piece("box",Vector3(side*w,SIGHT_LINE-.007,.117),Vector3(.008,.008,.004),"+b8d9c7",Vector3.ZERO,root)
	art.piece("box",Vector3(0,SIGHT_LINE-.061,-length*.74),Vector3(.014,.109,.023),"303b40",Vector3.ZERO,root)
	art.piece("oval",Vector3(0,SIGHT_LINE-.009,-length*.74),Vector3(.009,.009,.012),"+e3ae6c",Vector3.ZERO,root)
	for i in parts:
		match i:
			0:art.piece("box",Vector3(.016,-.21,.015),Vector3(.155,.13,.17),color,Vector3.ZERO,root)
			1:art.piece("box",Vector3(.085,-.15,.012),Vector3(.047,.11,.14),"a49171",Vector3.ZERO,root)
			2:art.piece("taper",Vector3(0,-.105,-.25),Vector3(.071,.17,.078),"38484a",Vector3(-.2,0,0),root)
			3:art.piece("pipe",Vector3(.087,.026,-.15),Vector3(.045,.23,.045),"+7bbaa7",Vector3(PI/2,0,0),root)
			4:art.piece("box",Vector3(-.094,.044,-.04),Vector3(.034,.064,.17),"c19461",Vector3.ZERO,root)
			5:art.piece("oval",Vector3(w+.012,.17,.09),Vector3(.034,.041,.045),"+94aabb",Vector3.ZERO,root)
