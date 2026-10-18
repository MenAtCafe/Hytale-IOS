#version 410 core
in vec2 vUV;
uniform sampler2D uAlbedo;
uniform sampler2D uNormal;
out vec4 oColor;
void main() {
    vec3 albedo = texture(uAlbedo, vUV).rgb;
    vec3 n = normalize(texture(uNormal, vUV).rgb * 2.0 - 1.0);
    vec3 L = normalize(vec3(0.35, 0.9, 0.55));
    float ndl = max(dot(n, L), 0.0);
    oColor = vec4(albedo * (0.30 + 0.95 * ndl), 1.0);
}
