
uniform mat4 projection;
uniform mat4 camera;
uniform mat4 rotation;
uniform mat4 translation;
uniform vec4 light_position;

uniform vec4 color;
uniform float roughness;
uniform float metallic;

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
		vec3 p = gl_in[i].gl_Position.xyz * 0.5f;
		ex_position = (translation * rotation * vec4(p, 1.0f)).xyz;
		ex_normal = normalize((rotation * gl_in[i].gl_Position).xyz);
		gl_Position = projection * (translation * camera * rotation * vec4(p, 1.0f));
		EmitVertex();
	}
}
#endif

#define PI 3.14159265359f
//float roughness = 0.5f;
vec3 fresnel_plastic_high = vec3(0.05f, 0.05f, 0.05f);
//float metalness = 0.0f;

//							v this should be HdotV
vec3 fresnel_schlick(float hdotv, vec3 f0) {
	f0 = mix(f0, color.rgb, metallic);
	return f0 + ((1.0f - f0)*pow(1 - hdotv, 5.0f));
}

float schlick_ggx(float ndotv, float k) {
	return ndotv / (ndotv * (1.0f - k) + k);
}

float smith_ggx(float ndotv, float ndotl) {
	float k = (roughness + 1);
	k = (k*k) / 8;

	float ggx0 = schlick_ggx(ndotv, k);
	float ggx1 = schlick_ggx(ndotl, k);

	return ggx0 * ggx1;
}

float trowbridge_reitz_ggx(float ndoth, float roughness) {
	float ndoth2 = ndoth*ndoth;
	float a = roughness*roughness;
	float a2 = (a*a);

	float denom = ndoth2 * (a2-1.0f) + 1.0f;

	return a2 / (PI * denom * denom);
}

vec3 cook_torrance(vec3 p, vec3 n, float ndotl, float ndotv, float ndoth, float hdotv) {
	vec3 fresnel = fresnel_schlick(hdotv, vec3(0.04f)/*fresnel_plastic_high*/);
	vec3 kd = vec3(1.0f) - fresnel;
	kd *= 1.0f - metallic;
	vec3 ks = fresnel;
	vec3 lambert = color.xyz / PI;
	//vec3 cookt_lambert = kd*lambert;

	float D = trowbridge_reitz_ggx(ndoth, roughness) ;
	vec3 F = /*vec3(1)*/fresnel;
	float G = ( smith_ggx(ndotv, ndotl) );
	vec3 cookt_specular = (D*F*G) / ((4 * ndotv * ndotl) + 0.001f)/*prevent divide by zero?*/;
	//cookt_specular /= ;

	return (kd*lambert + /*ks**/cookt_specular) * ndotl;
	//return cookt_specular;
		
	//float result = (d*f*g) / (4*dot(wo, n)*dot(wi, n));
}

#ifdef SHADER_PIXEL
in vec3 ex_position;
in vec3 ex_normal;
out vec4 pixel;
void main() {
	vec4 light_pos = light_position;
	vec3 light_dir = normalize(light_pos.xyz - ex_position);

	// float light_out = cook_torrance(p, wi, wo, n);
	// float light_out = fr(p, wi, wo) * li(p, wi) * dot(n, wi) * dw;
	
	vec3 p = ex_position;
	vec3 v = -normalize((camera * vec4(ex_position, 1.0f)).xyz);
	vec3 l = light_dir;
	vec3 n = ex_normal;
	vec3 h = normalize(v + l);

	float ndotl = max(dot(n, l), 0.0f);
	float ndotv = max(dot(n, v), 0.0f);
	float ndoth = max(dot(n, h), 0.0f);
	float hdotv = max(dot(h, v), 0.0f);
	vec3 Lo = cook_torrance(p, n, ndotl, ndotv, ndoth, hdotv);
	vec3 ambient = vec3(0.03) * color.rgb;

	vec3 output = ambient + Lo;
	output = output / (output + vec3(1.0f));
	output = pow(output, vec3(1.0f/2.0f));

	pixel = vec4(output, 1.0f);

	//float light = dot(light_dir, ex_normal);
}
#endif
