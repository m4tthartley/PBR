
uniform mat4 projection;
uniform vec3 camera_position;
uniform mat4 camera;
uniform mat4 rotation;
uniform mat4 translation;

struct Light {
	vec3 position;
	vec3 color;
};

#define NUM_LIGHTS 4
uniform Light lights[NUM_LIGHTS];

uniform struct {
	vec3 albedo;
	float roughness;
	float metallic;
} material;


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
out vec3 ex_position_from_camera;
out vec3 ex_normal;
void main() {
	for (int i = 0; i < 3; ++i) {
		vec3 p = gl_in[i].gl_Position.xyz * 0.5f;
		ex_position = (translation * rotation * vec4(p, 1.0f)).xyz;
		ex_normal = normalize((rotation * gl_in[i].gl_Position).xyz);
		gl_Position = projection * (camera * translation * rotation * vec4(p, 1.0f));
		EmitVertex();
	}
}
#endif

#define PI 3.14159265359f
//vec3 fresnel_plastic_high = vec3(0.05f, 0.05f, 0.05f);

// Fresnel-Schlick
vec3 brdf_fresnel(vec3 h, vec3 v, vec3 f0) {
	float costheta = max(dot(h, v), 0.0f);
	return f0 + ((1.0f - f0)*pow(1 - costheta, 5.0f));
}

// Schlick-GGX
float brdf_geometry_sub(float ndotv, float k) {
	return ndotv / (ndotv * (1.0f - k) + k);
}
float brdf_geometry(vec3 n, vec3 v, vec3 l, float roughness) {
	float ndotl = max(dot(n, l), 0.0f);
	float ndotv = max(dot(n, v), 0.0f);

	float k = (roughness + 1.0);
	k = (k*k) / 8.0;

	float ggx0 = brdf_geometry_sub(ndotv, k);
	float ggx1 = brdf_geometry_sub(ndotl, k);

	return ggx0 * ggx1;
}

// Trowbridge-Reitz GGX
float brdf_distribution(vec3 n, vec3 h, float roughness) {
	float ndoth = max(dot(n, h), 0.0f);

	float ndoth2 = ndoth*ndoth;
	float a = roughness*roughness;
	float a2 = (a*a);

	float denom = ndoth2 * (a2-1.0f) + 1.0f;

	return a2 / (PI * denom * denom);
}

#ifdef SHADER_PIXEL
in vec3 ex_position;
in vec3 ex_position_from_camera;
in vec3 ex_normal;
out vec4 pixel;
void main() {
	vec3 albedo = material.albedo;
	float roughness = material.roughness * (0.9) + 0.05;
	float metallic = material.metallic;

	vec3 Lo = vec3(0.0);
	for (int i = 0; i < NUM_LIGHTS; ++i) {
		vec3 light_dir = normalize(lights[i].position - ex_position);
		float light_dist = length(lights[i].position - ex_position);
		vec3 radiance = vec3(300.0) * lights[i].color * (1.0 / (light_dist*light_dist));

		vec3 v = -normalize(ex_position - camera_position);
		vec3 l = light_dir;
		vec3 n = normalize(ex_normal);
		vec3 h = normalize(v + l);

		/*if (dot(n, v) > 0.999) {
			pixel = vec4(0.0, 1.0, 0.0, 1.0);
			return;
		}*/

		float ndotl = max(dot(n, l), 0.0f);
		float ndotv = max(dot(n, v), 0.0f);
		
		vec3 f0 = mix(vec3(0.04f), albedo, metallic);
		vec3 fresnel = brdf_fresnel(h, v, f0);
		vec3 kd = vec3(1.0f) - fresnel;
		kd *= 1.0f - metallic;
		vec3 lambert = albedo / PI;
			
		float D = brdf_distribution(n, h, roughness);
		vec3 F = fresnel;
		float G = (brdf_geometry(n, v, l, roughness));
		vec3 specular = (D*F*G) / ((4 * ndotv * ndotl) + 0.001f)/*prevent divide by zero?*/;
			
		Lo += (kd*lambert + specular) * radiance * ndotl;
	}

	vec3 ambient = vec3(0.03) * albedo;
	vec3 output = ambient + Lo;
	output = output / (output + vec3(1.0f));
	output = pow(output, vec3(1.0f/2.2f));

	pixel = vec4(output, 1.0f);
}
#endif
