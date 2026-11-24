shader_type canvas_item;
render_mode blend_mix;

uniform float time = 0.0;
uniform vec4 accent_color : source_color = vec4(0.45, 0.72, 0.62, 1.0);
uniform float intensity : hint_range(0.0, 1.0) = 0.38;

void fragment() {
    vec4 tex = texture(TEXTURE, UV) * COLOR;
    float edge = 0.0;
    vec2 px = TEXTURE_PIXEL_SIZE * 1.6;
    float a = texture(TEXTURE, UV + vec2(px.x, 0.0)).a;
    float b = texture(TEXTURE, UV - vec2(px.x, 0.0)).a;
    float c = texture(TEXTURE, UV + vec2(0.0, px.y)).a;
    float d = texture(TEXTURE, UV - vec2(0.0, px.y)).a;
    edge = max(max(a, b), max(c, d)) - tex.a;
    float shimmer = 0.5 + 0.5 * sin(UV.y * 42.0 - time * 1.7);
    vec3 rim = accent_color.rgb * edge * (0.28 + shimmer * 0.22) * intensity;
    tex.rgb += rim;
    COLOR = tex;
}
