extends RefCounted

var first_kills := 0
var first_shots := 0
var first_hits := 0
var first_credits := 0
var damage := 0
var damage_total := 0
var worst_room := ""
var wounds := {}
var streak := 0
var repairs := 0
var contracts := 0
var pressure := 0.0
var recovery := 0.0
var challenge := false
var paid := false
var start_time := 0.0
var scorecard := ""
var card_time := 0.0

func open(g) -> int:
	first_kills = g.kills
	first_shots = g.shots
	first_hits = g.hits
	first_credits = g.earned
	damage = 0
	streak = 0
	repairs = 0
	paid = false
	pressure = 0
	recovery = 0
	start_time = g.sim_time
	challenge = g.wave % 4 == 0
	var count: int = 3 + 3 * g.wave + g.options.pref("Difficulty",0) * g.wave
	return count + (2 if challenge else 0)

func cadence(g) -> float:
	return maxf(.30,1.55 - g.wave * .115) * (.74 if challenge else 1.0)

func update(delta: float) -> void:
	card_time = maxf(0,card_time-delta)
	recovery = maxf(0,recovery-delta)
	pressure = move_toward(pressure,0,delta*1.2)

func wounded(g, amount: int) -> void:
	damage += amount
	damage_total += amount
	streak = 0
	var room: String = g.sector.room_names.get(g.sector.cell_at(g.player.position),"Landing")
	wounds[room] = wounds.get(room,0) + amount
	if worst_room.is_empty() or wounds[room] > wounds.get(worst_room,0): worst_room = room
	pressure += amount
	if pressure >= 35:
		recovery = 2.6
		pressure = 0

func record_shot(g, critical: bool) -> void:
	streak = streak+1 if critical else 0
	if g.wave % 3 == 1 and streak >= 3: reward(g)

func repaired(g) -> void:
	repairs += 1
	if g.wave % 3 == 2 and repairs >= 2: reward(g)

func contract_text(wave: int) -> String:
	if paid: return "Contract paid"
	match wave % 3:
		1: return "Land consecutive headshots   %d/3" % mini(streak,3)
		2: return "Brace breached entrances   %d/2" % mini(repairs,2)
		_: return "Clear this wave unhurt" if damage==0 else "Unhurt contract lost"
		
func reward(g) -> void:
	if paid: return
	paid = true
	contracts += 1
	g.award(175)
	g.sound.cue("purchase",-13)
	g.announce("Contract complete   +175 cr")

func close(g) -> float:
	if g.wave % 3 == 0 and damage == 0: reward(g)
	if challenge:
		g.award(300)
		g.apply_drop("ammo")
	var accuracy := roundi(100.0*(g.hits-first_hits)/maxi(1,g.shots-first_shots))
	scorecard = "WAVE %02d CLEAR    ·    %d kills    ·    %d%% accuracy    ·    +%d cr    ·    %ds" % [g.wave,g.kills-first_kills,accuracy,g.earned-first_credits,roundi(g.sim_time-start_time)]
	if challenge: scorecard += "\nRush reward   +300 cr and reserve ammo"
	card_time = 5
	return 8.5 if damage>=35 or challenge else 5.5

func debrief(g) -> String:
	var advice := "Most damage in %s (%d HP). Open an exit there early." % [worst_room,wounds.get(worst_room,0)]
	if worst_room.is_empty():
		advice = "Clean run through the opened rooms."
	if g.shots>12 and float(g.hits)/g.shots < .4:
		advice += " Aim during bursts to conserve ammo."
	return "%d contracts paid   ·   %d HP lost\n%s" % [contracts,damage_total,advice]
