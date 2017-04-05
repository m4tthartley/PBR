
uniform mat4 projection;
uniform vec3 camera_position;
uniform mat4 camera;
//uniform mat4 camera_rotation;
//uniform mat4 camera_rotation_reverse;
uniform mat4 rotation;
uniform mat4 translation;

struct Light {
	vec4 position;
	vec4 color;
};

uniform Light lights[2];

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
out vec3 ex_position_from_camera;
out vec3 ex_normal;
void main() {
	for (int i = 0; i < 3; ++i) {
		vec3 p = gl_in[i].gl_Position.xyz * 0.5f;
		ex_position = (translation * rotation * vec4(p, 1.0f)).xyz;
		//ex_position_from_camera = (camera * translation * rotation * vec4(p, 1.0f)).xyz;
		ex_normal = normalize((rotation * gl_in[i].gl_Position).xyz);
		gl_Position = projection * (camera * translation * rotation * vec4(p, 1.0f) /*+ vec4(camera_position, 0.0)*/);
		EmitVertex();
	}
}
#endif

#define PI 3.14159265359f
//float roughness = 0.5f;
vec3 fresnel_plastic_high = vec3(0.05f, 0.05f, 0.05f);
//float metalness = 0.0f;

//							v this should be HdotV
#if 0
vec3 fresnel_schlick(float hdotv, vec3 f0) {
	f0 = mix(f0, color.rgb, metallic);
	return f0 + ((1.0f - f0)*pow(1 - hdotv, 5.0f));
}

float schlick_ggx(float ndotv, float k) {
	return ndotv / (ndotv * (1.0f - k) + k);
}

float smith_ggx(float ndotv, float ndotl, float roughness) {
	float k = (roughness + 1.0);
	k = (k*k) / 8.0;

	float ggx0 = schlick_ggx(ndotv, k);
	float ggx1 = schlick_ggx(ndotl, k);

	return ggx0 * ggx1;
}

float trowbridge_reitz_ggx(float ndoth, float roughness) {
	float ndoth2 = ndoth*ndoth;
	float a = roughness*roughness /*+ 0.005f*/;
	float a2 = (a*a);

	float denom = ndoth2 * (a2-1.0f) + 1.0f;

	return a2 / (PI * denom * denom);
}
#endif

float DistributionGGX(vec3 N, vec3 H, float roughness)
{
	float a = roughness*roughness;
	float a2 = a*a;
	float NdotH = max(dot(N, H), 0.0);
	float NdotH2 = NdotH*NdotH;

	float nom = a2;
	float denom = (NdotH2 * (a2 - 1.0) + 1.0);
	denom = PI * denom * denom;

	return nom / denom;
}
// ----------------------------------------------------------------------------
float GeometrySchlickGGX(float NdotV, float roughness)
{
	float r = (roughness + 1.0);
	float k = (r*r) / 8.0;

	float nom = NdotV;
	float denom = NdotV * (1.0 - k) + k;

	return nom / denom;
}
// ----------------------------------------------------------------------------
float GeometrySmith(vec3 N, vec3 V, vec3 L, float roughness)
{
	float NdotV = max(dot(N, V), 0.0);
	float NdotL = max(dot(N, L), 0.0);
	float ggx2 = GeometrySchlickGGX(NdotV, roughness);
	float ggx1 = GeometrySchlickGGX(NdotL, roughness);

	return ggx1 * ggx2;
}
// ----------------------------------------------------------------------------
vec3 fresnelSchlick(float cosTheta, vec3 F0)
{
	F0 = mix(F0, color.rgb, metallic);
	return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
}

//vec3 cook_torrance(vec3 p, vec3 n, float ndotl, float ndotv, float ndoth, float hdotv) {
//	
//	//return cookt_specular;
//		
//	//float result = (d*f*g) / (4*dot(wo, n)*dot(wi, n));
//}

#ifdef SHADER_PIXEL
in vec3 ex_position;
in vec3 ex_position_from_camera;
in vec3 ex_normal;
out vec4 pixel;
void main() {
	vec3 Lo = vec3(0.0);
	for (int i = 0; i < 2; ++i) {
		vec4 light_pos = lights[i].position;
		vec3 light_dir = normalize(light_pos.xyz - ex_position);

		// float light_out = cook_torrance(p, wi, wo, n);
		// float light_out = fr(p, wi, wo) * li(p, wi) * dot(n, wi) * dw;

		vec3 p = ex_position;
		//vec3 camera_pos = (camera_rotation_reverse * -vec4(camera_position, 0.0)).xyz;
		vec3 v = -normalize(ex_position - camera_position);
		/*vec3 tp = (translation * vec4(ex_position, 1.0f)).xyz;
		vec3 v = (camera_translation * vec4(tp, 1.0)).xyz;
		v = normalize((-camera * vec4(v, 0.0)).xyz);*/
		//vec3 v = -normalize(ex_position_from_camera);

		//v = camera_position * camera_rotation * /*vec4(0.0, 0.0, 1.0, 1.0)*/ -normalize(vec4(ex_position, 1.0f));

		vec3 l = light_dir;
		vec3 n = normalize(ex_normal);
		vec3 h = normalize(v + l);

		if (dot(n, v) > 0.999) {
			pixel = vec4(0.0, 1.0, 0.0, 1.0);
			return;
		}

		float ndotl = max(dot(n, l), 0.0f);
		float ndotv = max(dot(n, v), 0.0f);
		float ndoth = max(dot(n, h), 0.0f);
		float hdotv = max(dot(h, v), 0.0f);

		float dist = length(lights[i].position.xyz - ex_position);

		{
			vec3 fresnel = fresnelSchlick(hdotv, vec3(0.04f)/*fresnel_plastic_high*/);
			vec3 kd = vec3(1.0f) - fresnel;
			kd *= 1.0f - metallic;
			//vec3 ks = fresnel;
			vec3 lambert = color.xyz / PI;
			//vec3 cookt_lambert = kd*lambert;

			float D = DistributionGGX(n, h, roughness);
			vec3 F = fresnel;
			float G = (GeometrySmith(n, v, l, roughness));
			vec3 cookt_specular = (D*F*G) / ((4 * ndotv * ndotl) + 0.001f)/*prevent divide by zero?*/;
			//cookt_specular /= ;

			Lo += (kd*lambert + cookt_specular) * (vec3(300.0) * (1.0 / (dist*dist))) * ndotl;
			/*float a = dot(n, l);
			if (a < 0.0) a = 0.0;
			Lo += vec3(ndotl);*/
		}
		//Lo += cook_torrance(p, n, ndotl, ndotv, ndoth, hdotv) * (vec3(300.0) * (1.0 / (dist*dist))) * ndotl;
	}

	vec3 ambient = vec3(0.03) * color.rgb;
	vec3 output = ambient + Lo;
	output = output / (output + vec3(1.0f));
	output = pow(output, vec3(1.0f/2.2f));

	///output = normalize(ex_normal);

	pixel = vec4(output, 1.0f);

	//float light = dot(light_dir, ex_normal);
}
#endif
