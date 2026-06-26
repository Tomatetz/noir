extends Control

var map

func bind(map_ref) -> void:
	map = map_ref
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if map == null or map.game == null:
		return
	_draw_rain()
	_draw_rain_impacts()
	_draw_route_overlay()
	_draw_destination_overlay()
	_draw_hover_card()
	_draw_legend()
	if not map.fullscreen_view:
		_draw_minimap()

func _draw_rain() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var time: float = Time.get_ticks_msec() * 0.001
	var gust_angle: float = -0.22 + sin(time * 0.17) * 0.05
	var base_rain_direction := Vector2(gust_angle, 1.0).normalized()
	var wrap_size := size + Vector2(260.0, 260.0)
	for i in range(map.RAIN_STREAK_COUNT):
		var h1: float = map._hash01(map.rain_seed + i * 37)
		var h2: float = map._hash01(map.rain_seed + i * 53 + 11)
		var h3: float = map._hash01(map.rain_seed + i * 71 + 23)
		var h4: float = map._hash01(map.rain_seed + i * 89 + 41)
		var h5: float = map._hash01(map.rain_seed + i * 97 + 67)
		var rain_direction: Vector2 = base_rain_direction.rotated(lerp(-0.10, 0.10, h4))
		var speed: float = lerp(155.0, 360.0, pow(h3, 0.72))
		var travel: Vector2 = rain_direction * time * speed
		var x: float = fposmod(h1 * wrap_size.x + travel.x, wrap_size.x) - 130.0
		var y: float = fposmod(h2 * wrap_size.y + travel.y, wrap_size.y) - 130.0
		var start := Vector2(x, y)
		var length: float = lerp(10.0, 70.0, pow(h5, 1.75))
		var end := start - rain_direction * length
		var headlight_factor: float = _screen_headlight_factor((start + end) * 0.5)
		var alpha: float = lerp(0.025, 0.085, h3) + headlight_factor * lerp(0.06, 0.16, h5)
		var rain_color: Color = Color("#d8eeee").lerp(Color("#caffd7"), min(0.75, headlight_factor))
		rain_color.a = min(alpha, 0.28)
		draw_line(start, end, rain_color, lerp(0.35, 0.85, headlight_factor), true)

func _draw_route_overlay() -> void:
	if map.current_route_points.size() < 2:
		return
	var left_track: Array[Vector2] = []
	var right_track: Array[Vector2] = []
	var track_half_width := 6.0
	for i in range(map.current_route_points.size()):
		var point: Vector2 = map.current_route_points[i]
		var tangent: Vector2
		if i == 0:
			tangent = map.current_route_points[min(i + 1, map.current_route_points.size() - 1)] - point
		elif i == map.current_route_points.size() - 1:
			tangent = point - map.current_route_points[i - 1]
		else:
			tangent = map.current_route_points[i + 1] - map.current_route_points[i - 1]
		if tangent.length() <= 0.01:
			tangent = Vector2.RIGHT
		var normal := tangent.normalized().orthogonal()
		left_track.append(map._to_screen(point + normal * track_half_width))
		right_track.append(map._to_screen(point - normal * track_half_width))
	_draw_route_overlay_track(left_track)
	_draw_route_overlay_track(right_track)

func _draw_route_overlay_track(points: Array[Vector2]) -> void:
	var dash := 7.0
	var gap := 10.0
	var draw_dash := true
	var remaining := dash
	for i in range(points.size() - 1):
		var a := points[i]
		var b := points[i + 1]
		var segment := b - a
		var segment_len := segment.length()
		if segment_len <= 0.01:
			continue
		var direction := segment / segment_len
		var cursor := 0.0
		while cursor < segment_len:
			var step = min(remaining, segment_len - cursor)
			if draw_dash:
				var p1: Vector2 = a + direction * cursor
				var p2: Vector2 = a + direction * (cursor + step)
				draw_line(p1, p2, Color("#45ff87", 0.18), 4.5, true)
				draw_line(p1, p2, Color("#baffcb", 0.62), 1.45, true)
			cursor += step
			remaining -= step
			if remaining <= 0.01:
				draw_dash = not draw_dash
				remaining = dash if draw_dash else gap

func _draw_destination_overlay() -> void:
	if not map.game.is_traveling:
		return
	var screen_pos: Vector2 = map._to_screen(map.game.travel_final_pos)
	if not Rect2(Vector2(-40.0, -40.0), size + Vector2(80.0, 80.0)).has_point(screen_pos):
		return
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.007)
	draw_circle(screen_pos, lerp(9.0, 15.0, pulse), Color("#dfffd8", 0.12))
	draw_arc(screen_pos, lerp(15.0, 22.0, pulse), 0.0, TAU, 42, Color("#eaffdf", 0.72), 1.7, true)
	draw_line(screen_pos + Vector2(-10.0, 0.0), screen_pos + Vector2(10.0, 0.0), Color("#eaffdf", 0.75), 1.2, true)
	draw_line(screen_pos + Vector2(0.0, -10.0), screen_pos + Vector2(0.0, 10.0), Color("#eaffdf", 0.75), 1.2, true)

func _screen_headlight_factor(screen_pos: Vector2) -> float:
	if map == null or map.game == null:
		return 0.0
	var car_screen: Vector2 = map._to_screen(map.game.player_pos)
	var forward := Vector2.RIGHT.rotated(map.game.vehicle_angle)
	if map.game.is_traveling and map.game.vehicle_velocity.length() > 2.0:
		forward = map.game.vehicle_velocity.normalized()
	var side := forward.orthogonal()
	var relative: Vector2 = screen_pos - car_screen
	var along: float = relative.dot(forward)
	if along <= 0.0 or along > 620.0:
		return 0.0
	var lateral: float = abs(relative.dot(side))
	var spread: float = along * 0.52 + 34.0
	var cone: float = clamp(1.0 - lateral / spread, 0.0, 1.0)
	var distance_fade: float = clamp(1.0 - along / 620.0, 0.0, 1.0)
	return pow(cone, 1.2) * pow(distance_fade, 0.6)

func _draw_rain_impacts() -> void:
	for impact in map.rain_impacts:
		var age: float = float(impact["age"])
		var life: float = max(0.01, float(impact["life"]))
		var t: float = clamp(age / life, 0.0, 1.0)
		var world_pos: Vector2 = impact["world_pos"]
		var screen_pos: Vector2 = map._to_screen(world_pos)
		if not Rect2(Vector2(-32.0, -32.0), size + Vector2(64.0, 64.0)).has_point(screen_pos):
			continue
		var light_factor: float = max(float(impact["light"]), map._headlight_weather_factor(world_pos))
		var radius: float = lerp(1.5, float(impact["radius"]), t)
		var fade: float = pow(1.0 - t, 1.05)
		var color: Color = Color("#d6f3f4").lerp(Color("#e6ffe3"), min(0.9, light_factor))
		color.a = fade * lerp(0.72, 1.0, light_factor)
		var seed: int = int(impact["seed"])
		var start_angle: float = map._hash01(seed) * TAU
		var arc_len: float = lerp(2.4, 5.2, map._hash01(seed + 17))
		draw_circle(screen_pos, max(1.8, radius * 0.24), Color(color.r, color.g, color.b, color.a * 0.42))
		draw_arc(screen_pos, radius, start_angle, start_angle + arc_len, 18, color, lerp(1.8, 3.2, light_factor), true)
		draw_arc(screen_pos, radius * 0.58, start_angle + 0.8, start_angle + arc_len * 0.72 + 0.8, 12, Color(color.r, color.g, color.b, color.a * 0.54), lerp(1.0, 2.0, light_factor), true)
		for j in range(3):
			var spoke_angle: float = start_angle + TAU * map._hash01(seed + j * 29 + 101)
			var spoke_dir := Vector2.RIGHT.rotated(spoke_angle)
			var spoke_len: float = radius * lerp(0.42, 0.86, map._hash01(seed + j * 31 + 113))
			var spoke_color := Color(color.r, color.g, color.b, color.a * 0.68)
			draw_line(screen_pos + spoke_dir * radius * 0.12, screen_pos + spoke_dir * spoke_len, spoke_color, lerp(1.0, 1.8, light_factor), true)
		var glint_color := Color("#f1ffe8", fade * lerp(0.28, 0.84, light_factor))
		draw_line(screen_pos + Vector2(-radius * 0.90, 0.0), screen_pos + Vector2(radius * 0.90, 0.0), glint_color, 1.25, true)
		draw_line(screen_pos + Vector2(0.0, -radius * 0.38), screen_pos + Vector2(0.0, radius * 0.38), Color(glint_color.r, glint_color.g, glint_color.b, glint_color.a * 0.58), 0.9, true)

func _draw_hover_card() -> void:
	if map.hovered_district == -1:
		return
	var d = map.game.districts[map.hovered_district]
	var faction = map.game.FACTIONS[d.faction]
	var card_pos = map.hover_screen_pos + Vector2(18, 18)
	var card_size := Vector2(285, 116)
	if card_pos.x + card_size.x > size.x - 12:
		card_pos.x = map.hover_screen_pos.x - card_size.x - 18
	if card_pos.y + card_size.y > size.y - 12:
		card_pos.y = map.hover_screen_pos.y - card_size.y - 18
	draw_rect(Rect2(card_pos, card_size), Color("#101417", 0.92), true)
	draw_rect(Rect2(card_pos, card_size), Color("#e7ecef", 0.24), false, 1.0)
	draw_circle(card_pos + Vector2(17, 23), 7, faction.color)
	draw_string(get_theme_default_font(), card_pos + Vector2(32, 28), d.name, HORIZONTAL_ALIGNMENT_LEFT, 230, 14, Color("#f2f2f2"))
	draw_string(get_theme_default_font(), card_pos + Vector2(18, 53), faction.title, HORIZONTAL_ALIGNMENT_LEFT, 240, 12, Color("#b6c2c8"))
	draw_string(get_theme_default_font(), card_pos + Vector2(18, 76), "Вода %d  Еда %d  Заряд %d" % [d.water, d.food, d.power], HORIZONTAL_ALIGNMENT_LEFT, 250, 12, Color("#d9e2e7"))
	draw_string(get_theme_default_font(), card_pos + Vector2(18, 96), "Безопасность %d  Вычисления %d" % [d.security, d.compute], HORIZONTAL_ALIGNMENT_LEFT, 250, 12, Color("#d9e2e7"))

func _draw_legend() -> void:
	var x := 18.0
	var y := size.y - 94.0
	draw_string(get_theme_default_font(), Vector2(x, y), "Двигайте мышь к краям экрана: сдвиг карты. ЛКМ по карте: ехать. ЛКМ по точке: войти. ПКМ: центр на машине.", HORIZONTAL_ALIGNMENT_LEFT, 940, 12, Color("#cfd8dc"))
	y += 26
	var offset := 0.0
	for key in map.game.FACTIONS.keys():
		var f = map.game.FACTIONS[key]
		draw_circle(Vector2(x + offset, y), 7, f.color)
		draw_string(get_theme_default_font(), Vector2(x + offset + 12, y + 5), f.title, HORIZONTAL_ALIGNMENT_LEFT, 128, 11, Color("#cfd8dc"))
		offset += 126

func _draw_minimap() -> void:
	var map_size := Vector2(205, 136)
	var pos := Vector2(size.x - map_size.x - 18, 18)
	map.minimap_rect = Rect2(pos, map_size)
	draw_rect(Rect2(pos, map_size), Color("#0d1215", 0.88), true)
	draw_rect(Rect2(pos, map_size), Color("#e7ecef", 0.25), false, 1.0)
	var scale = min(map_size.x / map.WORLD_SIZE.x, map_size.y / map.WORLD_SIZE.y)
	var pad = (map_size - map.WORLD_SIZE * scale) * 0.5
	for from in map.game.routes.keys():
		for to in map.game.routes[from]:
			if from > to:
				continue
			draw_line(pos + pad + map.game.districts[from].pos * scale, pos + pad + map.game.districts[to].pos * scale, Color("#506672", 0.55), 1.0, true)
	for i in range(map.game.districts.size()):
		var d = map.game.districts[i]
		var radius := 5.0 if map.game.at_location and i == map.game.current_district else 3.0
		draw_circle(pos + pad + d.pos * scale, radius, map.game.FACTIONS[d.faction].color)
	draw_circle(pos + pad + map.game.player_pos * scale, 4.5, Color("#e9c46a"))
	if map.pirate_active:
		var pirate_minimap_pos: Vector2 = pos + pad + map.pirate_pos * scale
		draw_circle(pirate_minimap_pos, 5.0, Color("#ff3030", 0.30))
		draw_circle(pirate_minimap_pos, 3.2, Color("#ff5b5b"))
		draw_arc(pirate_minimap_pos, 6.2, 0.0, TAU, 20, Color("#ffb0b0", 0.85), 1.0)
	var view_rect := Rect2(pos + pad + map.camera_offset * scale, size * scale)
	draw_rect(view_rect, Color("#f4f1de", 0.08), true)
	draw_rect(view_rect, Color("#f4f1de", 0.80), false, 1.0)
	draw_string(get_theme_default_font(), pos + Vector2(10, map_size.y - 10), "Перейти к точке", HORIZONTAL_ALIGNMENT_LEFT, 180, 11, Color("#cfd8dc"))
