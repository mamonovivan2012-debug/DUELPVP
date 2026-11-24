shader_type canvas_item;
render_mode blend_mix;

uniform float time = 0.0;
uniform vec4 accent_color : source_color = vec4(0.55, 0.25, 0.9, 1.0);
uniform float intensity : hint_range(0.0, 2.0) = 1.0;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
    vec2 uv = UV;
    float wave = sin(uv.y * 17.0 + time * 2.2) * 0.006 + sin(uv.x * 23.0 - time * 1.6) * 0.004;
    uv.x += wave * (0.3 + uv.y);
    vec4 tex = texture(TEXTURE, uv) * COLOR;
    float noise = hash(floor(UV * 90.0 + vec2(time * 3.0, -time * 2.0)));
    float pulse = 0.78 + 0.22 * sin(time * 3.0 + UV.y * 13.0);
    float edge = max(texture(TEXTURE, uv + vec2(TEXTURE_PIXEL_SIZE.x * 2.0, 0.0)).a,
                     texture(TEXTURE, uv + vec2(0.0, TEXTURE_PIXEL_SIZE.y * 2.0)).a) - tex.a;
    vec3 void_tint = accent_color.rgb * (0.07 + noise * 0.07) * pulse * intensity;
    tex.rgb = mix(tex.rgb, tex.rgb * vec3(0.76, 0.66, 0.95), 0.22) + void_tint;
    tex.rgb += accent_color.rgb * edge * (0.55 + 0.25 * pulse) * intensity;
    tex.a *= 0.96 + noise * 0.04;
    COLOR = tex;
}
