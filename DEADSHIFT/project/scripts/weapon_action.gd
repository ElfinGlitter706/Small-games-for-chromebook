extends RefCounted

# Lift, roll, reload tilt, muzzle length and impulse for each first-person animation.
const MOTION := {
	"sidearm":Vector4(.27,.06,.70,.39), "gun":Vector4(.16,-.06,.60,.68),
	"smg":Vector4(.11,.10,.92,.48), "shotgun":Vector4(.43,-.12,.38,.72),
	"heavy":Vector4(.32,.16,-.72,.54), "lmg":Vector4(.18,-.10,-.41,.76),
	"marksman":Vector4(.35,-.035,1.10,.79), "relic":Vector4(.22,.18,-1.03,.61)}
var spin := 0.0
var winding := false
var shove := 0.0
var fx: Array[Dictionary] = []
var next_fx := 0

func shoot(g, melee: bool) -> void:
	var aim: Basis = g.camera.global_basis.orthonormalized()
	var eye: Vector3 = g.sector.to_local(g.camera.global_position)
	var scatter: bool = g.loadout=="shotgun" and not melee
	var pellets := 7 if scatter else 1
	var penetrating: bool = not melee and (scatter or g.specialty.get(g.loadout,"")=="arc")
	var touched := false
	var critical := false
	var penetrated:=false
	for i in pellets:
		var direction := -aim.z
		if i>0:
			var angle: float = i*TAU/6.0+g.shots*.39
			direction = (direction+(aim.x*cos(angle)+aim.y*sin(angle))*(.044 if g.aiming() else .071)).normalized()
		var contacts: Array[Dictionary] = []
		for enemy in g.enemies:
			if enemy.mode!="hunt" or enemy.hp<=0: continue
			var center: Vector3 = enemy.position+Vector3.UP*1.18*enemy.scale.y
			var along := (center-eye).dot(direction)
			if along<=0 or along>(2.2 if melee else 80.0): continue
			var point := eye+direction*along
			var lateral := Vector2(point.x-center.x,point.z-center.z)
			var height: float = (point.y-enemy.position.y)/enemy.scale.y
			if lateral.length()>.46*enemy.scale.x or height<.14 or height>2.12: continue
			if g.sector.nav.blocked_ray(eye,point): continue
			var zone := "head" if height>1.60 else ("leg" if height<.84 else "torso")
			contacts.append({"enemy":enemy,"zone":zone,"distance":along})
		contacts.sort_custom(func(a,b): return a.distance<b.distance)
		var limit := (3 if scatter and g.specialty.get(g.loadout,"")=="arc" else 2) if penetrating else 1
		for j in mini(contacts.size(),limit):
			if j>0:penetrated=true
			var contact: Dictionary = contacts[j]
			var zone: String = contact.zone
			var hit_power: int = 2 if melee else g.WEAPONS[g.loadout].power + g.upgrades.get(g.loadout,0)
			if not melee and 3 in g.fitted: hit_power+=1
			if scatter: hit_power = ceili(hit_power/4.0)
			if j>0: hit_power = maxi(1,hit_power/2)
			if zone=="head" and not melee: hit_power *= 3 if "deadeye" in g.perks else 2
			var enemy = contact.enemy
			hit_power = enemy.strike(zone,hit_power,melee)
			if g.buffs.get("overload",0)>0: hit_power = 999
			enemy.hp -= hit_power
			if melee:
				var push: Vector3 = enemy.position-g.player.position
				push.y=0
				enemy.position = g.sector.nav.move(enemy.position,push.normalized()*.35)
			touched = true
			critical = critical or (zone=="head" and not melee)
			if enemy.hp<=0: g.kill_enemy(enemy,zone=="head" and not melee,not melee)
	if not melee:
		g.shots += 1
		if touched: g.hits += 1
		g.director.record_shot(g,critical)
		if not g.session.practice:
			g.mastery_streak=g.mastery_streak+1 if critical else 0
			var task:String=g.armory.TASKS[g.loadout][0]
			if task=="Headshot streak":g.armory.advance(g.loadout,g.mastery_streak,true)
			if task=="Penetrations" and penetrated:g.armory.advance(g.loadout,1)
	if touched:
		g.hit=.18
		g.ui.marker.modulate=[Color.GOLD,Color.CYAN,Color.HOT_PINK][g.options.pref("Critical marker",0)] if critical else Color.WHITE
		g.ui.marker.text="✦" if melee else "×"
		g.sound.cue("slam" if melee else ("critical" if critical else "impact"),-13)
	if g.queued==0 and g.enemies.is_empty() and g.intermission<=0: g.wave_clear()

func eject(g) -> void:
	if DisplayServer.get_name()=="headless": return
	if fx.size()<16:
		var shell = g.sector.art.piece("pipe",Vector3.ZERO,Vector3(.025,.071,.025),"c7a670",Vector3.ZERO,g)
		var puff = g.sector.art.piece("oval",Vector3.ZERO,Vector3.ONE*.05,"a9aaa2",Vector3.ZERO,g)
		var haze: StandardMaterial3D = puff.material_override.duplicate()
		haze.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		haze.albedo_color=Color(.65,.7,.72,.22)
		haze.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		puff.material_override=haze
		fx.append({"shell":shell,"puff":puff})
		next_fx=fx.size()-1
	var effect: Dictionary = fx[next_fx]
	next_fx=(next_fx+1)%16
	var basis: Basis=g.camera.global_basis.orthonormalized()
	effect.shell.global_position=g.gun.global_position+basis.x*.09
	effect.shell.show()
	effect.puff.global_position=g.flash.global_position
	effect.puff.show()
	effect.life=.48
	effect.velocity=basis.x*1.45+Vector3.UP*1.2+basis.z*.15
	effect.drift=-basis.z*.9+Vector3.UP*.35

func tick(delta: float) -> void:
	shove=maxf(0,shove-delta*4.4)
	if not winding: spin=maxf(0,spin-delta)
	for effect in fx:
		if effect.life<=0: continue
		effect.life-=delta
		effect.velocity+=Vector3.DOWN*delta*7.0
		effect.shell.position+=effect.velocity*delta
		effect.shell.rotate_x(delta*11.0)
		effect.puff.position+=effect.drift*delta
		effect.puff.scale=Vector3.ONE*(.042+.2*(.48-effect.life))
		effect.puff.material_override.albedo_color.a=.30*maxf(0,effect.life/.48)
		effect.puff.visible=effect.life>.17
		effect.shell.visible=effect.life>0

func pose(g) -> void:
	var shape: Vector4=MOTION[g.loadout]
	var reload_phase := 1.0-clampf(g.reload_left/g.reload_duration(),0,1)
	var tilt := sin(reload_phase*PI)
	var kick: float=g.recoil*(.63 if g.specialty.get(g.loadout,"")=="handling" else 1.0)
	g.gun.position.z=-.60+shape.x*.48*kick-.25*sin(PI*shove)+.07*tilt
	if 2 in g.fitted: kick*=.65
	g.gun.position.y=(-g.Models.SIGHT_LINE if g.aiming() else -.25)-.13*tilt
	if g.walking and not g.aiming() and g.options.pref("Camera effects",1): g.gun.position.y+=.014*sin(g.sim_time*10)
	g.gun.rotation=Vector3(shape.x*kick*(.12 if g.aiming() else 1.)-tilt*.24,shape.y*kick+.24*shove,shape.z*tilt+shape.y*kick-.7*shove)
	g.flash.visible=g.recoil>.80 and shove<=0
	if is_instance_valid(g.reload_part):
		var open:=sin(PI*reload_phase)
		match g.loadout:
			"shotgun": g.reload_part.position=Vector3(.13*open,-.13*absf(sin(PI*reload_phase*3)),-.15*open)
			"heavy","relic":
				g.reload_part.position=Vector3(shape.y*open,.07*open,.22*open)
				g.reload_part.rotation.z=open*shape.z*2
			"lmg":
				g.reload_part.position=Vector3(-.20*open,-.21*open,.09*open)
				g.reload_part.rotation.z=-.6*open
			"marksman": g.reload_part.position=Vector3(-.09*open,-.17*open,.18*sin(TAU*reload_phase))
			_: g.reload_part.position=Vector3(shape.y*open,-(.17+absf(shape.z)*.14)*open,.08*open)
