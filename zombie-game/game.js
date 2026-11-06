import * as THREE from 'three';

const $ = id => document.getElementById(id);
const menu=$('menu'), game=$('game'), modeScreen=$('modeScreen'), loadoutScreen=$('loadoutScreen');
let mode='free', started=false, scene,camera,renderer,clock;
let yaw=0,pitch=0,playerY=1.65,verticalVelocity=0,health=100,points=500,round=1;
let playerSpeed=5.2,playerSprintSpeed=8.2,ammo=8,reserve=Infinity,clipMax=8,reloading=false,firing=false,reloadTimer=null,fireTimer=null;
let weapon='m1911',equipment='frag',equipmentReady=true,equipmentTimer=0,boxWeapon=null,roundTimer=0,roundActive=false,spawnQueue=0,spawnClock=0;
let powerOn=false,godMode=false,isEasterEggActive=false;
const keysPressed={}, collisionObstacles=[], zombies=[], interactives=[], windowZones=[], bullets=[], effects=[], turrets=[];
const player={pos:new THREE.Vector3(0,1.65,8),radius:.38};
const worldUp=new THREE.Vector3(0,1,0);
let joystick={x:0,y:0}, touchLook=null, mobile=false, cheatSequence='';
const mats={wall:new THREE.MeshStandardMaterial({color:0x343c43}),floor:new THREE.MeshStandardMaterial({color:0x202a2d}),wood:new THREE.MeshStandardMaterial({color:0x775033}),metal:new THREE.MeshStandardMaterial({color:0x65727a,metalness:.65,roughness:.4}),zombie:new THREE.MeshStandardMaterial({color:0x69734c}),red:new THREE.MeshStandardMaterial({color:0xa83b2e}),blue:new THREE.MeshStandardMaterial({color:0x1c8dbd,emissive:0x075a9a}),gold:new THREE.MeshStandardMaterial({color:0xd7a83d,emissive:0x49300b})};
function notice(t){$('notice').textContent=t;clearTimeout(notice.timer);notice.timer=setTimeout(()=>$('notice').textContent='',1800)}
function box(w,h,d,x,y,z,mat,solid=false){const m=new THREE.Mesh(new THREE.BoxGeometry(w,h,d),mat);m.position.set(x,y,z);m.castShadow=true;m.receiveShadow=true;scene.add(m);if(solid)addObstacle(m);return m}
function addObstacle(mesh){const o={mesh,box:new THREE.Box3().setFromObject(mesh)};collisionObstacles.push(o);return o}
function updateObstacle(o){o.box.setFromObject(o.mesh)}
function buildWorld(){
 scene=new THREE.Scene();scene.background=new THREE.Color(0x111a20);scene.fog=new THREE.Fog(0x111a20,20,65);
 camera=new THREE.PerspectiveCamera(75,innerWidth/innerHeight,.1,120);camera.rotation.order='YXZ';
 renderer=new THREE.WebGLRenderer({antialias:true});renderer.setPixelRatio(Math.min(devicePixelRatio,2));renderer.setSize(innerWidth,innerHeight);renderer.shadowMap.enabled=true;game.prepend(renderer.domElement);
 scene.add(new THREE.HemisphereLight(0x9cb5c7,0x242018,1.2));const light=new THREE.DirectionalLight(0xffd5a1,2);light.position.set(-8,14,6);light.castShadow=true;scene.add(light);
 const floor=box(42,.5,42,0,-.25,0,mats.floor,true);
 // Perimeter walls.
 box(42,5,.6,0,2.5,-21,mats.wall,true);box(42,5,.6,0,2.5,21,mats.wall,true);
 box(.6,5,42,-21,2.5,0,mats.wall,true);box(.6,5,42,21,2.5,0,mats.wall,true);
 // Three connected wings with deliberate door openings.
 box(.5,4,19.6,-7,2,-11.2,mats.wall,true);box(.5,4,19.6,-7,2,11.2,mats.wall,true);
 box(.5,4,19.6,7,2,-11.2,mats.wall,true);box(.5,4,19.6,7,2,11.2,mats.wall,true);
 box(19.6,4,.5,-11.2,2,-7,mats.wall,true);box(19.6,4,.5,11.2,2,-7,mats.wall,true);
 // Barricaded windows are the designated zombie entry points.
 for(const [x,z,rot] of [[-20.6,-8,0],[20.6,8,Math.PI],[0,-20.6,Math.PI/2],[-8,20.6,-Math.PI/2]]){
  const group=new THREE.Group();group.position.set(x,1.5,z);group.rotation.y=rot;scene.add(group);
  for(let i=0;i<3;i++){const plank=new THREE.Mesh(new THREE.BoxGeometry(2.3,.18,.16),mats.wood);plank.position.y=-.65+i*.65;group.add(plank)}
  const frame=new THREE.Mesh(new THREE.BoxGeometry(2.8,2.5,.28),mats.metal);frame.position.z=-.12;group.add(frame);
  windowZones.push({pos:new THREE.Vector3(x,1.5,z),group,boards:3,max:3,lastRepair:0});
 }
 // Wall-facing machines around the perimeter.
 const gen=box(1.2,2,1,-14,1,-13,mats.metal);gen.userData.name='Power Switch';
 interactives.push({type:'power',name:'Power Switch',pos:gen.position,cost:0,mesh:gen});
 addMachine('Juggernog',2500,[-20.35,0,3],[1,0,0],0xb83d35);
 addMachine('Speed Cola',3000,[20.35,0,-3],[-1,0,0],0x36a45e);
 addMachine('Mystery Box',950,[0,0,-20.35],[0,0,1],0x1e83bc);
 addMachine('Pack-a-Punch',5000,[10,0,20.35],[0,0,-1],0xb18b34);
 addWallBuy('Wall Buy: Field Tool A',350,[-20.35,1.5,-2],[1,0,0]);
 addWallBuy('Wall Buy: Field Tool B',500,[20.35,1.5,2],[-1,0,0]);
 // Debris blocks the actual room connections and can be purchased away.
 addDebrisDoor('Clear North Wing',750,[0,1.2,-7],[0,0,1]);
 addDebrisDoor('Clear West Wing',1000,[-7,1.2,0],[1,0,0]);
 addDebrisDoor('Clear East Wing',1000,[7,1.2,0],[-1,0,0]);
 // A few props give the rooms different silhouettes.
 for(const [x,z] of [[-14,-14],[14,-14],[-14,14],[14,14]]){
  box(1.2,1.1,1.2,x,.55,z,mats.wood);
  box(.18,2.2,.18,x-.48,1.1,z-.48,mats.metal);
  box(.18,2.2,.18,x+.48,1.1,z-.48,mats.metal);
 }
}
function addMachine(name,cost,pos,normal,color){
 const mesh=new THREE.Group();mesh.position.set(...pos);mesh.rotation.y=Math.atan2(normal[0],normal[2]);scene.add(mesh);
 const body=new THREE.Mesh(new THREE.BoxGeometry(1.1,2,.72),new THREE.MeshStandardMaterial({color,metalness:.3,roughness:.55}));body.position.set(0,1,0);mesh.add(body);
 const face=new THREE.Mesh(new THREE.BoxGeometry(.72,.72,.08),new THREE.MeshStandardMaterial({color:0x17232a,emissive:color,emissiveIntensity:.22}));face.position.set(0,1.35,.4);mesh.add(face);
 const glow=new THREE.Mesh(new THREE.SphereGeometry(.18,16,12),new THREE.MeshBasicMaterial({color:0xffffff}));glow.position.set(0,1.72,.42);mesh.add(glow);
 const trim=new THREE.Mesh(new THREE.BoxGeometry(.9,.08,.08),mats.gold);trim.position.set(0,.32,.4);mesh.add(trim);
 interactives.push({type:name==='Mystery Box'?'box':name==='Pack-a-Punch'?'pap':'perk',name,cost,pos:mesh.position,mesh});
}
function addWallBuy(name,cost,pos,normal){
 const group=new THREE.Group();group.position.set(...pos);group.rotation.y=Math.atan2(normal[0],normal[2]);scene.add(group);
 const panel=new THREE.Mesh(new THREE.BoxGeometry(1.05,1.25,.12),mats.gold);group.add(panel);
 const screen=new THREE.Mesh(new THREE.BoxGeometry(.72,.55,.05),new THREE.MeshStandardMaterial({color:0x14242b,emissive:0x24677a,emissiveIntensity:.5}));screen.position.set(0,.18,.09);group.add(screen);
 const icon=new THREE.Mesh(new THREE.OctahedronGeometry(.22,0),mats.blue);icon.position.set(0,-.35,.13);group.add(icon);
 interactives.push({type:'wallbuy',name,cost,pos:group.position,mesh:group});
}
function addDebrisDoor(name,cost,pos,normal){
 const group=new THREE.Group();group.position.set(...pos);group.rotation.y=Math.atan2(normal[0],normal[2]);scene.add(group);
 const obstacleMesh=new THREE.Mesh(new THREE.BoxGeometry(2.8,2.4,.72),mats.wood);group.add(obstacleMesh);
 for(let i=0;i<5;i++){const plank=new THREE.Mesh(new THREE.BoxGeometry(.18,2.5,.82),mats.metal);plank.position.set(-1.1+i*.55,0,.12);plank.rotation.z=(i%2?-.12:.12);group.add(plank)}
 const obstacle={mesh:obstacleMesh,box:new THREE.Box3().setFromObject(obstacleMesh)};collisionObstacles.push(obstacle);
 interactives.push({type:'debris',name,pos:group.position,cost,mesh:group,obstacle});
}
function makeZombie(){
 const group=new THREE.Group(), torso=new THREE.Mesh(new THREE.BoxGeometry(.7,1,.38),mats.zombie);torso.position.y=1.35;group.add(torso);
 const head=new THREE.Mesh(new THREE.BoxGeometry(.48,.48,.45),mats.zombie);head.position.y=2.12;group.add(head);
 const arms=[],legs=[];for(let s of [-1,1]){const arm=new THREE.Mesh(new THREE.BoxGeometry(.2,.78,.22),mats.zombie);arm.position.set(s*.48,1.38,0);group.add(arm);arms.push(arm);const leg=new THREE.Mesh(new THREE.BoxGeometry(.25,.8,.28),mats.zombie);leg.position.set(s*.2,.45,0);group.add(leg);legs.push(leg)}
 const hp=round<=2?70:round<=5?100:130;const runner=round>=6&&Math.random()<.6;
 const z={group,torso,head,arms,legs,hp,maxHp:hp,speed:runner?Math.min(3.4,playerSprintSpeed-.8):round<=2?1.05:round<=5?1.55:2.0,runner,phase:Math.random()*6.28,alive:true,radius:.38};
 const entry=windowZones[Math.floor(Math.random()*windowZones.length)];
 const inward=entry.pos.clone().multiplyScalar(-1).setY(0).normalize();
 group.position.copy(entry.pos.clone().add(inward.multiplyScalar(2.2)));group.position.y=0;
 scene.add(group);zombies.push(z);return z;
}
function damageZombie(z,damage,headshot=false,killBonus=true){if(!z.alive)return;z.hp-=damage;if(z.hp<=0){z.alive=false;scene.remove(z.group);points+=headshot?100:60;if(killBonus)notice(headshot?'HEADSHOT +100':'ZOMBIE ELIMINATED');if(zombies.every(v=>!v.alive))finishRound()}else points+=10}
function finishRound(){if(roundActive){roundActive=false;roundTimer=5;notice(`ROUND ${round} COMPLETE`)}}
function startRound(){round++;spawnQueue=5+round*2;spawnClock=0;roundActive=true;$('round').textContent=`ROUND ${round}`;notice(`ROUND ${round}`)}
function moveWithCollision(pos,delta,radius){let p=pos.clone();for(const axis of ['x','z']){const next=p.clone();next[axis]+=delta[axis];const bb=new THREE.Box3(new THREE.Vector3(next.x-radius,next.y-.85,next.z-radius),new THREE.Vector3(next.x+radius,next.y+.85,next.z+radius));let blocked=false;for(const o of collisionObstacles){if(bb.intersectsBox(o.box)){blocked=true;break}}if(!blocked)p[axis]=next[axis]}return p}
function interact(){
 let best=null,bestD=3.0001;for(const item of interactives){if(item.used)continue;const d=player.pos.distanceTo(new THREE.Vector3(item.pos.x,player.pos.y,item.pos.z));if(d<bestD){best=item;bestD=d}}
 for(const w of windowZones){const d=player.pos.distanceTo(new THREE.Vector3(w.pos.x,player.pos.y,w.pos.z));if(d<bestD&&w.boards<3){best={type:'window',name:'Repair Barrier',window:w};bestD=d}}
 if(!best)return;
 if(best.type==='window'){if(points>=10&&best.window.boards<3){points-=0;best.window.boards++;const plank=new THREE.Mesh(new THREE.BoxGeometry(2.3,.18,.16),mats.wood);plank.position.y=-.65+(best.window.boards-1)*.65;best.window.group.add(plank);points+=10;notice('BARRIER REPAIRED +10')}return}
 if(best.type==='power'){powerOn=true;notice('GENERATOR ONLINE');return}
 if(best.type==='debris'){if(points>=best.cost){points-=best.cost;best.used=true;scene.remove(best.mesh);if(best.obstacle){const i=collisionObstacles.indexOf(best.obstacle);if(i>=0)collisionObstacles.splice(i,1)}notice('DEBRIS CLEARED')}return}
 if(best.type==='box'){if(points>=best.cost){points-=best.cost;const choices=['Ray Gun','LMG','Shotgun'];boxWeapon=choices[Math.floor(Math.random()*choices.length)];notice(`MYSTERY BOX: ${boxWeapon} — press E again to claim`);best.name=boxWeapon;best.type='claim';best.cost=0;best.pos.y=player.pos.y}return}
 if(best.type==='claim'){weapon=best.name.toLowerCase();clipMax=weapon==='ray gun'?20:weapon==='lmg'?60:8;ammo=clipMax;reserve=weapon==='ray gun'?100:120;best.used=true;notice(`${best.name} ACQUIRED`);return}
 if(best.type==='perk'&&best.name!=='Juggernog'&&best.name!=='Speed Cola')return;
 if(best.type==='perk'&&!powerOn){notice('POWER IS OFF');return}
 if(points>=best.cost){points-=best.cost;if(best.name==='Juggernog')health=150;if(best.name==='Speed Cola')reloadDuration=1000;if(best.name==='Pack-a-Punch'){weapon='ray gun';clipMax=20;ammo=20;reserve=100}if(best.type==='wallbuy'){weapon='shotgun';clipMax=6;ammo=6;reserve=36}notice(`${best.name} PURCHASED`)}
}
let reloadDuration=2000;
function reload(){if(reloading||ammo>=clipMax||reserve<=0)return;reloading=true;clearTimeout(reloadTimer);reloadTimer=setTimeout(()=>{const n=Math.min(clipMax-ammo,reserve);ammo+=n;if(reserve!==Infinity)reserve-=n;reloading=false},reloadDuration)}
function fire(){if(reloading||firing||ammo<=0)return;if(weapon==='m1911'&&reserve===Infinity){}else if(ammo<=0){reload();return}firing=true;ammo--;const ray=new THREE.Raycaster();ray.setFromCamera(new THREE.Vector2(0,0),camera);let hit=null,dist=Infinity;for(const z of zombies){if(!z.alive)continue;const parts=[z.head,z.torso,...z.legs];for(const part of parts){const h=ray.intersectObject(part,false)[0];if(h&&h.distance<dist){dist=h.distance;hit={z,head:part===z.head}}}}if(hit&&dist<35)damageZombie(hit.z,hit.head?100:55,hit.head);else{const dir=new THREE.Vector3();camera.getWorldDirection(dir);const b=new THREE.Mesh(new THREE.SphereGeometry(.045,6,6),new THREE.MeshBasicMaterial({color:0xffd37a}));b.position.copy(camera.position).add(dir.multiplyScalar(1));scene.add(b);effects.push({mesh:b,life:.12})}clearTimeout(fireTimer);fireTimer=setTimeout(()=>firing=false,weapon==='rk5'?180:260);if(ammo===0)reload()}
function throwEquipment(kind){if(!equipmentReady)return;equipmentReady=false;const dir=new THREE.Vector3();camera.getWorldDirection(dir);const p=camera.position.clone().add(dir.multiplyScalar(1.2));if(kind==='frag'||kind==='acid'){const orb=new THREE.Mesh(new THREE.SphereGeometry(.18,12,8),new THREE.MeshStandardMaterial({color:kind==='frag'?0x303b3d:0x54c933,emissive:kind==='acid'?0x164d0b:0x000000}));orb.position.copy(p);scene.add(orb);let t=0;effects.push({mesh:orb,life:kind==='frag'?3:2,callback:()=>{const pos=orb.position.clone();scene.remove(orb);if(kind==='frag'){for(const z of zombies)if(z.alive&&z.group.position.distanceTo(pos)<5)damageZombie(z,180,false)}else{const puddle=new THREE.Mesh(new THREE.CylinderGeometry(2,2,.08,24),new THREE.MeshBasicMaterial({color:0x38d52d,transparent:true,opacity:.55}));puddle.position.set(pos.x,.06,pos.z);scene.add(puddle);effects.push({mesh:puddle,life:5,callback:()=>scene.remove(puddle)});for(const z of zombies)if(z.alive&&z.group.position.distanceTo(pos)<2.5)damageZombie(z,120,false)}}})}else{const turret=new THREE.Group();turret.position.set(player.pos.x,.1,player.pos.z);const base=new THREE.Mesh(new THREE.CylinderGeometry(.35,.45,.35,12),mats.metal);turret.add(base);const barrel=new THREE.Mesh(new THREE.BoxGeometry(.16,.18,.8),mats.red);barrel.position.y=.3;turret.add(barrel);scene.add(turret);turrets.push({mesh:turret,life:30,cool:0})}equipmentReady=false;equipmentTimer=kind==='frag'?15:kind==='acid'?20:60;notice(`${kind.toUpperCase()} DEPLOYED`)}
function update(dt){
 const f=new THREE.Vector3(-Math.sin(yaw),0,-Math.cos(yaw)),r=new THREE.Vector3(Math.cos(yaw),0,-Math.sin(yaw));
 let mx=(keysPressed.KeyD?1:0)-(keysPressed.KeyA?1:0)+joystick.x,my=(keysPressed.KeyW?1:0)-(keysPressed.KeyS?1:0)-joystick.y;
 const dir=f.multiplyScalar(my).add(r.multiplyScalar(mx));if(dir.lengthSq()>1)dir.normalize();const speed=(keysPressed.ShiftLeft||keysPressed.ShiftRight||touchSprint)?playerSprintSpeed:playerSpeed;
 const delta=dir.multiplyScalar(speed*dt);player.pos.copy(moveWithCollision(player.pos,delta,player.radius));
 if(keysPressed.Space&&player.pos.y<=playerY+.01)verticalVelocity=.15*60;
 player.pos.y+=verticalVelocity*dt;verticalVelocity-=18*dt;if(player.pos.y<playerY){player.pos.y=playerY;verticalVelocity=0}
 camera.position.copy(player.pos);camera.rotation.set(pitch,yaw,0,'YXZ');
 // Zombies move with axis-separated collision and animated limbs.
 for(const z of zombies){if(!z.alive)continue;z.phase+=dt*(z.runner?12:5);const target=new THREE.Vector3(player.pos.x,0,player.pos.z),to=target.sub(z.group.position);to.y=0;const d=to.length();if(d>1.05){to.normalize();const step=to.multiplyScalar(z.speed*dt);z.group.position.copy(moveWithCollision(z.group.position,step,z.radius));z.group.lookAt(player.pos.x,0,player.pos.z)}
  const swing=Math.sin(z.phase)*(z.runner?.9:.48);z.legs[0].rotation.x=swing;z.legs[1].rotation.x=-swing*(round<=2?.45:1);z.arms[0].rotation.x=-swing*.7;z.arms[1].rotation.x=swing*.7;z.torso.rotation.z=round<=2?Math.sin(z.phase*.5)*.22:0;z.group.position.y=z.runner?Math.abs(Math.sin(z.phase*2))*.08:Math.abs(Math.sin(z.phase))*.025;
  if(d<1.25&&!godMode){health-=12*dt;if(health<=0){health=100;points=Math.max(0,points-250);player.pos.set(0,1.65,8);notice('DOWNED — RESPAWNED')}}
 }
 if(roundActive&&spawnQueue>0){spawnClock-=dt;if(spawnClock<=0){makeZombie();spawnQueue--;spawnClock=Math.max(.8,2.8-round*.07)}}
 if(!roundActive&&roundTimer>0){roundTimer-=dt;if(roundTimer<=0)startRound()}
 for(let i=effects.length-1;i>=0;i--){const e=effects[i];e.life-=dt;if(e.life<=0){if(e.callback)e.callback();else scene.remove(e.mesh);effects.splice(i,1)}}
 for(const t of turrets){t.life-=dt;t.cool-=dt;if(t.life<=0){scene.remove(t.mesh);turrets.splice(turrets.indexOf(t),1);continue}if(t.cool<=0){let closest=null,dd=9;for(const z of zombies)if(z.alive){const d=z.group.position.distanceTo(t.mesh.position);if(d<dd){dd=d;closest=z}}if(closest){damageZombie(closest,30,false);t.mesh.lookAt(closest.group.position);t.cool=.25}}}
 if(!equipmentReady){equipmentTimer-=dt;if(equipmentTimer<=0)equipmentReady=true}
 // nearest interaction prompt
 let nearest=null,nd=3.0001;for(const it of interactives){if(it.used)continue;const d=player.pos.distanceTo(new THREE.Vector3(it.pos.x,player.pos.y,it.pos.z));if(d<nd){nd=d;nearest=it}}
 for(const w of windowZones){const d=player.pos.distanceTo(new THREE.Vector3(w.pos.x,player.pos.y,w.pos.z));if(w.boards<3&&d<nd){nd=d;nearest={name:'Repair Barrier',type:'window'}}}
 $('prompt').textContent=nearest?`E — ${nearest.name}${nearest.cost?` [${nearest.cost} PTS]`:''}`:'';
 $('points').textContent=`${points} PTS`;$('health').textContent=`HEALTH ${Math.ceil(health)}`;$('ammo').textContent=`${ammo} / ${reserve===Infinity?'∞':reserve}`;$('weaponName').textContent=weapon.toUpperCase();$('equipmentHud').textContent=equipmentReady?equipment.toUpperCase():'RECHARGING';
}
let touchSprint=false;
function animate(){if(!started)return;requestAnimationFrame(animate);const dt=Math.min(clock.getDelta(),.04);update(dt);renderer.render(scene,camera)}
function begin(){
 weapon=$('weaponChoice').value;equipment=$('equipmentChoice').value;ammo=weapon==='rk5'?15:8;clipMax=weapon==='rk5'?15:8;reserve=weapon==='m1911'?Infinity:60;powerOn=mode==='free';menu.hidden=true;game.hidden=false;started=true;mobile=('ontouchstart'in window)||navigator.maxTouchPoints>0;
 buildWorld();clock=new THREE.Clock();if(mobile)$('mobileControls').hidden=false;animate();
}
document.querySelectorAll('[data-mode]').forEach(b=>b.addEventListener('click',()=>{mode=b.dataset.mode;modeScreen.hidden=true;loadoutScreen.hidden=false}));
$('startGame').addEventListener('click',begin);
window.addEventListener('resize',()=>{if(!camera||!renderer)return;camera.aspect=innerWidth/innerHeight;camera.updateProjectionMatrix();renderer.setSize(innerWidth,innerHeight)});
window.addEventListener('keydown',e=>{keysPressed[e.code]=true;if(e.code==='KeyE')interact();if(e.code==='KeyR')reload();if(e.code==='KeyQ'){clearTimeout(reloadTimer);reloading=false;weapon=weapon==='m1911'?'rk5':'m1911';clipMax=weapon==='m1911'?8:15;ammo=Math.min(ammo,clipMax);reserve=weapon==='m1911'?Infinity:60}if(e.code==='Space')e.preventDefault();if(e.code==='KeyG')throwEquipment('frag');if(e.code==='KeyF')throwEquipment('acid');if(e.code==='KeyV')throwEquipment('sentry');
 const seq=['KeyY','KeyU','KeyI','KeyO','KeyP'];cheatSequence=(cheatSequence+e.code+' ').slice(-35);if(cheatSequence.includes(seq.join(' '))){isEasterEggActive=true;$('cheats').hidden=false;if(document.pointerLockElement)document.exitPointerLock();for(const z of zombies)if(z.alive){z.head.material=new THREE.MeshBasicMaterial({map:makeFaceTexture()});const c=document.createElement('canvas');}notice('HE IS WATCHING...')}}
);
window.addEventListener('keyup',e=>keysPressed[e.code]=false);
function makeFaceTexture(){const c=document.createElement('canvas');c.width=128;c.height=128;const x=c.getContext('2d');x.fillStyle='#d9a06f';x.beginPath();x.arc(64,68,42,0,Math.PI*2);x.fill();x.fillStyle='#171313';for(let i=0;i<90;i++){const a=Math.random()*Math.PI*2,r=42+Math.random()*9;x.beginPath();x.arc(64+Math.cos(a)*r,62+Math.sin(a)*r,4,0,Math.PI*2);x.fill()}x.fillStyle='#222';x.beginPath();x.arc(48,62,4,0,7);x.arc(80,62,4,0,7);x.fill();x.strokeStyle='#642d25';x.lineWidth=3;x.beginPath();x.arc(64,75,15,.2,Math.PI-.2);x.stroke();return new THREE.CanvasTexture(c)}
document.querySelectorAll('[data-cheat]').forEach(b=>b.addEventListener('click',()=>{const c=b.dataset.cheat;if(c==='points')points=99999;if(c==='god'){godMode=!godMode;b.textContent=`God Mode: ${godMode?'ON':'OFF'}`}if(c==='doors'){for(const i of interactives)if(i.type==='debris')i.cost=0;notice('DOORS UNLOCKED')}if(c==='ray'){weapon='ray gun';clipMax=20;ammo=20;reserve=100}}));
$('closeCheats').addEventListener('click',()=>$('cheats').hidden=true);
game.addEventListener('click',()=>{if(started&&!mobile&&$('cheats').hidden)document.body.requestPointerLock?.()});
document.addEventListener('pointerlockchange',()=>{});
document.addEventListener('mousemove',e=>{if(document.pointerLockElement===document.body){yaw-=e.movementX*.002;pitch-=e.movementY*.002;pitch=Math.max(-1.45,Math.min(1.45,pitch))}});
document.addEventListener('mousedown',e=>{if(e.button===0&&started&&$('cheats').hidden)fire()});
document.querySelectorAll('[data-action]').forEach(b=>{const action=b.dataset.action;const run=()=>{if(action==='fire')fire();if(action==='reload')reload();if(action==='interact')interact();if(action==='jump')keysPressed.Space=true;if(action==='sprint')touchSprint=true;if(action==='frag')throwEquipment('frag');if(action==='acid')throwEquipment('acid');if(action==='deploy')throwEquipment('sentry')};const stop=()=>{if(action==='jump')keysPressed.Space=false;if(action==='sprint')touchSprint=false};b.addEventListener('touchstart',e=>{e.preventDefault();run()},{passive:false});b.addEventListener('touchend',stop);b.addEventListener('click',run)});
const stick=$('stick'),knob=$('stickKnob');let stickId=null,stickRect;
stick.addEventListener('touchstart',e=>{e.preventDefault();stickId=e.changedTouches[0].identifier;stickRect=stick.getBoundingClientRect();moveStick(e.changedTouches[0])},{passive:false});
stick.addEventListener('touchmove',e=>{for(const t of e.changedTouches)if(t.identifier===stickId)moveStick(t)},{passive:false});
function moveStick(t){const cx=stickRect.left+65,cy=stickRect.top+65;let dx=t.clientX-cx,dy=t.clientY-cy;const len=Math.hypot(dx,dy),s=Math.min(1,54/(len||1));dx*=s;dy*=s;joystick={x:dx/54,y:dy/54};knob.style.transform=`translate(${dx}px,${dy}px)`}
stick.addEventListener('touchend',e=>{for(const t of e.changedTouches)if(t.identifier===stickId){stickId=null;joystick={x:0,y:0};knob.style.transform=''}});
const look=$('lookZone');look.addEventListener('touchstart',e=>{const t=e.changedTouches[0];touchLook={id:t.identifier,x:t.clientX,y:t.clientY}},{passive:true});
look.addEventListener('touchmove',e=>{if(!touchLook)return;for(const t of e.changedTouches)if(t.identifier===touchLook.id){yaw-=(t.clientX-touchLook.x)*.005;pitch-=(t.clientY-touchLook.y)*.005;pitch=Math.max(-1.45,Math.min(1.45,pitch));touchLook.x=t.clientX;touchLook.y=t.clientY}},{passive:true});
look.addEventListener('touchend',()=>touchLook=null);
