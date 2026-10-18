#version 410 core
layout(location = 0) in vec3 aPos;
layout(location = 1) in vec3 aNormal;
layout(location = 2) in vec2 aUV;
layout(location = 3) in vec3 iPos;
layout(location = 4) in vec3 iVel;
uniform mat4 uViewProj;
out vec2 vUV;
out vec3 vTint;
void main() {
    vec3 world = aPos * 0.16 + iPos;
    vUV = aUV;
    vTint = mix(vec3(0.30, 0.60, 1.00), vec3(1.00, 0.45, 0.15), clamp(length(iVel) * 0.08, 0.0, 1.0));
    gl_Position = uViewProj * vec4(world, 1.0);
}
