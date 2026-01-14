shader_type canvas_item;

// Colore base del pannello
uniform vec4 base_color : source_color = vec4(0.06, 0.10, 0.14, 1.0);
// Colore della cornice
uniform vec4 border_color : source_color = vec4(0.22, 0.90, 0.88, 1.0);
// Colore dei “circuiti” interni
uniform vec4 circuit_color : source_color = vec4(0.12, 0.75, 0.72, 1.0);
// Colore dei dati che scorrono
uniform vec4 data_color : source_color = vec4(1.00, 0.78, 0.88, 1.0);

// Dimensione della porta in pixel
uniform vec2 gate_size = vec2(256.0, 64.0);

// Quante tile contiene la porta (es: 3x1, 4x2, ecc.)
uniform vec2 tiles = vec2(1.0, 1.0);

// Spessore della cornice in PIXEL (uguale su tutti i lati)
uniform float border_px = 1.0;

// Scala del pattern interno (più basso = più grosso)
uniform float pattern_scale = 8.0;

// Velocità dello scorrimento dei “dati”
uniform float data_speed = 1.2;

// Intensità del glow generale
uniform float glow = 1.5;

// Opacità di fondo quando la porta è attiva
uniform float background_alpha = 0.9;

// 0 = spento / quasi trasparente, 1 = acceso
uniform float active = 1.0;


// pseudo-noise
float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}


void fragment() {
	vec2 uv = UV;

	// ==============================
	// 1) BORDO UNICO IN PIXEL
	// ==============================
	// limito lo spessore a dell'altezza,
	float max_border = min(gate_size.y, gate_size.x) * 0.10;
	float effective_border_px = min(border_px, max_border);

	// distanza dal bordo più vicino in pixel
	float dist_x_px = min(uv.x, 1.0 - uv.x) * gate_size.x;
	float dist_y_px = min(uv.y, 1.0 - uv.y) * gate_size.y;
	float dist_px   = min(dist_x_px, dist_y_px);

	// bordo: alto vicino al bordo, 0 verso il centro
	float border_mask = 1.0 - smoothstep(effective_border_px,
	                                     effective_border_px + 1.0,
	                                     dist_px);

	// interno: 0 vicino al bordo, 1 verso il centro
	float inside_mask = smoothstep(effective_border_px + 1.0,
	                               effective_border_px + 3.0,
	                               dist_px);

	vec3 col = base_color.rgb;
	float alpha = background_alpha;

	// ==============================
	// 2) UV PER-TILE (pattern a blocchi)
	// ==============================
	vec2 tile_uv = fract(uv * tiles);

	// ==============================
	// 3) PATTERN A GRIGLIA / CIRCUITI (per tile)
	// ==============================
	vec2 gv = tile_uv * pattern_scale;

	float grid_v = smoothstep(0.0, 0.2, 0.5 - abs(fract(gv.x) - 0.5));
	float grid_h = smoothstep(0.0, 0.2, 0.5 - abs(fract(gv.y) - 0.5));
	float grid = max(grid_v * 0.7, grid_h * 0.7);

	float lane_v = step(0.9, fract(gv.x * 0.25));
	float lane_h = step(0.9, fract(gv.y * 0.25));
	float lanes = max(lane_v, lane_h);

	float n = hash(floor(gv));
	float noise_mask = smoothstep(0.4, 1.0, n);

	vec3 circuit = circuit_color.rgb
		* (grid * 0.6 + lanes * 0.9)
		* noise_mask
		* 1.3;

	// pattern pieno nella zona interna
	col = mix(col, circuit, inside_mask);

	// ==============================
	// 4) DATI CHE SCORRONO (per tile)
	// ==============================
	float t = TIME * data_speed;
	vec2 data_uv = vec2(tile_uv.x * pattern_scale * 0.5,
	                    (tile_uv.y + t) * pattern_scale);

	float band = step(0.85, fract(data_uv.y));
	float col_band = step(0.7, fract(data_uv.x));
	float data_flow = band * col_band;

	float data_noise = hash(floor(data_uv * 1.5));
	data_flow *= smoothstep(0.3, 1.0, data_noise);

	vec2 centered_tile = tile_uv - 0.5;
	float center_falloff = 1.0 - smoothstep(0.2, 0.6, length(centered_tile));
	data_flow *= inside_mask * center_falloff;

	col += data_color.rgb * data_flow * 1.5;

	// ==============================
	// 5) BORDO GLOW
	// ==============================
	vec3 border_col = border_color.rgb * (1.0 + glow * 0.5);
	col = mix(col, border_col, border_mask * glow);
	alpha = mix(alpha, border_color.a, border_mask);

	// ==============================
	// 6) ATTIVAZIONE
	// ==============================
	col *= active;
	alpha *= active;

	if (active < 0.01) {
		alpha *= 0.1;
	}

	COLOR = vec4(col, alpha);
}
