shader_type sky;

// Procedural nebula: three octaves of value noise over the view direction,
// pushed through a band mask so it reads as gas clouds rather than fog.

uniform float drift_speed = 0.02;
uniform vec3 deep_color : source_color = vec3(0.004, 0.006, 0.018);
uniform vec3 band_color : source_color = vec3(0.020, 0.030, 0.090);
uniform vec3 hot_color : source_color = vec3(0.120, 0.030, 0.180);
uniform vec3 teal_color : source_color = vec3(0.010, 0.080, 0.110);

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash(i), hash(i + vec3(1.0, 0.0, 0.0)), f.x),
			mix(hash(i + vec3(0.0, 1.0, 0.0)), hash(i + vec3(1.0, 1.0, 0.0)), f.x), f.y),
		mix(mix(hash(i + vec3(0.0, 0.0, 1.0)), hash(i + vec3(1.0, 0.0, 1.0)), f.x),
			mix(hash(i + vec3(0.0, 1.0, 1.0)), hash(i + vec3(1.0, 1.0, 1.0)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float a = 0.5;
	float s = 0.0;
	for (int i = 0; i < 5; i++) {
		s += a * vnoise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return s;
}

void sky() {
	vec3 d = EYEDIR;
	float n1 = fbm(d * 2.1 + vec3(0.0, 0.0, TIME * drift_speed));
	float n2 = fbm(d * 4.7 - vec3(3.0, 1.0, 0.0));
	float band = smoothstep(0.34, 0.94, n1);

	vec3 col = deep_color;
	col = mix(col, band_color, band * 0.92);
	col += hot_color * pow(band, 2.0) * 0.62;
	col += teal_color * pow(smoothstep(0.55, 1.0, n2), 2.0) * 0.45;
	col *= 0.80 + 0.45 * n1;

	COLOR = col;
}
