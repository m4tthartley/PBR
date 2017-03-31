
//#pragma warning(disable: 4244 4047 4024 4267 4133)

#pragma comment(lib, "opengl32.lib")

#include "w:/libs/rain.c"
#include "w:/libs/math.c"
#include "w:/libs/gfx.c"

typedef struct {
	float3 v[3];
} Triangle;
typedef struct {
	Triangle tris[1024*100];
	int count;
	int tess_level;
	int current_level;
} TriangleList;

void add_tess_triangle(TriangleList *list, Triangle tri) {
	++list->current_level;

	tri.v[0] = normalize(tri.v[0]);
	tri.v[1] = normalize(tri.v[1]);
	tri.v[2] = normalize(tri.v[2]);

	float3 l0 = sub3(tri.v[1], tri.v[0]);
	float3 l1 = sub3(tri.v[2], tri.v[1]);
	float3 l2 = sub3(tri.v[0], tri.v[2]);
	float3 h0 = add3(tri.v[0], div3f(l0, 2.0f));
	float3 h1 = add3(tri.v[1], div3f(l1, 2.0f));
	float3 h2 = add3(tri.v[2], div3f(l2, 2.0f));

	float3 v0 = tri.v[0];
	float3 v1 = tri.v[1];
	float3 v2 = tri.v[2];
	h0 = normalize(h0);
	h1 = normalize(h1);
	h2 = normalize(h2);

	if (list->current_level < list->tess_level) {
		/*add_vert(v0);
		add_vert(h0);
		add_vert(h2);
		add_vert(h0);
		add_vert(v1);
		add_vert(h1);
		add_vert(h2);
		add_vert(h1);
		add_vert(v2);
		add_vert(h0);
		add_vert(h1);
		add_vert(h2);*/

		add_tess_triangle(list, {v0, h0, h2});
		add_tess_triangle(list, {h0, v1, h1});
		add_tess_triangle(list, {h2, h1, v2});
		add_tess_triangle(list, {h0, h1, h2});
	} else {
		if (list->count < array_size(list->tris)-4) {
			list->tris[list->count++] = {v0, h0, h2};
			list->tris[list->count++] = {h0, v1, h1};
			list->tris[list->count++] = {h2, h1, v2};
			list->tris[list->count++] = {h0, h1, h2};
		}
	}

	--list->current_level;
}

void add_triangle(TriangleList *list, Triangle tri) {
	if (list->tess_level) {
		add_tess_triangle(list, tri);
	} else {
		list->tris[list->count++] = {tri.v[0], tri.v[1], tri.v[2]};
	}
}

int CALLBACK WinMain(HINSTANCE hinstnace, HINSTANCE prev_instance, LPSTR lpcmdline, int showcmd) {
	Rain rain = {0};
	rain.window_width = 1280;
	rain.window_height = 720;
	rain_init(&rain);

	load_opengl_extensions();
	glEnable(GL_DEPTH_TEST);
	glFrontFace(GL_CW);
	//glEnable(GL_CULL_FACE);
	glCullFace(GL_BACK);

	GLuint shader = shader_from_string(
		"#version 330\n"
		"in vec3 position;\n"
		"in vec3 normal;\n"
		"uniform mat4 projection;\n"
		"uniform mat4 camera;\n"
		"uniform mat4 rotation;\n"
		"out vec3 ex_normal;\n"
		"void main() {\n"
		"	//gl_Position = projection * (camera * rotation * vec4(position, 1.0f));\n"
		"	gl_Position = vec4(position, 1.0f);\n"
		"	ex_normal = normal;\n"
		"\n"
		"\n"
		"\n"
		"\n"
		"\n"
		"\n"
		"\n"
		"\n"
		"}\n",

		"#version 330\n"
		"in vec3 ex_normal;\n"
		"out vec4 pixel;\n"
		"void main() {\n"
		"	float light = dot(ex_normal, normalize(vec3(1.0f, 1.0f, 1.0f)))*0.75f + 0.25f;\n"
		"	pixel = vec4(1.0f*light, 1.0f*light, 1.0f*light, 1.0f);\n"
		"}\n"
		"\n"
		"\n"
		"\n"
		"\n"
		"\n",

		"#version 330\n"
		"layout(triangles) in;\n"
		"layout(triangle_strip, max_vertices = 3) out;\n"
		"uniform mat4 projection;\n"
		"uniform mat4 camera;\n"
		"uniform mat4 rotation;\n"
		"out vec3 ex_normal;\n"
		"void main() {\n"
		/*"	ex_normal = normalize(cross(gl_in[2].gl_Position.xyz - gl_in[0].gl_Position.xyz, gl_in[1].gl_Position.xyz - gl_in[0].gl_Position.xyz));\n"
		"	ex_normal = (rotation * vec4(ex_normal, 0.0f)).xyz;\n"
		"	gl_Position = projection * (camera * rotation * gl_in[0].gl_Position);\n"
		"	EmitVertex();\n"
		"	gl_Position = projection * (camera * rotation  * gl_in[1].gl_Position);\n"
		"	EmitVertex();\n"
		"	gl_Position = projection * (camera * rotation  * gl_in[2].gl_Position);\n"
		"	EmitVertex();\n"*/
		"	ex_normal = (rotation * vec4(normalize(gl_in[0].gl_Position.xyz), 0.0f)).xyz;\n"
		"	gl_Position = projection * (camera * rotation * gl_in[0].gl_Position);\n"
		"	EmitVertex();\n"
		"	ex_normal = (rotation * vec4(normalize(gl_in[1].gl_Position.xyz), 0.0f)).xyz;\n"
		"	gl_Position = projection * (camera * rotation  * gl_in[1].gl_Position);\n"
		"	EmitVertex();\n"
		"	ex_normal = (rotation * vec4(normalize(gl_in[2].gl_Position.xyz), 0.0f)).xyz;\n"
		"	gl_Position = projection * (camera * rotation  * gl_in[2].gl_Position);\n"
		"	EmitVertex();\n"
		"	EndPrimitive();\n"
		"}\n"
		"\n"
		"\n"
		"\n"
		"\n"
		"\n"
		"\n"
		"\n"
		"\n"
		"\n"
		"\n"
		"\n"
	);

	GLuint normal_shader = shader_from_string(
		"#version 330\n"
		"in vec3 position;\n"
		"void main() {\n"
		"	gl_Position = vec4(position, 1.0f);\n"
		"}\n",

		"#version 330\n"
		"in vec3 ex_normal;\n"
		"out vec4 pixel;\n"
		"void main() {\n"
		"	pixel = vec4(1.0f, 0.0f, 1.0f, 1.0f);\n"
		"}\n",

		"#version 330\n"
		"layout(triangles) in;\n"
		"layout(line_strip, max_vertices = 3) out;\n"
		"uniform mat4 projection;\n"
		"uniform mat4 camera;\n"
		"uniform mat4 rotation;\n"
		"out vec3 ex_normal;\n"
		"void main() {\n"
		"	ex_normal = normalize(cross(gl_in[2].gl_Position.xyz - gl_in[0].gl_Position.xyz, gl_in[1].gl_Position.xyz - gl_in[0].gl_Position.xyz));\n"
		"	//gl_Position = gl_in[0].gl_Position.xyz;\n"
		"	//EmitVertex();\n"
		"	gl_Position = projection * (camera * rotation * gl_in[0].gl_Position);\n"
		"	EmitVertex();\n"
		"	gl_Position = projection * (camera * rotation * (gl_in[0].gl_Position + vec4(ex_normal*0.1f, 0.0f)));\n"
		"	EmitVertex();\n"
		"	//gl_Position = projection * (camera * rotation  * gl_in[1].gl_Position);\n"
		"	//EmitVertex();\n"
		"	//gl_Position = projection * (camera * rotation  * gl_in[2].gl_Position);\n"
		"	//EmitVertex();\n"
		"	EndPrimitive();\n"
		"}\n"
		"\n"
		"\n"
		"\n"
		"\n"
		"\n"
		"\n"
		"\n"
		"\n"
		"\n"
		"\n"
		"\n"
	);

	float3 rotation = {};
	TriangleList *tri_list = (TriangleList*)malloc(sizeof(TriangleList));

	float3 v0 = make_float3(0.0f, 1.0f, 0.0f);
	float3 v1 = make_float3(1.0f, 0.0f, 1.0f);
	float3 v2 = make_float3(-1.0f, 0.0f, 1.0f);
	memset(tri_list, 0, sizeof(TriangleList));
	tri_list->tess_level = 5;
	add_triangle(tri_list, {v0, v1, v2});
	Triangle t1 = {
		make_float3(0.0f, 1.0f, 0.0f),
		make_float3(-1.0f, 0.0f, 1.0f),
		make_float3(-1.0f, 0.0f, -1.0f)
	};
	add_triangle(tri_list, t1);
	Triangle t2 = {
		make_float3(0.0f, 1.0f, 0.0f),
		make_float3(1.0f, 0.0f, -1.0f),
		make_float3(1.0f, 0.0f, 1.0f)
	};
	add_triangle(tri_list, t2);
	Triangle t3 = {
		make_float3(0.0f, 1.0f, 0.0f),
		make_float3(-1.0f, 0.0f, -1.0f),
		make_float3(1.0f, 0.0f, -1.0f)
	};
	add_triangle(tri_list, t3);

	Triangle t4 = {
		make_float3(-1.0f, 0.0f, 1.0f),
		make_float3(1.0f, 0.0f, 1.0f),
		make_float3(0.0f, -1.0f, 0.0f)
	};
	add_triangle(tri_list, t4);
	Triangle t5 = {
		make_float3(-1.0f, 0.0f, -1.0f),
		make_float3(-1.0f, 0.0f, 1.0f),
		make_float3(0.0f, -1.0f, 0.0f)
	};
	add_triangle(tri_list, t5);
	Triangle t6 = {
		make_float3(1.0f, 0.0f, 1.0f),
		make_float3(1.0f, 0.0f, -1.0f),
		make_float3(0.0f, -1.0f, 0.0f)
	};
	add_triangle(tri_list, t6);
	Triangle t7 = {
		make_float3(1.0f, 0.0f, -1.0f),
		make_float3(-1.0f, 0.0f, -1.0f),
		make_float3(0.0f, -1.0f, 0.0f)
	};
	add_triangle(tri_list, t7);

	while (!rain.quit) {
		rain_update(&rain);

		glClearColor(0.5f, 0.0f, 0.5f, 1.0f);
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

		float3 verts[1024];
		int vert_count = 0;
#define add_vert(v) verts[vert_count++] = v;

		/*add_vert(v0);
		add_vert(v1);
		add_vert(v2);*/

		float3 l0 = sub3(v1, v0);
		float3 l1 = sub3(v2, v1);
		float3 l2 = sub3(v0, v2);
		float3 h0 = add3(v0, div3f(l0, 2.0f));
		float3 h1 = add3(v1, div3f(l1, 2.0f));
		float3 h2 = add3(v2, div3f(l2, 2.0f));

		v0 = normalize(v0);
		v1 = normalize(v1);
		v2 = normalize(v2);
		h0 = normalize(h0);
		h1 = normalize(h1);
		h2 = normalize(h2);

		add_vert(v0);
		add_vert(h0);
		add_vert(h2);

		add_vert(h0);
		add_vert(v1);
		add_vert(h1);

		add_vert(h2);
		add_vert(h1);
		add_vert(v2);

		add_vert(h0);
		add_vert(h1);
		add_vert(h2);

		/*use_shader(0);
		glBegin(GL_POINTS);
		glColor4f(0.0f, 0.0f, 1.0f, 1.0f);
		glVertex3f(h0.x, h0.y, h0.z - 3.0f);
		glVertex3f(h1.x, h1.y, h1.z - 3.0f);
		glVertex3f(h2.x, h2.y, h2.z - 3.0f);
		glEnd();*/


		//float3 v = div3f(add3(add3(v0, v1), v2), 3.0f);

		/*float3 verts[] = {
			0.0f, 1.0f, 0.0f,
			1.0f, -1.0f, 1.0f,
			-1.0f, -1.0f, 1.0f,

			0.0f, 1.0f, 0.0f,
			-1.0f, -1.0f, 1.0f,
			-1.0f, -1.0f, -1.0f,

			0.0f, 1.0f, 0.0f,
			-1.0f, -1.0f, -1.0f,
			1.0f, -1.0f, -1.0f,

			0.0f, 1.0f, 0.0f,
			1.0f, -1.0f, -1.0f,
			1.0f, -1.0f, 1.0f,
		};
		int indices[] = {
			0, 1, 2,
			3, 4, 5,
			6, 7, 8,
			9, 10, 11
		};*/

		rotation.y += 0.01f;

		use_shader(shader);
		mat4 projection = make_perspective_matrix(70, (float)rain.window_width/(float)rain.window_height, 0.1f, 100.0f);
		mat4 camera = mat4_translate(make_float3(0, 0, -2.0f));
		glUniformMatrix4fv(glGetUniformLocation(shader, "projection"), 1, GL_FALSE, projection.e);
		glUniformMatrix4fv(glGetUniformLocation(shader, "camera"), 1, GL_FALSE, camera.e);
		glUniformMatrix4fv(glGetUniformLocation(shader, "rotation"), 1, GL_FALSE, euler_to_mat4(rotation).e);

		glEnableVertexAttribArray(0);
		//glEnableVertexAttribArray(1);
		glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, tri_list->tris);
		glDrawArrays(GL_TRIANGLES, 0, tri_list->count*3);

		use_shader(normal_shader);
		glUniformMatrix4fv(glGetUniformLocation(shader, "projection"), 1, GL_FALSE, projection.e);
		glUniformMatrix4fv(glGetUniformLocation(shader, "camera"), 1, GL_FALSE, camera.e);
		glUniformMatrix4fv(glGetUniformLocation(shader, "rotation"), 1, GL_FALSE, euler_to_mat4(rotation).e);
		glEnableVertexAttribArray(0);
		glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, tri_list->tris);
		//glDrawArrays(GL_TRIANGLES, 0, tri_list.count*3);
	}
}
