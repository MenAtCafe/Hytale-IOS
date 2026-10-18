#version 410 core
layout(location = 0) in vec3 aPos;
layout(location = 1) in vec3 aNormal;
layout(location = 2) in vec2 aUV;
layout(location = 3) in vec3 iOffset;
layout(location = 4) in float iScale;
layout(location = 5) in vec3 iTint;
uniform mat4 uViewProj;
out vec3 vNormal;
out vec2 vUV;
out vec3 vTint;
void main() {
    vec3 world = aPos * iScale + iOffset;
    vNormal = aNormal;
    vUV = aUV;
    vTint = iTint;
    gl_Position = uViewProj * vec4(world, 1.0);
}
