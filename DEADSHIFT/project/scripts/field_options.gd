extends CanvasLayer

var game
var sample_seconds:=0.0
var sample_frames:=0
var good_samples:=0
var auto_resolution:=.65
var weapon_list:=OptionButton.new()
var armory_info:=Label.new()
var part_buttons:Array[Button]=[]
var config := ConfigFile.new()
var panel := PanelContainer.new()
var tabs := TabContainer.new()
var eggs:=Label.new()
var record_text := Label.new()
var fov := 78.
var sensitivity := 1.
var active_cap := 14
var capture_key := 0
var capture_button: Button
var bindings := {}
var previous_mouse := Input.MOUSE_MODE_VISIBLE
const KEYS := {KEY_W:"Forward",KEY_S:"Back",KEY_A:"Left",KEY_D:"Right",KEY_SHIFT:"Sprint",KEY_CTRL:"Crouch / slide",KEY_SPACE:"Jump",KEY_R:"Reload",KEY_F:"Melee",KEY_E:"Interact",KEY_Q:"Swap weapon",KEY_P:"Performance display",KEY_G:"Use equipment / training gun",KEY_UP:"Look up",KEY_DOWN:"Look down",KEY_LEFT:"Look left",KEY_RIGHT:"Look right"}

func build(parent) -> void:
	game=parent
	layer=4
	config.load("user://deadshift_options.cfg")
	var ui=game.ui
	ui.button(ui.menu,"Armory, settings & records",Rect2(46,358,393,42),show_panel)
	ui.button(ui.overlay,"SETTINGS & RECORDS",Rect2(415,456,325,61),show_panel)
	add_child(panel)
	panel.position=Vector2(180,46)
	panel.size=Vector2(920,632)
	var style:=StyleBoxFlat.new()
	style.bg_color=Color("14212b")
	style.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel",style)
	var stack:=VBoxContainer.new()
	panel.add_child(stack)
	tabs.custom_minimum_size=Vector2(865,512)
	stack.add_child(tabs)
	var display:=page("Display")
	var controls:=page("Controls")
	var audio:=page("Audio")
	var workshop:=page("Armory")
	workshop.add_child(weapon_list)
	for key in game.WEAPONS: weapon_list.add_item(game.WEAPONS[key].title)
	workshop.add_child(armory_info)
	weapon_list.item_selected.connect(func(_idx): refresh_armory())
	for i in game.armory.PARTS.size():
		var part:=Button.new()
		workshop.add_child(part)
		part_buttons.append(part)
		part.pressed.connect(change_part.bind(i))
	var records:=page("Run records")
	records.add_child(record_text)
	page("Discovered Easter Eggs").add_child(eggs)
	var rules:=page("Challenges")
	var hint:=Label.new()
	hint.text="Applies on your next deployment. Each modifier adds 15% weapon XP."
	rules.add_child(hint)
	choice(rules,"Daily seed",["Off","Today’s challenge"],0)
	for rule in game.session.RULES:choice(rules,rule,["Off","On"],0)
	choice(controls,"Sprint toggle",["Hold","Toggle"],0)
	choice(controls,"Crouch toggle",["Hold","Toggle"],0)
	choice(display,"Critical marker",["Gold","Cyan","Pink"],0)
	choice(display,"Subtitle size",["Standard","Large","Extra large"],0)
	choice(audio,"Threat captions",["Off","On"],0)
	choice(display,"Quality",["Auto","Low","Medium","High","Ultra"],0)
	choice(display,"Window",["Windowed","Fullscreen"],0)
	choice(display,"Resolution",["1280 × 720","1600 × 900","1920 × 1080"],0)
	choice(display,"VSync",["Off","On"],1)
	choice(display,"FPS limit",["Unlimited","30","60","120"],2)
	choice(display,"Antialiasing",["Off","2× MSAA"],1)
	choice(display,"Shadows",["Off","On"],1)
	choice(display,"Texture filter",["Nearest","Linear"],1)
	choice(display,"Camera effects",["Reduced","Full"],1)
	choice(display,"Crosshair",["Off","On"],1)
	choice(display,"Difficulty",["Standard","Veteran"],0)
	choice(display,"Weapon finish",["Steel","Oxide","Polar"],0)
	choice(display,"Sleeves",["Field","Ember","Frost"],0)
	choice(controls,"FOV",["65","75","85","95","105"],2)
	choice(controls,"Sensitivity",["Slow","Normal","Fast","Very fast"],1)
	choice(controls,"ADS sensitivity",["Low","Medium","Full"],1)
	choice(controls,"Aim mode",["Hold","Toggle"],0)
	for key in KEYS:
		bindings[key]=config.get_value("keys",str(key),key)
		var b:=Button.new()
		b.text=KEYS[key]+"    "+OS.get_keycode_string(bindings[key])
		controls.add_child(b)
		b.pressed.connect(begin_capture.bind(key,b))
	for title in ["Master","Music","Weapons","Zombies","Ambience"]:
		choice(audio,title,["Mute","25%","50%","75%","100%"],2 if title=="Music" else 4)
	var close:=Button.new()
	close.text="Back"
	close.pressed.connect(hide_panel)
	stack.add_child(close)
	panel.hide()
	apply_quality()
	if not OS.has_feature("web") and DisplayServer.get_name()!="headless":
		if config.has_section_key("prefs","Resolution"):
			DisplayServer.window_set_size([Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080)][pref("Resolution",0)])
		if pref("Window",0): DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func page(title: String) -> VBoxContainer:
	var scroll:=ScrollContainer.new()
	scroll.name=title
	tabs.add_child(scroll)
	var box:=VBoxContainer.new()
	box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	return box

func pref(key: String, fallback: int) -> int:
	return int(config.get_value("prefs",key,fallback))

func choice(parent: VBoxContainer,title: String,values: Array,initial: int) -> void:
	var row:=HBoxContainer.new()
	parent.add_child(row)
	var label:=Label.new()
	label.text=title
	label.custom_minimum_size.x=290
	row.add_child(label)
	var opt:=OptionButton.new()
	for value in values: opt.add_item(value)
	opt.select(clampi(pref(title,initial),0,values.size()-1))
	row.add_child(opt)
	opt.item_selected.connect(func(index):
		config.set_value("prefs",title,index)
		config.save("user://deadshift_options.cfg")
		apply_quality()
		if title=="Window" and not OS.has_feature("web"):
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if index else DisplayServer.WINDOW_MODE_WINDOWED)
		if title=="Resolution" and not OS.has_feature("web"):
			DisplayServer.window_set_size([Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080)][index])
	)

func _process(delta:float) -> void:
	if not OS.has_feature("web") or pref("Quality",0)!=0 or game.state!="play": return
	sample_seconds+=delta
	sample_frames+=1
	if sample_seconds<2.0:return
	var rate:=sample_frames/sample_seconds
	var target:=minf(60,maxi(1,Engine.max_fps)) if Engine.max_fps>0 else 60.0
	sample_seconds=0
	sample_frames=0
	if rate<target*.78:
		auto_resolution=maxf(.45,auto_resolution-.10)
		good_samples=0
	elif rate>=target*.94:
		good_samples+=1
		if good_samples>=3:
			auto_resolution=minf(.75,auto_resolution+.05)
			good_samples=0
	else: good_samples=0
	get_viewport().scaling_3d_scale=auto_resolution

func apply_quality() -> void:
	var quality:=pref("Quality",0)
	if quality==0: quality=1 if OS.has_feature("web") else 3
	active_cap=[10,9,12,16,20][quality]
	fov=[65.,75.,85.,95.,105.][pref("FOV",2)]
	sensitivity=[.65,1.,1.45,2.][pref("Sensitivity",1)]
	Engine.max_fps=[0,30,60,120][pref("FPS limit",2)]
	if DisplayServer.get_name()!="headless" and not OS.has_feature("web"):
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if pref("VSync",1) else DisplayServer.VSYNC_DISABLED)
	var viewport:=get_viewport()
	viewport.scaling_3d_scale=auto_resolution if OS.has_feature("web") and pref("Quality",0)==0 else [1.,.75,.9,1.,1.][quality]
	viewport.msaa_3d=Viewport.MSAA_2X if pref("Antialiasing",1) and quality>1 else Viewport.MSAA_DISABLED
	if game.sector!=null:
		for sun in game.sector.find_children("*","DirectionalLight3D",false,false): sun.shadow_enabled=quality>1 and pref("Shadows",1)==1
		for mat in game.sector.art.materials.values():
			mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS if pref("Texture filter",1) else BaseMaterial3D.TEXTURE_FILTER_NEAREST
	game.ui.subtitle.add_theme_font_size_override("font_size",[19,24,29][pref("Subtitle size",0)])
	for dot in game.ui.dots: dot.visible=pref("Crosshair",1)==1
	AudioServer.set_bus_mute(0,pref("Master",4)==0)
	AudioServer.set_bus_volume_db(0,linear_to_db(maxf(.001,pref("Master",4)*.25)))
	for channel in ["Music","Weapons","Zombies","Ambience"]:
		game.sound.gains[channel]=linear_to_db(maxf(.00001,pref(channel,2 if channel=="Music" else 4)*.25))

func down(key: int) -> bool:
	return Input.is_physical_key_pressed(bindings.get(key,key))

func action(key: int) -> int:
	for original in bindings:
		if bindings[original]==key: return original
	return 0 if bindings.has(key) else key

func begin_capture(key: int,b: Button) -> void:
	capture_key=key
	capture_button=b
	b.text="Press a key"

func _input(e: InputEvent) -> void:
	if not panel.visible or not e is InputEventKey or not e.pressed or e.echo: return
	if capture_key:
		var key: int=e.physical_keycode
		if key!=KEY_ESCAPE and not (key in bindings.values() and bindings[capture_key]!=key):
			bindings[capture_key]=key
			config.set_value("keys",str(capture_key),key)
			config.save("user://deadshift_options.cfg")
		capture_button.text=KEYS[capture_key]+"    "+OS.get_keycode_string(bindings[capture_key])
		capture_key=0
		get_viewport().set_input_as_handled()
	elif e.keycode==KEY_ESCAPE:
		hide_panel()
		get_viewport().set_input_as_handled()

func change_part(index:int) -> void:
	var key:String=game.WEAPONS.keys()[weapon_list.selected]
	if game.armory.toggle(key,index) and game.loadout==key and game.wave>0:
		game.model()
		var excess:=maxi(0,game.ammo-game.capacity())
		game.ammo-=excess
		game.reserve=mini(game.reserve+excess,game.WEAPONS[key].reserve)
		game.refresh()
	refresh_armory()

func refresh_armory() -> void:
	var key:String=game.WEAPONS.keys()[weapon_list.selected]
	var rank:int=game.armory.rank(key)
	var equipped:Array=game.armory.equipped(key)
	var progress:String="Max level" if rank==game.armory.STEPS.size() else "%d / %d XP" % [game.armory.xp(key)-game.armory.STEPS[rank-1],game.armory.STEPS[rank]-game.armory.STEPS[rank-1]]
	armory_info.text="Level %d    ·    %s    ·    %d/%d attachments\nGun kills earn 20 XP, headshot kills earn 30 XP." % [rank,progress,equipped.size(),game.armory.slots(key)]
	var task:Array=game.armory.TASKS[key]
	armory_info.text+="\nGold finish   ·   %s   %d/%d" % [task[0],game.armory.data.get_value(key,"mastery",0),task[1]]
	for i in part_buttons.size():
		var selected:=i in equipped
		var locked:bool=game.armory.UNLOCK[i]>rank
		part_buttons[i].text="%s    ·    %s    ·    %s" % [game.armory.PARTS[i],game.armory.INFO[i],("Level %d" % game.armory.UNLOCK[i]) if locked else ("Equipped" if selected else "Equip")]
		part_buttons[i].disabled=locked or (not selected and equipped.size()>=game.armory.slots(key))

func show_panel() -> void:
	refresh_armory()
	var lines:=PackedStringArray()
	for mode in ["Outpost","Vertigo"]:
		lines.append("%s   •   Highest wave %d" % [mode,game.records.get_value(mode,"best",0)])
		var last: Dictionary=game.records.get_value(mode,"last",{})
		if not last.is_empty(): lines.append("Last run: %d kills, %d headshots, %d shots, %d downs, %d perks, %d weapon buys" % [last.kills,last.headshots,last.shots,last.downs,last.perks,last.weapons])
		var times: Array=game.records.get_value(mode,"leaderboard",[])
		if not times.is_empty(): lines.append("Local best waves: "+str(times))
	if game.records.has_section_key("Vertigo","fastest"): lines.append("Fastest extraction: %ds" % int(game.records.get_value("Vertigo","fastest")))
	lines.append("Challenges: survive wave 10  •  score 20 headshots  •  extract")
	lines.append("Completed: "+str(game.records.get_value("medals","unlocked",[])))
	var history:Array=game.records.get_value("runs","history",[])
	if not history.is_empty():
		lines.append("Recent runs")
		lines.append_array(history)
	var discovered:Array=game.records.get_value("discoveries","found",[])
	eggs.text="No discoveries yet." if discovered.is_empty() else "\n\n".join(discovered)
	record_text.text="\n\n".join(lines)
	panel.show()
	panel.move_to_front()
	game.ui.menu.visible=false
	game.ui.overlay.visible=false

func hide_panel() -> void:
	panel.hide()
	game.ui.menu.visible=game.state=="menu"
	game.ui.overlay.visible=game.state in ["paused","ended"]
