shader_type canvas_item;
void fragment() {
	vec2 offset = (UV - vec2(.5)) * vec2(1.777778,1.);
	float radius = length(offset);
	float edge = smoothstep(.325,.346,radius);
	float crosshair = (1.-step(.0013,min(abs(offset.x),abs(offset.y)))) * step(.008,radius);
	float tick = (1.-step(.0014,abs(mod(abs(offset.y)+.016,.032)-.016))) * (1.-step(.009,abs(offset.x))) * step(.02,offset.y);
	float dot = 1.-smoothstep(.0012,.0026,radius);
	COLOR = vec4(mix(vec3(.025,.048,.055),vec3(.95,.67,.30),dot),max(dot,max(edge*.98,max(crosshair*.85,tick))));
}
