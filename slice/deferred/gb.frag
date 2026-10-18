#version 410 core
in vec3 vNormal;
in vec2 vUV;
uniform sampler2D uTexture;
layout(location = 0) out vec4 oAlbedo;
layout(location = 1) out vec4 oNormal;
void main() {
    vec4 c = texture(uTexture, vUV);
    oAlbedo = vec4(c.rgb, 1.0);
    oNormal = vec4(normalize(vNormal) * 0.5 + 0.5, 1.0);
}
