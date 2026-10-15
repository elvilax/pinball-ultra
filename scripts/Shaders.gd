extends RefCounted
## Shaders del juego, como texto: perspectiva de la mesa y acabado envejecido.

## Acabado analógico sobre toda la pantalla: menos saturación, tono cálido, viñeta y grano.
const ANALOG := "
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float gray = dot(c, vec3(0.3, 0.59, 0.11));
	c = mix(c, vec3(gray), 0.28);
	c *= vec3(1.05, 1.0, 0.88);
	vec2 d = UV - 0.5;
	c *= 1.0 - dot(d, d) * 1.1;
	vec2 cell = floor(UV * vec2(540.0, 960.0)) + floor(TIME * 10.0) * 7.0;
	float grain = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
	c += (grain - 0.5) * 0.045;
	COLOR = vec4(c, 1.0);
}
"
const PERSPECTIVE := "
shader_type canvas_item;
uniform float depth = 0.22;
void fragment() {
	// Proyección de un plano inclinado: el fondo (arriba) queda más lejos.
	float q = 1.0 - UV.y;
	float s = q / (1.0 + depth - depth * q);
	float z = 1.0 + depth * s;
	vec2 uv = vec2((UV.x - 0.5) * z + 0.5, 1.0 - s);
	if (uv.x < 0.0 || uv.x > 1.0) {
		COLOR = vec4(0.0);
	} else {
		COLOR = texture(TEXTURE, uv);
		// Un poco más oscuro al fondo, para dar profundidad.
		COLOR.rgb *= mix(1.0, 0.78, s * s);
	}
}
"
