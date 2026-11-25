extends Node3D

const Art = preload("res://scripts/field_art.gd")
var nav = preload("res://scripts/navigation.gd").new()
var art: Art
var tower := false
var gates: Array[Dictionary] = []
var stations: Array[Dictionary] = []
var lanes: Array[Dictionary] = []
var shade := "273e42"
var glow := "+ffb66a"
var city_elevation:=0.

func build(is_tower: bool) -> void:
	tower = is_tower
	art = Art.new(self)
	var depth := 8 if tower else 12
	nav.main_depth = depth - .3
	if tower:
		shade = "34405b"
		glow = "+79f3e1"
	lighting()
	var flooring := ShaderMaterial.new()
	flooring.shader = preload("res://scripts/deck.gdshader")
	flooring.set_shader_parameter("steel", Color("333e50") if tower else Color("414c46"))
	flooring.set_shader_parameter("rust", Color("657381") if tower else Color("8b6952"))
	var deck := art.piece("box",Vector3(0,-.22,0),Vector3(24,.42,depth*2),shade,Vector3.ZERO,self)
	deck.material_override = flooring
	for side: float in [-1.,1.]:
		var z := side * depth
		solid(Vector3(0,.65,z),Vector3(24,1.3,.4),shade)
		art.piece("pipe",Vector3(0,1.37,z),Vector3(.15,24,.15),"738187",Vector3(0,0,PI/2))
		for k in range(-10,11,2):
			art.piece("box",Vector3(k,.73,z-side*.23),Vector3(.06,1.1,.07),"8a958d")
		var wing := art.piece("box",Vector3(18*side,-.22,0),Vector3(12,.42,12),shade,Vector3.ZERO,self)
		wing.material_override = flooring
		for edge: float in [-1.,1.]:
			solid(Vector3(12*side,1.6,edge*(depth+2)/2),Vector3(.45,3.2,depth-2),shade)
			solid(Vector3(18*side,.64,edge*6),Vector3(12,1.28,.45),shade)
		solid(Vector3(24*side,1.05,0),Vector3(.4,2.1,12),shade)
		var gate := solid(Vector3(12*side,1.24,0),Vector3(.44,2.48,4),"93614a",true)
		for j in 5:
			art.piece("box",Vector3(0,j*.16-.32,0),Vector3(1.06,.035,.92),"e5ae62",Vector3.ZERO,gate)
		gates.append({"kind":"gate","title":"OPEN "+("WEST" if side<0 else "EAST")+" ACCESS","pos":Vector3(12*side,0,0),"price":300,"mesh":gate,"open":false})
		for corner in [-1,1]:
			art.piece("pipe",Vector3(12*side,1.55,corner*2.12),Vector3(.3,3.1,.3),"55585e")
		art.piece("box",Vector3(12*side,3.15,0),Vector3(.44,.22,4.6),glow)
		for j in range(-10,11,2):
			art.piece("box",Vector3(j,.012,side*(depth-1.7)),Vector3(.9,.014,.10),"ab9270")
	for x in [-18,-12,-6,0,6,12,18]:
		art.piece("box",Vector3(x,.012,0),Vector3(.045,.01,10),"283439")
	if tower:
		for x in [-5,5]:
			solid(Vector3(x,1.15,0),Vector3(2.5,2.3,3),"46546a")
			art.piece("taper",Vector3(x,2.53,0),Vector3(2.35,.5,2.35),"738394")
			for slat in 6: art.piece("box",Vector3(x,.5+slat*.25,1.53),Vector3(2,.09,.05),"1d2836")
			art.piece("pipe",Vector3(x,2.79,0),Vector3(1.58,.05,1.58),"273a46")
			for blade in 6:
				var a := TAU*blade/6
				art.piece("oval",Vector3(x+cos(a)*.41,2.84,sin(a)*.41),Vector3(.60,.045,.23),"84918d",Vector3(0,-a+.25,0))
			for s in [-1,1]: art.beam(Vector3(x+s*1.03,.3,1.56),Vector3(x+s*1.03,2.12,1.56),.085,"8a9295")
	else:
		for p in [Vector3(-4,0,-3),Vector3(4,0,2)]:
			solid(p+Vector3.UP*.76,Vector3(2.05,1.5,1.9),"545a55")
			for x in [-.72,.72]: art.piece("box",p+Vector3(x,.78,0),Vector3(.12,1.57,1.95),"b18b5c")
		for x in [-8,8]:
			for z in [-8,8]:
				var pole := art.piece("pipe",Vector3(x,2,z),Vector3(.7,4,.7),"59656a",Vector3.ZERO,self)
				nav.add_obstacle(pole,Vector3(.7,4,.7),pole.position)
				art.piece("oval",Vector3(x,4,z),Vector3(.78,.4,.78),glow)
	for x in [-7.,7.]:
		hatch(Vector3(x,0,-depth+1.6),-1)
	hatch(Vector3(-2,0,depth-1.65),-1)
	hatch(Vector3(-20,0,3.5),0)
	hatch(Vector3(20,0,-3.5),1)
	station("gun","FEN CARBINE",350,Vector3(-5,0,-depth+.85),"+69e8cb")
	station("heavy","ARC DRIVER",650,Vector3(-18,0,-4.8),"+ffaf61")
	station("vital","SECOND PULSE",450,Vector3(18,0,4.8),"+ff6c79")
	station("quick","QUICK CURRENT",400,Vector3(-21,0,-4.8),"+87bfff")
	if tower: station("exit","ROOF BEACON",0,Vector3(21,0,4.8),"+f3e28e")
	for side in [-1,1]:
		art.signpost("WEST   /   FOUNDRY" if side<0 else "EAST   /   INFIRMARY",Vector3(12*side,3.58,0),31,"ffcf94")
		for j in 6:
			art.piece("box",Vector3(12*side,1.5,3+j*.65),Vector3(.52,2.8,.052),"657273")
	for i in 8:
		var y := 3.35-1.4*sin(PI*i/8)
		var next_y := 3.35-1.4*sin(PI*(i+1)/8)
		art.beam(Vector3(-11+i*2.75,y,-depth-.6),Vector3(-11+(i+1)*2.75,next_y,-depth-.6),.06,"29363c")
	for x in [-11,11]:
		art.piece("pipe",Vector3(x,1.85,-depth-.6),Vector3(.17,3.7,.17),"465452")
		art.piece("oval",Vector3(x,3.75,-depth-.6),Vector3(.29,.23,.29),glow)
	vista()
	art.finish()
	nav.rebuild()

func solid(pos: Vector3, size: Vector3, ink: String, movable:=false) -> MeshInstance3D:
	var mesh:MeshInstance3D
	if OS.has_feature("web") and art.building and not movable:
		art.piece("box",pos,size,ink)
		mesh=MeshInstance3D.new()
		add_child(mesh)
	else: mesh=art.piece("box",pos,size,ink,Vector3.ZERO,self)
	nav.add_obstacle(mesh,size,pos)
	return mesh

func hatch(pos: Vector3, gate_id: int) -> void:
	var latch := art.piece("box",pos+Vector3.UP*.095,Vector3(1.94,.07,.21),"be8e54",Vector3.ZERO,self)
	lanes.append({"kind":"seal","title":"BRACE HATCH","price":0,"pos":pos,"gate":gate_id,"brace":latch,"armed":true,"occupied":false})
	art.piece("pipe",pos+Vector3.UP*.023,Vector3(2.7,.04,2.7),"79817a")
	art.piece("pipe",pos+Vector3.UP*.049,Vector3(2.36,.04,2.36),"121d23")
	for k in 8:
		var a := TAU*k/8
		art.piece("oval",pos+Vector3(cos(a)*1.24,.083,sin(a)*1.24),Vector3(.12,.07,.12),glow)

func station(kind: String, title: String, price: int, pos: Vector3, accent: String, face_north := false) -> void:
	var face := -1.0 if face_north else 1.0
	stations.append({"kind":kind,"title":title,"price":price,"pos":pos})
	solid(pos+Vector3.UP,Vector3(1.95,2,.65),"26313c")
	art.piece("box",pos+Vector3(0,1.28,.37*face),Vector3(1.76,1.09,.09),"101f28")
	art.piece("box",pos+Vector3(0,1.94,.4*face),Vector3(1.75,.065,.08),accent)
	if kind in ["gun","heavy"]:
		art.piece("taper",pos+Vector3(.10,1.34,.51*face),Vector3(.18,1.12,.18),accent,Vector3(0,0,PI/2))
		art.piece("box",pos+Vector3(-.32,1.19,.51*face),Vector3(.17,.34,.16),"cdd8cc",Vector3(0,0,-.25))
	else:
		art.piece("oval",pos+Vector3(0,1.29,.45*face),Vector3(.63,.79,.22),accent)
	stations.back().label = art.signpost(title,pos+Vector3.UP*2.55,39,accent.trim_prefix("+"))
	stations.back().label.visibility_range_end=16

func lighting() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var mat := ProceduralSkyMaterial.new()
	mat.sky_top_color = Color("162843") if tower else Color("284953")
	mat.sky_horizon_color = Color("776881") if tower else Color("d6b79c")
	mat.sky_curve = .24
	mat.ground_horizon_color = mat.sky_horizon_color
	mat.ground_bottom_color = Color("27333e")
	sky.sky_material = mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("bbcbd9")
	env.ambient_light_energy = .75
	env.fog_enabled = true
	env.fog_density = .0028
	env.fog_light_color = mat.sky_horizon_color
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-32,-45,0)
	sun.light_color = Color("ffdcad")
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 33
	add_child(sun)

func vista() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 712 if tower else 893
	for i in 64:
		var angle := TAU*i/64
		var dist := rng.randf_range(35,80)
		var p := Vector3(cos(angle)*dist,0,sin(angle)*dist)
		# Keep the skyline and forest beyond the ends of the playable route.
		if not nav.rooms.is_empty(): p.x*=1.85
		if tower:
			var h := rng.randf_range(7,30)
			var w := rng.randf_range(3,7)
			art.piece("box",p+Vector3.UP*(h/2-12+city_elevation),Vector3(w,h,w),"454b66" if i%2 else "535971")
			for row in range(1,int(h/2)):
				art.piece("box",p+Vector3.UP*(row*2-12+city_elevation),Vector3(w+.035,.16,w+.035),"+b99a80" if i%3 else "+7eafb8")
		else:
			p *= .73
			if not nav.rooms.is_empty() and absf(p.x-10)<58 and absf(p.z-10)<40: continue
			for j in 3:
				art.piece("cone",p+Vector3.UP*(1.2+j*1.7),Vector3(4.8-j,5.5-j*.5,4.8-j),"253f3a",Vector3(.04,j*1.3,-.04))
	if not tower:
		ridgeline()
		var base := Vector3(4,0,-25)
		for a in 3:
			var v := Vector3(cos(TAU*a/3),0,sin(TAU*a/3))
			art.beam(base+v*2,base+Vector3.UP*15,.22,"936758")
			for j in 4:
				var n := Vector3(cos(TAU*(a+1)/3),0,sin(TAU*(a+1)/3))
				art.beam(base+v*(2-j*.45)+Vector3.UP*(j*3),base+n*(1.55-j*.45)+Vector3.UP*(j*3+3),.1,"936758")
		art.piece("oval",base+Vector3.UP*15,Vector3(.6,.6,.6),"+ff7960")
		art.piece("oval",base+Vector3(0,10,0),Vector3(4.5,.64,4.5),"b0aaa0",Vector3(.98,0,.35))

func ridgeline() -> void:
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	var terrain := FastNoiseLite.new()
	terrain.seed = 793
	terrain.frequency = .036
	for band in 2:
		for i in 92:
			var corners: Array[Vector3] = []
			for index in [i,(i+1)%92]:
				var a: float = TAU*index/92
				var v := Vector3(cos(a),0,sin(a))
				var height := 12+band*9+absf(terrain.get_noise_2d(v.x*113+band*32,v.z*113))*25
				corners.append(v*(60+band*31)+Vector3.UP*height)
				corners.append(v*(39+band*30)+Vector3.UP*(height*.24-6))
			for idx in [0,1,2,2,1,3]:
				mesh.set_smooth_group(-1)
				mesh.set_color(Color("647d80") if band==0 else Color("98aba6"))
				mesh.add_vertex(corners[idx])
	mesh.generate_normals()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var ridges := MeshInstance3D.new()
	if not nav.rooms.is_empty(): ridges.scale=Vector3(2.3,1,1.9)
	ridges.mesh = mesh.commit()
	ridges.material_override = mat
	add_child(ridges)
