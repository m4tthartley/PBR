
uniform mat4 projection;
uniform vec3 camera_position;
uniform mat4 camera;
uniform mat4 rotation;
uniform mat4 translation;

uniform sampler2D env_map;
uniform sampler2D spec_map;

vec3 sample_equirectangle(sampler2D tex, vec3 n) {
	vec3 v = n;
	vec2 uv = vec2(atan(v.z, v.x), asin(v.y));
	uv *= vec2(0.1591, 0.3183);
	uv += 0.5;
	uv.y *= -1;
	return texture(tex, uv).rgb;
}

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
vec3 brdf_fresnel_roughness(vec3 h, vec3 v, vec3 f0, float roughness) {
	float costheta = max(dot(h, v), 0.0f);
	return f0 + ((max(vec3(1.0f - roughness), f0) - f0) * pow(1.0 - costheta, 5.0f));
}
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

float brdf_geometry_sub_ibl(float ndotv, float k) {
	return ndotv / (ndotv * (1.0f - k) + k);
}
float brdf_geometry_ibl(vec3 n, vec3 v, vec3 l, float roughness) {
	float ndotl = max(dot(n, l), 0.0f);
	float ndotv = max(dot(n, v), 0.0f);

	float k = roughness;
	k = (k*k) / 2.0;

	float ggx0 = brdf_geometry_sub_ibl(ndotv, k);
	float ggx1 = brdf_geometry_sub_ibl(ndotl, k);

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

vec3 importance_sample_ggx(vec2 xi, vec3 n, float roughness) {
	float a = roughness*roughness;
	float phi = 2.0 * PI * xi.x;
	float costheta = sqrt((1.0 - xi.y) / (1.0 + (a*a - 1.0) * xi.y));
	float sintheta = sqrt(1.0 - costheta*costheta);

	vec3 h = vec3(cos(phi) * sintheta, sin(phi) * sintheta, costheta);
	vec3 up = abs(n.z) < 0.999 ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0);
	vec3 tangent = normalize(cross(up, n));
	vec3 bitangent = cross(n, tangent);

	return normalize(tangent * h.x + bitangent * h.y + n * h.z);
}

vec2 hammersley(uint i, uint n) {
	uint bits = i;

	bits = (bits << 16u) | (bits >> 16u);
	bits = ((bits & 0x55555555u) << 1u) | ((bits & 0xAAAAAAAAu) >> 1u);
	bits = ((bits & 0x33333333u) << 2u) | ((bits & 0xCCCCCCCCu) >> 2u);
	bits = ((bits & 0x0F0F0F0Fu) << 4u) | ((bits & 0xF0F0F0F0u) >> 4u);
	bits = ((bits & 0x00FF00FFu) << 8u) | ((bits & 0xFF00FF00u) >> 8u);
	float radical_inverse = float(bits) * 2.3283064365386963e-10;

	return vec2(float(i)/float(n), radical_inverse);
}

vec3 specular_env_map(vec3 n, float roughness) {
	vec3 r = n;
	vec3 v = r;

	const uint SAMPLE_COUNT = 100u;
	float totalWeight = 0.0;   
	vec3 prefilteredColor = vec3(0.0);     
	for(uint i = 0u; i < SAMPLE_COUNT; ++i) {
		vec2 xi = hammersley(i, SAMPLE_COUNT);
		vec3 h = importance_sample_ggx(xi, n, roughness);
		vec3 l = normalize(2.0 * dot(v, h) * h - v);

		float NdotL = max(dot(n, l), 0.0);
		if(NdotL > 0.0) {
			prefilteredColor += sample_equirectangle(spec_map, l).rgb * NdotL;
			totalWeight += NdotL;
		}
	}
	prefilteredColor = prefilteredColor / totalWeight;

	return prefilteredColor;
}

vec2 integrate_brdf(float NdotV, float roughness) {
    vec3 V;
    V.x = sqrt(1.0 - NdotV*NdotV);
    V.y = 0.0;
    V.z = NdotV;

    float A = 0.0;
    float B = 0.0;

    vec3 N = vec3(0.0, 0.0, 1.0);

    const uint SAMPLE_COUNT = 100u;
    for(uint i = 0u; i < SAMPLE_COUNT; ++i)
    {
        vec2 Xi = hammersley(i, SAMPLE_COUNT);
        vec3 H  = importance_sample_ggx(Xi, N, roughness);
        vec3 L  = normalize(2.0 * dot(V, H) * H - V);

        float NdotL = max(L.z, 0.0);
        float NdotH = max(H.z, 0.0);
        float VdotH = max(dot(V, H), 0.0);

        if(NdotL > 0.0)
        {
            float G = brdf_geometry_ibl(N, V, L, roughness);
            float G_Vis = (G * VdotH) / (NdotH * NdotV);
            float Fc = pow(1.0 - VdotH, 5.0);

            A += (1.0 - Fc) * G_Vis;
            B += Fc * G_Vis;
        }
    }
    A /= float(SAMPLE_COUNT);
    B /= float(SAMPLE_COUNT);
    return vec2(A, B);
}

#ifdef SHADER_PIXEL
in vec3 ex_position;
in vec3 ex_position_from_camera;
in vec3 ex_normal;
out vec4 pixel;
void main() {
	//vec3 albedo = /*material.albedo*/vec3(1.0, 0.05, 0.05);
	vec3 albedo = vec3(0.0, 0.1, 0.1);
	float roughness = material.roughness * (0.9) + 0.05;
	float metallic = material.metallic * (0.9) + 0.05;

	vec3 f0 = mix(vec3(0.04f), albedo, metallic);
	vec3 v = -normalize(ex_position - camera_position);
	vec3 n = normalize(ex_normal);
	float ndotv = max(dot(n, v), 0.0f);

	vec3 Lo = vec3(0.0);
	for (int i = 0; i < NUM_LIGHTS; ++i) {
		vec3 light_dir = normalize(lights[i].position - ex_position);
		float light_dist = length(lights[i].position - ex_position);
		vec3 radiance = vec3(30.0) * lights[i].color * (1.0 / (light_dist*light_dist));

		vec3 l = light_dir;
		vec3 h = normalize(v + l);

		/*if (dot(n, v) > 0.999) {
			pixel = vec4(0.0, 1.0, 0.0, 1.0);
			return;
		}*/

		float ndotl = max(dot(n, l), 0.0f);
				
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

	vec3 ks = brdf_fresnel_roughness(n, v, f0, roughness);
	vec3 kd = 1.0 - ks;
	vec3 irradiance = sample_equirectangle(env_map, n);

	/*vec3 ambient = vec3(0.03) * albedo;*/
	vec3 diffuse = kd * irradiance * albedo;

	vec3 pre_color = specular_env_map(reflect(-v, n), roughness);
	vec2 brdf = integrate_brdf(ndotv, roughness);
	vec3 specular = pre_color * (ks * brdf.x + brdf.y);

	vec3 ambient = (kd * diffuse + specular);

	vec3 output = ambient + Lo;
	output = output / (output + vec3(1.0f));
	output = pow(output, vec3(1.0f/2.2f));

	pixel = vec4(output, 1.0f);

	
	// pixel = vec4(specular, 1.0);
	// pixel = vec4(, 0.0, 1.0);

}
#endif
