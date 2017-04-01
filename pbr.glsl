
uniform mat4 projection;
uniform mat4 camera;
uniform mat4 rotation;
uniform vec4 color;

#ifdef SHADER_VERTEX
in vec3 position;
void main() {
	gl_Position = vec4(position, 1.0f);
}
#endif

#ifdef SHADER_GEOMETRY
layout(triangles) in;
layout(triangle_strip, max_vertices = 3) out;
out vec3 ex_position;
out vec3 ex_normal;
void main() {
	for (int i = 0; i < 3; ++i) {
		ex_position = (rotation * gl_in[i].gl_Position).xyz;
		ex_normal = normalize((rotation * gl_in[i].gl_Position).xyz);
		gl_Position = projection * (camera * rotation * gl_in[i].gl_Position);
		EmitVertex();
	}
}
#endif

#define PI 3.14159265359f
float roughness = 0.5f;

float trowbridge_reitz_ggx(vec3 n, vec3 h, float a) {
	float nh = max(dot(n, h), 0.0f);
	float nh2 = nh*nh;
	float a2 = (a*a);

	float denom = nh2 * (a2-1.0f) + 1.0f;

	return a2 / (PI * denom * denom);
}

vec3 cook_torrance(vec3 p, vec3 wi, vec3 wo, vec3 n) {
	float kd = 0.5f;
	float ks = 1.0f - kd;
	vec3 lambert = color.xyz / PI;
	vec3 cookt_lambert = lambert*kd;

	vec3 h = normalize(wo + -wi/*n + -wi*/);
	float D = trowbridge_reitz_ggx(n, h, roughness);
	float F = 1.0f;
	float G = 1.0f;
	float cookt_specular = (D*F*G);
	//cookt_specular /= (4 * dot(wo, n) * dot(wi, n));

	//return cookt_lambert + ks*cookt_specular;
	return vec3(cookt_specular);
		
	//float result = (d*f*g) / (4*dot(wo, n)*dot(wi, n));
}

#ifdef SHADER_PIXEL
in vec3 ex_position;
in vec3 ex_normal;
out vec4 pixel;
void main() {
	vec3 light_pos = vec3(5.0f, 5.0f, 5.0f);
	vec3 light_dir = normalize(light_pos - ex_position);

	// float light_out = cook_torrance(p, wi, wo, n);
	// float light_out = fr(p, wi, wo) * li(p, wi) * dot(n, wi) * dw;
	
	vec3 p = ex_position;
	vec3 wo = -normalize((camera * vec4(ex_position, 1.0f)).xyz);
	vec3 wi = -light_dir;
	vec3 n = ex_normal;

	vec3 Lo = cook_torrance(p, wi, wo, n) /** dot(n, wi)*/;

	pixel = vec4(Lo, 1.0f);

	//float light = dot(light_dir, ex_normal);
}
#endif
