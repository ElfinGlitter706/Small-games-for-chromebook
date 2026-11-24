extends RefCounted

var obstacles: Array[Dictionary] = []
var grid := AStarGrid2D.new()
var main_depth := 11.7
var rooms := {}

func add_obstacle(mesh: MeshInstance3D, size: Vector3, location: Vector3) -> void:
	obstacles.append({"mesh": mesh, "bounds": AABB(location - size / 2, size)})

func clear_at(p: Vector3, radius: float = 0.4) -> bool:
	var in_main := absf(p.x) < 11.7 - radius and absf(p.z) < main_depth - radius
	var in_wing := absf(p.x) < 23.7 - radius and absf(p.z) < 5.7 - radius
	if not rooms.is_empty():
		if not rooms.has(Vector2i(floori((p.x+6)/12),floori((p.z+6)/12))): return false
	elif not in_main and not in_wing: return false
	for obstacle in obstacles:
		if not is_instance_valid(obstacle.mesh) or not obstacle.mesh.visible: continue
		var box: AABB = obstacle.bounds
		if p.x > box.position.x - radius and p.x < box.end.x + radius and p.z > box.position.z - radius and p.z < box.end.z + radius:
			return false
	return true

func move(from: Vector3, movement: Vector3) -> Vector3:
	var result := from
	var steps := maxi(1, ceili(movement.length() / 0.15))
	var step := movement / steps
	for i in steps:
		var candidate := result + Vector3(step.x, 0, 0)
		if clear_at(candidate): result = candidate
		candidate = result + Vector3(0, 0, step.z)
		if clear_at(candidate): result = candidate
	return result

func blocked_ray(from: Vector3, to: Vector3) -> bool:
	for obstacle in obstacles:
		if not is_instance_valid(obstacle.mesh) or not obstacle.mesh.visible: continue
		var bounds: AABB = obstacle.bounds
		if bounds.intersects_segment(from, to) != null: return true
	return false

func rebuild() -> void:
	var region := Rect2i(-48, -36, 97, 73)
	if not rooms.is_empty():
		var first: Vector2i = rooms.keys()[0]
		var bounds := Rect2i(first,Vector2i.ONE)
		for cell: Vector2i in rooms:
			bounds=bounds.merge(Rect2i(cell,Vector2i.ONE))
		region=Rect2i(bounds.position*24-Vector2i(12,12),bounds.size*24)
	grid.region = region
	grid.cell_size = Vector2(0.5, 0.5)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	if not rooms.is_empty():
		grid.fill_solid_region(region,true)
		for cell: Vector2i in rooms:
			grid.fill_solid_region(Rect2i(cell*24-Vector2i(12,12),Vector2i(24,24)),false)
		for obstacle in obstacles:
			if not obstacle.mesh.visible: continue
			var bounds: AABB=obstacle.bounds.grow(.48)
			for x in range(ceili(bounds.position.x*2),floori(bounds.end.x*2)+1):
				for z in range(ceili(bounds.position.z*2),floori(bounds.end.z*2)+1):
					if grid.is_in_boundsv(Vector2i(x,z)): grid.set_point_solid(Vector2i(x,z))
		return
	for x in range(-48, 49):
		for z in range(-36, 37):
			grid.set_point_solid(Vector2i(x, z), not clear_at(Vector3(x * 0.5, 0, z * 0.5), 0.48))

func path(from: Vector3, to: Vector3) -> PackedVector2Array:
	var start := nearest_cell(from)
	var finish := nearest_cell(to)
	if not grid.is_in_boundsv(start) or not grid.is_in_boundsv(finish): return PackedVector2Array()
	if grid.is_point_solid(start) or grid.is_point_solid(finish): return PackedVector2Array()
	return grid.get_point_path(start, finish)

func nearest_cell(point: Vector3) -> Vector2i:
	var cell := Vector2i(roundi(point.x * 2), roundi(point.z * 2))
	var best := Vector2i(-999, -999)
	var distance := INF
	for x in range(cell.x - 2, cell.x + 3):
		for z in range(cell.y - 2, cell.y + 3):
			var candidate := Vector2i(x, z)
			if not grid.is_in_boundsv(candidate) or grid.is_point_solid(candidate): continue
			var gap := Vector2(point.x - x * 0.5, point.z - z * 0.5).length_squared()
			if gap < distance:
				distance = gap
				best = candidate
	return best
