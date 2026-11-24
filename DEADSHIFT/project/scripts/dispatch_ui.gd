extends CanvasLayer

signal selected(tower: bool)
signal deployed
signal command(action: String)
var scope: ColorRect
var intro_card: Label
var card: Label
var subtitle: Label
var contract: Label
var loading := Control.new()
var loading_label: Label
var busy := false
var menu := Control.new()
var overlay := Control.new()
var play := Control.new()
var map_title: Label
var description: Label
var deploy_button: Button
var location: Label
var wave: Label
var vitals: Label
var ammo: Label
var prompt: Label
var banner: Label
var marker: Label
var end_title: Label
var end_detail: Label
var resume: Button
var objective: Label
var perk_line: Label
var damage: ColorRect
var transit: ColorRect
var directory := Control.new()
var directory_title: Label
var map_cells := {}
var map_doors: Array[ColorRect] = []
var last_floor_key:=""
var dots: Array = []
var map_buttons: Array[Button] = []
const IVORY := Color("f3ecdc")
const AMBER := Color("ffbb72")
const ICE := Color("8be6d6")

func backing(parent: Control, rect: Rect2, color: Color) -> ColorRect:
	var block := ColorRect.new()
	block.position = rect.position
	block.size = rect.size
	block.color = color
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(block)
	return block

func words(parent: Control, txt: String, x: int, y: int, pts: int, ink := IVORY) -> Label:
	var label := Label.new()
	label.text = txt
	label.position = Vector2(x,y)
	label.add_theme_font_size_override("font_size",pts)
	label.add_theme_color_override("font_color",ink)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func button(parent: Control, txt: String, rect: Rect2, action: Callable) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.position = rect.position
	btn.size = rect.size
	btn.add_theme_font_size_override("font_size",19)
	for state in ["normal","hover","pressed","focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("23383e") if state=="normal" else Color("39615f")
		style.border_color = ICE if state!="normal" else Color("68807c")
		style.set_border_width_all(1)
		btn.add_theme_stylebox_override(state,style)
	btn.pressed.connect(action)
	parent.add_child(btn)
	return btn

func _ready() -> void:
	for screen in [menu,play,overlay]:
		add_child(screen)
		screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backing(menu,Rect2(0,0,486,720),Color("101b23f4"))
	backing(menu,Rect2(483,0,3,720),Color("ddac78"))
	words(menu,"DEADSHIFT",43,41,65)
	words(menu,"SELECT OPERATION",48,170,17,AMBER)
	map_buttons.append(button(menu,"The Outpost",Rect2(46,218,393,60),func(): request_map(false)))
	map_buttons.append(button(menu,"Vertigo Tower",Rect2(46,291,393,60),func(): request_map(true)))
	map_title = words(menu,"",46,408,33)
	description = words(menu,"",47,472,18)
	deploy_button = button(menu,"DEPLOY",Rect2(46,605,393,65),func(): deployed.emit())
	var active_style := StyleBoxFlat.new()
	active_style.bg_color = Color("d79f68")
	deploy_button.add_theme_stylebox_override("normal",active_style)
	deploy_button.add_theme_color_override("font_color",Color("18242a"))
	scope=backing(play,Rect2(0,0,1280,720),Color.WHITE)
	var scope_mat:=ShaderMaterial.new()
	scope_mat.shader=preload("res://scripts/scope.gdshader")
	scope.material=scope_mat
	scope.hide()
	backing(play,Rect2(20,17,367,70),Color("101b22df"))
	location = words(play,"",35,22,15,ICE)
	wave = words(play,"",35,43,24)
	objective=words(play,"",35,91,18,AMBER)
	perk_line=words(play,"",35,606,16,ICE)
	contract=words(play,"",36,119,15,ICE)
	for field in [objective,perk_line,contract]:
		field.add_theme_constant_override("outline_size",4)
	damage=backing(play,Rect2(0,0,1280,720),Color(1,.12,.06,0))
	backing(play,Rect2(20,640,385,62),Color("101b22e8"))
	vitals = words(play,"",35,651,23)
	backing(play,Rect2(870,640,390,62),Color("101b22e8"))
	ammo = words(play,"",884,652,22)
	prompt = words(play,"",0,545,20)
	banner = words(play,"",0,108,29,AMBER)
	card=words(play,"",0,170,21)
	subtitle=words(play,"",0,466,19)
	intro_card=words(play,"",0,256,32)
	for label in [prompt,banner,card,subtitle,intro_card]:
		label.size.x = 1280
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_constant_override("outline_size",5)
		label.add_theme_color_override("font_outline_color",Color("101722"))
	for pos in [Vector2(631,359),Vector2(645,359),Vector2(639,351),Vector2(639,365)]:
		dots.append(backing(play,Rect2(pos,Vector2(4,2) if pos.y==359 else Vector2(2,4)),IVORY))
	marker = words(play,"×",629,335,36,AMBER)
	marker.hide()
	transit=backing(play,Rect2(0,0,1280,720),Color(.03,.05,.07,0))
	play.add_child(directory)
	backing(directory,Rect2(95,118,1090,466),Color("101d26f7"))
	directory_title=words(directory,"",125,139,25,AMBER)
	words(directory,"Gold is your room     ·     Teal passages are open     ·     Amber bars are barricades     ·     Purple marks a service return",125,531,16,ICE)
	directory.hide()
	backing(overlay,Rect2(0,0,1280,720),Color("101823df"))
	end_title = words(overlay,"",85,165,59)
	end_detail = words(overlay,"",90,270,23,ICE)
	resume = button(overlay,"RESUME",Rect2(90,375,300,61),func(): command.emit("resume"))
	button(overlay,"MAP SELECTION",Rect2(90,456,300,61),func(): command.emit("menu"))
	play.hide()
	overlay.hide()
	add_child(loading)
	loading.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backing(loading,Rect2(0,0,1280,720),Color("101b23"))
	words(loading,"DEADSHIFT",72,469,48)
	loading_label=words(loading,"",74,552,24,ICE)
	loading.hide()

func request_map(tower_map: bool) -> void:
	if busy: return
	busy=true
	loading_label.text="Surveying Vertigo Tower…" if tower_map else "Tuning the ridge signal…"
	loading.show()
	await get_tree().process_frame
	await get_tree().process_frame
	selected.emit(tower_map)
	loading.hide()
	busy=false
	menu.modulate.a=.36
	create_tween().tween_property(menu,"modulate:a",1.0,.28)


func preview(tower: bool) -> void:
	map_buttons[0].modulate = Color.WHITE if not tower else Color("80969b")
	map_buttons[1].modulate = Color.WHITE if tower else Color("80969b")
	map_title.text = "Vertigo Tower" if tower else "The Outpost"
	description.text = "TOWER EXTRACTION\nCross each floor to the opposite lift.\nReach the roof and call the helicopter." if tower else "ENDLESS SURVIVAL\nCross the depot yard to the ridge.\nOne continuous ground-level route."

func modal(title: String, detail: String, paused: bool) -> void:
	overlay.show()
	end_title.text = title
	end_detail.text = detail
	resume.visible = paused

func show_directory(game) -> void:
	directory.visible=Input.is_physical_key_pressed(KEY_TAB) and game.state=="play"
	if not directory.visible:return
	var key: String=str(game.tower)+"/"+str(game.level)
	if key!=last_floor_key:
		for item in map_cells.values():item.queue_free()
		for door in map_doors:door.queue_free()
		map_cells.clear()
		map_doors.clear()
		var bounds:=Rect2i(game.sector.route[0],Vector2i.ONE)
		for cell: Vector2i in game.sector.route:
			bounds=bounds.merge(Rect2i(cell,Vector2i.ONE))
		var step:=Vector2(minf(200,1036./bounds.size.x),minf(158,340./bounds.size.y))
		var origin:=Vector2(640,351)-Vector2(bounds.size-Vector2i.ONE)*step*.5
		var card_size:=Vector2(step.x-12,minf(94,step.y-9))
		for link in game.sector.links:
			var a:=origin+Vector2(link[0]-bounds.position)*step
			var b:=origin+Vector2(link[1]-bounds.position)*step
			map_doors.append(backing(directory,Rect2(a.min(b)-Vector2(2,2),(b-a).abs()+Vector2(4,4)),ICE))
		for cell: Vector2i in game.sector.route:
			var p:=origin+Vector2(cell-bounds.position)*step-card_size*.5
			var card:=backing(directory,Rect2(p,card_size),Color("29434a"))
			var name_label:=words(card,game.sector.room_names[cell],5,4,17 if game.tower else 12)
			name_label.size.x=card_size.x-14
			name_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
			var details:=words(card,"",5,roundi(card_size.y*.45),13 if game.tower else 11,ICE)
			details.name="Details"
			details.size.x=card_size.x-14
			details.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
			map_cells[cell]=card
		last_floor_key=key
	var floor_name:String=game.sector.FLOORS[game.level] if game.tower else "The Outpost"
	directory_title.text=floor_name+(("   /   Eastbound" if game.level%2==0 else "   /   Westbound") if game.tower else "")
	for cell in map_cells:
		map_cells[cell].color=Color("8c653d") if cell==game.sector.cell_at(game.player.position) else (Color("28484b") if game.sector.accessible.has(cell) else Color("2c333e"))
		var tags:=PackedStringArray()
		for station in game.sector.stations:
			if game.sector.cell_at(station.pos)!=cell or station.get("dormant",false):continue
			tags.append({"gun":"Carbine","heavy":"Arc Driver","sidearm":"Rook","shotgun":"Shotgun","smg":"SMG","lmg":"LMG","marksman":"Marksman","up":"Lift up","down":"Lift down","board":"Aircraft","objective":"Objective","power":"Power","forge":"Forge","cache":"Cache","lore":"Tape","lore_b":"Tape","secret":"Decoder","quick":"Reload","light":"Speed","revive":"Revive","recovery":"Recovery","vital":"Health"}.get(station.kind,station.title.capitalize()))
		map_cells[cell].get_node("Details").text=" · ".join(tags)
	for i in map_doors.size():
		var gate:Dictionary=game.sector.gates[i]
		map_doors[i].color=ICE if gate.open else (Color("bb9ad5") if gate.shortcut else AMBER)
