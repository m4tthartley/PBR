
uniform mat4 projection;
uniform vec3 camera_position;
uniform mat4 camera;

uniform vec3 color;
uniform sampler2D equirectangle;

#ifdef SHADER_VERTEX
in vec3 position;
out vec3 ex_position;
void main() {
	gl_Position = projection * (camera * vec4(position, 1.0));
	ex_position = (/*camera **/ vec4(position, 1.0)).xyz;
}
#endif

#ifdef SHADER_PIXEL
out vec4 pixel;
in vec3 ex_position;
void main() {
	vec3 v = normalize(ex_position);
	vec2 uv = vec2(atan(v.z, v.x), asin(v.y));
	uv *= vec2(0.1591, 0.3183);
	uv += 0.5;
	uv.y *= -1;

	vec3 output = texture(equirectangle, uv).rgb;
	output = output / (output + vec3(1.0));
	output = pow(output, vec3(1.0/2.2));
	pixel = vec4(output, 1.0);
}
#endif