extends Control

var g
var readout:=Label.new()
var times:=PackedFloat32Array()
var elapsed:=0.
var frames:=0
var room_samples:={}
var room:=""
var clock:=0.
var enemy_us:=0
var enemy_ticks:=0
var ai_ms:=0.

func setup(game) -> void:
	g=game
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	position=Vector2(891,20)
	size=Vector2(368,188)
	readout.position=Vector2(12,8)
	readout.add_theme_font_size_override("font_size",15)
	add_child(readout)
	hide()

func _process(dt:float) -> void:
	if not g or g.state!="play":return
	elapsed+=dt
	frames+=1
	clock+=dt
	times.append(dt*1000.)
	if times.size()>120:times.remove_at(0)
	if clock<.33:return
	room=g.sector.room_names.get(g.sector.cell_at(g.player.position),"Landing")
	var fps:=Engine.get_frames_per_second()
	var entry:Vector2=room_samples.get(room,Vector2.ZERO)
	room_samples[room]=entry+Vector2(fps,1)
	ai_ms=enemy_us/maxf(1.,enemy_ticks)/1000.
	enemy_us=0
	enemy_ticks=0
	clock=0
	if visible:
		var longest:=.001
		for sample in times:longest=maxf(longest,sample)
		readout.text="%d FPS   ·   avg %.0f   ·   recent low %.0f\n%s   /   %s\n%d active / %d cap   ·   %d queued\n%s   ·   3D %.0f%%   ·   %d drawn objects\nEnemy update %.2f ms   ·   frame %.1f ms" % [fps,frames/maxf(.01,elapsed),1000./longest,g.Sector.FLOORS[g.level] if g.tower else "Outpost",room,g.enemies.size(),g.options.active_cap,g.queued,["Auto","Low","Medium","High","Ultra"][g.options.pref("Quality",0)],g.get_viewport().scaling_3d_scale*100,Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),ai_ms,times[-1]]
		if fps>0 and fps<40:
			readout.text+="\n"+("Enemy updates are costly" if ai_ms>9.0 else "Slow frames · check 3D resolution")
		queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("101b23ec"))
	if times.size()<2:return
	var pts:=PackedVector2Array()
	for i in times.size():pts.append(Vector2(12+i*343./119.,177-minf(50,times[i])*.72))
	draw_polyline(pts,Color("8de5ce"),1.5)

func summary() -> Dictionary:
	var worst:=""
	var lowest:=INF
	for key in room_samples:
		var entry:Vector2=room_samples[key]
		if entry.x/entry.y<lowest:
			lowest=entry.x/entry.y
			worst=key
	return {"fps":roundi(frames/maxf(.001,elapsed)),"room":worst,"elapsed":elapsed,"frames":frames,"rooms":room_samples.duplicate()}

func restore(stats:Dictionary) -> void:
	elapsed=stats.get("elapsed",0.)
	frames=stats.get("frames",0)
	room_samples=stats.get("rooms",{}).duplicate()
