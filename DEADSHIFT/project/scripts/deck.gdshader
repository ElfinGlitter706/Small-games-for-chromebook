shader_type spatial;
uniform bool lightweight = false;
uniform vec4 steel : source_color = vec4(0.24,0.29,0.31,1.0);
uniform vec4 rust : source_color = vec4(0.44,0.34,0.26,1.0);
varying vec3 world;
float hash21(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise2(vec2 p) {
	vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(hash21(i),hash21(i+vec2(1,0)),f.x),mix(hash21(i+vec2(0,1)),hash21(i+1.0),f.x),f.y);
}
void vertex() { world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
	vec2 uv=world.xz;
	vec2 cell=fract(uv/vec2(2.4,1.2));
	vec2 edge=min(cell,1.0-cell)*vec2(2.4,1.2);
	float joint=smoothstep(0.006,0.018,min(edge.x,edge.y));
	float patina=lightweight ? (0.5+0.10*fract(uv.x*.81+uv.y*.52)) : noise2(uv*.9)*.52+noise2(uv*3.3)*.28+noise2(uv*18.0)*.2;
	float rivet=1.0-smoothstep(.012,.022,length(edge-vec2(.065)));
	vec3 base=mix(steel.rgb,rust.rgb,smoothstep(.46,.77,patina)*.7);
	ALBEDO=base*(.72+.45*patina)*mix(.43,1.0,joint)+rivet*.08;
	ROUGHNESS=.78+.16*patina;
}
