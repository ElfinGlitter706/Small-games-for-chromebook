extends RefCounted
## Original modular low-poly scenery. Static pieces share geometry and draw calls.

var shapes := {}
var materials := {}
var batches := {}
var root: Node3D

func _init(parent: Node3D) -> void:
	root = parent
	shapes["box"] = BoxMesh.new()
	var ball := SphereMesh.new()
	ball.radial_segments = 12
	ball.rings = 6
	shapes["oval"] = ball
	for key in ["pipe", "cone", "taper"]:
		var tube := CylinderMesh.new()
		tube.radial_segments = 12 if key != "cone" else 7
		tube.rings = 1
		tube.height = 1
		tube.top_radius = {"pipe":0.5, "cone":0.0, "taper":0.31}[key]
		shapes[key] = tube

func surface(ink: String) -> StandardMaterial3D:
	if not materials.has(ink):
		var mat := StandardMaterial3D.new()
		var col := Color(ink.trim_prefix("+"))
		mat.albedo_color = col
		mat.roughness = 0.78
		if ink.begins_with("+"):
			mat.emission_enabled = true
			mat.emission = col
			mat.emission_energy_multiplier = 1.5
		materials[ink] = mat
	return materials[ink]

func piece(shape: String, pos: Vector3, size: Vector3, ink: String, rot := Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	var transform := Transform3D(Basis.from_euler(rot).scaled_local(size), pos)
	if parent == null:
		var key := shape + "/" + ink
		if not batches.has(key): batches[key] = []
		batches[key].append(transform)
		return null
	var item := MeshInstance3D.new()
	item.mesh = shapes[shape]
	item.material_override = surface(ink)
	item.transform = transform
	parent.add_child(item)
	return item

func beam(a: Vector3, b: Vector3, width: float, ink: String) -> void:
	var offset := b - a
	var rotation := Quaternion(Vector3.UP, offset.normalized()).get_euler()
	piece("pipe", (a+b)/2, Vector3(width, offset.length(), width), ink, rotation)

func finish() -> void:
	for key: String in batches:
		var parts := key.split("/")
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = shapes[parts[0]]
		mm.instance_count = batches[key].size()
		for i in mm.instance_count: mm.set_instance_transform(i, batches[key][i])
		var display := MultiMeshInstance3D.new()
		display.multimesh = mm
		display.material_override = surface(parts[1])
		root.add_child(display)
	batches.clear()

func signpost(words: String, pos: Vector3, size: int, ink: String, billboard := true) -> Label3D:
	var label := Label3D.new()
	label.text = words
	label.font_size = size
	label.pixel_size = 0.009
	label.outline_size = 8
	label.modulate = Color(ink)
	label.position = pos
	if billboard: label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	root.add_child(label)
	return label
