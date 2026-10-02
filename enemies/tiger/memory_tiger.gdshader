shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D fur_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D roughness_texture : filter_linear_mipmap, repeat_enable;
uniform vec4 main_fur : source_color = vec4(0.145098, 0.172549, 0.160784, 1.0);
uniform vec4 secondary_fur : source_color = vec4(0.274510, 0.325490, 0.294118, 1.0);
uniform vec4 stripe_color : source_color = vec4(0.031373, 0.043137, 0.039216, 1.0);
uniform vec4 memory_color : source_color = vec4(0.396078, 0.839216, 0.764706, 1.0);
uniform vec4 strong_memory_color : source_color = vec4(0.560784, 0.960784, 0.874510, 1.0);
uniform vec4 scar_color : source_color = vec4(0.462745, 0.180392, 0.196078, 1.0);
uniform vec4 nose_color : source_color = vec4(0.090196, 0.082353, 0.074510, 1.0);
uniform float memory_energy : hint_range(0.0, 5.0) = 0.35;
uniform float hit_flash : hint_range(0.0, 1.0) = 0.0;
varying vec3 anatomy_position;

void vertex() {
	anatomy_position = VERTEX;
}

void fragment() {
	vec3 original = texture(fur_texture, UV).rgb;
	float luminance = dot(original, vec3(0.2126, 0.7152, 0.0722));
	float fur = smoothstep(0.045, 0.28, luminance);
	vec3 p = anatomy_position;
	float underside = 1.0 - smoothstep(30.0, 85.0, p.y);
	vec3 tint = mix(main_fur.rgb, secondary_fur.rgb, 0.30 + underside * 0.35);
	float detail = mix(0.72, 1.30, clamp(luminance, 0.0, 1.0));
	vec3 color = mix(stripe_color.rgb, tint * detail, fur);
	float muzzle = smoothstep(100.0, 112.0, p.z) * (1.0 - smoothstep(6.0, 13.0, abs(p.x)));
	float claws = 1.0 - smoothstep(3.0, 8.0, p.y);
	color = mix(color, nose_color.rgb, max(muzzle * (1.0 - fur), claws * (1.0 - fur)));
	float scar_region = exp(-pow((abs(p.x) - 20.0) / 4.0, 2.0) - pow((p.z - 12.0) / 8.0, 2.0) - pow((p.y - 72.0) / 12.0, 2.0));
	float scar = scar_region * step(0.91, sin(p.y * 0.7 + p.z * 0.4) * 0.5 + 0.5);
	color = mix(color, scar_color.rgb, scar * 0.65);
	float face = smoothstep(72.0, 90.0, p.z) * smoothstep(65.0, 85.0, p.y);
	float shoulder = exp(-pow((p.z - 45.0) / 20.0, 2.0) - pow((p.y - 75.0) / 24.0, 2.0));
	float forelegs = exp(-pow((p.z - 42.0) / 18.0, 2.0)) * (1.0 - smoothstep(45.0, 75.0, p.y)) * smoothstep(5.0, 18.0, p.y);
	float traces = step(0.74, sin(p.y * 0.17 + p.z * 0.16 + abs(p.x) * 0.20) * 0.5 + 0.5);
	float markings = (1.0 - fur) * traces * clamp(face * 0.65 + shoulder * 0.85 + forelegs * 0.85, 0.0, 1.0);
	float eyes = exp(-pow((abs(p.x) - 8.0) / 3.5, 2.0) - pow((p.y - 105.0) / 4.5, 2.0) - pow((p.z - 98.0) / 5.0, 2.0));
	float energy_mask = max(markings * 0.55, eyes);
	vec3 glow = mix(memory_color.rgb, strong_memory_color.rgb, clamp(memory_energy / 3.0, 0.0, 1.0));
	ALBEDO = mix(color, glow * 0.45, energy_mask * 0.35);
	ALBEDO = mix(ALBEDO, vec3(0.75, 1.0, 0.94), hit_flash * 0.65);
	EMISSION = glow * energy_mask * memory_energy + vec3(0.75, 1.0, 0.94) * hit_flash * 1.2;
	NORMAL_MAP = texture(normal_texture, UV).rgb;
	NORMAL_MAP_DEPTH = 1.0;
	ROUGHNESS = clamp(texture(roughness_texture, UV).g, 0.65, 1.0);
	SPECULAR = 0.25;
}
