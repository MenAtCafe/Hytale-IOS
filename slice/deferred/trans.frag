#version 410 core
in vec2 vUV;
uniform sampler2D uTexture;
uniform vec4 uColor;
out vec4 oColor;
void main() {
    vec3 c = texture(uTexture, vUV).rgb;
    oColor = vec4(mix(c, uColor.rgb, 0.6), uColor.a);
}
