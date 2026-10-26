shader_type canvas_item;

uniform vec4 color_a : source_color = vec4(0.035, 0.008, 0.10, 1.0);
uniform vec4 color_b : source_color = vec4(0.28, 0.035, 0.52, 1.0);
uniform vec4 color_highlight : source_color = vec4(0.72, 0.18, 0.95, 1.0);
uniform float speed = 0.18;
uniform float scale = 3.2;
uniform float contrast = 1.15;

void fragment() {
    vec2 uv = UV * scale;
    float time = TIME * speed;

    float wave_a = sin(uv.x * 1.15 + time);
    float wave_b = sin(uv.y * 1.35 - time * 1.2);
    float wave_c = sin((uv.x + uv.y) * 1.7 + time * 0.8);
    float wave_d = sin(length(uv - vec2(1.5)) * 3.0 - time * 1.4);

    float plasma = (wave_a + wave_b + wave_c + wave_d) * 0.25;
    plasma = plasma * 0.5 + 0.5;
    plasma = clamp((plasma - 0.5) * contrast + 0.5, 0.0, 1.0);

    vec3 base_color = mix(color_a.rgb, color_b.rgb, plasma);
    float highlight = smoothstep(0.68, 1.0, plasma);
    vec3 final_color = mix(base_color, color_highlight.rgb, highlight * 0.35);

    COLOR = vec4(final_color, 1.0);
}
