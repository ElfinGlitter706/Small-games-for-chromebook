extends Node
## Short original synthesised cues, cached as PCM for native and Web playback.
var bank := {}
var voices: Array[AudioStreamPlayer] = []
var cursor := 0
var emitters: Array[AudioStreamPlayer3D] = []
var emitter_index := 0
var gains := {"Weapons":0.,"Zombies":0.,"Music":-6.,"Ambience":0.}
var music_clock := 0.
var beat := 0
var last_mode := ""
var recorder := AudioStreamPlayer.new()
var music_voice := AudioStreamPlayer.new()

func tape(first: bool) -> float:
	recorder.stream=preload("res://scripts/ridge_a.wav") if first else preload("res://scripts/ridge_b.wav")
	recorder.volume_db=-4+gains.Ambience
	recorder.play()
	return recorder.stream.get_length()+.5

func _ready() -> void:
	add_child(recorder)
	add_child(music_voice)
	var rng := RandomNumberGenerator.new()
	rng.seed = 733
	var profiles := {"fire":[0.15,156,42,0.72], "rack":[0.19,640,240,0.64],
		"impact":[0.11,350,65,0.38], "breach":[0.53,94,44,0.28],
		"fall":[0.27,88,32,0.43], "purchase":[0.34,370,760,0.0],
		"round":[0.72,145,290,0.03], "hurt":[0.19,95,46,0.15],
		"step":[0.10,85,34,0.48], "escape":[0.85,255,710,0.0],
		"critical":[.13,870,380,.08],"induct":[.28,310,80,.35],"tone":[.8,110,110,.015],
		"air":[1.4,48,51,.32],"pickup":[.36,385,780,.06],"slam":[.35,72,31,.63]}
	profiles.merge({"muffled":[.48,67,39,.22],"splinter":[.20,680,74,.88],"snarl":[.40,124,52,.34],"elite":[.66,69,31,.29],"radio":[.73,510,170,.23]})
	profiles.merge({"sidearm":[.16,191,48,.65],"gun":[.19,132,36,.73],"heavy":[.41,262,39,.32],
		"smg":[.11,208,60,.78],"shotgun":[.39,112,31,.84],"lmg":[.25,102,38,.67],
		"marksman":[.33,204,35,.59],"relic":[.42,521,65,.20],"swipe":[.14,490,160,.85],
		"spool":[.24,76,330,.32],"rotors":[.31,45,35,.25],"thunder":[1.25,72,25,.62],"wind":[1.55,77,58,.78]})
	for key: String in profiles:
		var p: Array = profiles[key]
		var count := int(p[0] * 22050)
		var data := PackedByteArray()
		data.resize(count * 2)
		var phase := 0.0
		var filtered := 0.0
		for i in count:
			var t := float(i) / count
			phase += TAU * lerpf(p[1], p[2], t) / 22050.0
			filtered = lerpf(filtered, rng.randf_range(-1, 1), 0.55)
			var sample := lerpf(sin(phase) + 0.16 * sin(phase*2.01), filtered, p[3])
			data.encode_s16(i*2, int(clampf(sample, -1, 1)* 17500 * minf(1, i/44.0) * pow(1-t, 2)))
		var stream := AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = 22050
		stream.data = data
		bank[key] = stream
	for i in 8:
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		voices.append(voice)
	for i in 4:
		var emitter := AudioStreamPlayer3D.new()
		emitter.unit_size = 6
		emitter.max_distance = 44
		add_child(emitter)
		emitters.append(emitter)

func at(key: String, location: Vector3, db: float) -> void:
	var emitter := emitters[emitter_index]
	emitter_index = (emitter_index+1)%emitters.size()
	emitter.position = location
	emitter.stream = bank[key]
	emitter.volume_db = db+gains["Zombies"]
	emitter.play()

func cue(key: String, db := -8.0) -> void:
	var voice := voices[cursor]
	cursor = (cursor + 1) % voices.size()
	voice.stream = bank[key]
	voice.pitch_scale=1
	voice.volume_db = db+gains["Weapons" if key in ["fire","induct","rack","impact","critical","sidearm","gun","smg","heavy","shotgun","lmg","marksman","relic","swipe","spool"] else "Ambience"]
	voice.play()

func score(delta: float, mode: String) -> void:
	if last_mode!=mode:
		last_mode=mode
		music_clock=0
		beat=0
	music_clock-=delta
	if music_clock>0: return
	var notes: Array
	match mode:
		"combat": notes=[0,7,3,5,0,10,7,3]
		"boss": notes=[-5,-5,1,-5,-2,1,-5,2]
		"extraction": notes=[0,4,7,12,11,7,4,7]
		_: notes=[0,0,3,7,5,3,0,-5]
	music_voice.stream=bank.tone
	music_voice.pitch_scale=pow(2.,notes[beat%8]/12.)
	music_voice.volume_db=(-22 if mode=="boss" else -25)+gains.Music
	music_voice.play()
	if beat%8==0: cue("air",-28)
	beat+=1
	music_clock={"combat":.53,"boss":.31,"extraction":.40,"calm":1.14}.get(mode,1.)

func _exit_tree() -> void:
	for voice in voices:
		voice.stop()
		voice.stream = null
	for emitter in emitters:
		emitter.stop()
		emitter.stream = null
