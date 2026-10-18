#version 410 core
in vec2 vUV;
in vec3 vTint;
out vec4 oColor;
void main() {
    oColor = vec4(vTint, 0.85);
}
