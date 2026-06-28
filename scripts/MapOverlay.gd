extends Control

var neon_font: Font
var sign_hover_levels := {}
var map

func bind(map_ref) -> void:
	map = map_ref
	var font_file := FontFile.new()
	if font_file.load_dynamic_font("res://assets/fonts/Jura.ttf") == OK:
		neon_font = font_file
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)

func _process(_delta: float) -> void:
	if map != null and map.game != null:
		for i in range(map.game.districts.size()):
			var current: float = sign_hover_levels.get(i, 0.0)
			var target := 1.0 if map.hovered_district == i else 0.0
			sign_hover_levels[i] = lerp(current, target, 0.14)
	queue_redraw()

func _draw() -> void:
	if map == null or map.game == null:
		return
	_draw_rain()
	_draw_route_overlay()
	_draw_destination_overlay()
	_draw_weapon_range_overlay()
	_draw_location_name_labels()
	_draw_hover_card()
	_draw_weapon_hud()
	if not map.fullscreen_view:
		_draw_minimap()

func _draw_rain() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var time: float = Time.get_ticks_msec() * 0.001
	var cloud_direction: Vector2 = map.cloud_wind_velocity.normalized()
	if cloud_direction.length() <= 0.01:
		cloud_direction = Vector2.RIGHT
	var base_rain_direction: Vector2 = (cloud_direction * 0.42 + Vector2.DOWN).normalized()
	base_rain_direction = base_rain_direction.rotated(sin(time * 0.17) * 0.035)
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
		var head := Vector2(x, y)
		var length: float = lerp(10.0, 70.0, pow(h5, 1.75))
		var tail := head - rain_direction * length
		var headlight_factor: float = _screen_headlight_factor((head + tail) * 0.5)
		var alpha: float = lerp(0.040, 0.120, h3) + headlight_factor * lerp(0.09, 0.22, h5)
		var rain_color: Color = Color("#d8eeee").lerp(Color("#caffd7"), min(0.75, headlight_factor))
		rain_color.a = min(alpha, 0.34)
		draw_line(tail, head, rain_color, lerp(0.42, 0.95, headlight_factor), true)

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
	var total_len := 0.0
	for i in range(points.size() - 1):
		total_len += points[i].distance_to(points[i + 1])
	var traveled_len := 0.0
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
				var progress: float = clamp((traveled_len + cursor + step * 0.5) / max(1.0, total_len), 0.0, 1.0)
				var alpha_scale: float = lerp(0.30, 1.0, progress)
				draw_line(p1, p2, Color("#45ff87", 0.18 * alpha_scale), 4.5, true)
				draw_line(p1, p2, Color("#baffcb", 0.62 * alpha_scale), 1.45, true)
			cursor += step
			remaining -= step
			if remaining <= 0.01:
				draw_dash = not draw_dash
				remaining = dash if draw_dash else gap
		traveled_len += segment_len

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

func _draw_weapon_hud() -> void:
	_draw_weapon_slot(0, "Лазер", map.player_laser_color, map.player_weapon_cooldown, map.player_weapon_rate, map.player_fire_phase > 0.0)
	_draw_weapon_slot(1, "Ракеты", Color("#ffcf5a"), map.player_missile_cooldown, map.player_missile_rate, false)

func _draw_weapon_slot(index: int, label: String, weapon_color: Color, cooldown: float, rate: float, firing: bool) -> void:
	var slot_center := _weapon_slot_center(index)
	var radius := 18.0
	var slot_rect := Rect2(slot_center - Vector2(radius + 12.0, radius + 12.0), Vector2(radius + 12.0, radius + 12.0) * 2.0)
	var hovered: bool = slot_rect.has_point(get_local_mouse_position())
	var ready_ratio: float = 1.0
	if cooldown > 0.0:
		ready_ratio = clamp(1.0 - cooldown / max(0.01, rate), 0.0, 1.0)
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.018)
	var glow_alpha: float = 0.08 + pow(ready_ratio, 1.7) * 0.24
	if firing:
		glow_alpha += 0.10 + pulse * 0.08
	if hovered:
		glow_alpha += 0.08
	draw_circle(slot_center, radius + 14.0, Color(weapon_color.r, weapon_color.g, weapon_color.b, glow_alpha * 0.38))
	draw_circle(slot_center, radius + 9.0, Color(weapon_color.r, weapon_color.g, weapon_color.b, glow_alpha))
	draw_circle(slot_center, radius, Color("#071013", 0.94))
	draw_circle(slot_center, radius * 0.58, Color(weapon_color.r, weapon_color.g, weapon_color.b, 0.24 + ready_ratio * 0.34))
	draw_arc(slot_center, radius, 0.0, TAU, 42, Color("#d7e3e4", 0.34), 1.4, true)
	var start_angle: float = -PI * 0.5
	var end_angle: float = start_angle + TAU * ready_ratio
	var ring_color: Color = weapon_color.lightened(0.20)
	var ring_alpha: float = 0.36 + pow(ready_ratio, 1.45) * 0.56
	draw_arc(slot_center, radius + 5.0, start_angle, end_angle, 48, Color(ring_color.r, ring_color.g, ring_color.b, ring_alpha * 0.28), 7.0, true)
	draw_arc(slot_center, radius + 2.0, start_angle, end_angle, 48, Color(ring_color.r, ring_color.g, ring_color.b, ring_alpha * 0.46), 4.5, true)
	draw_arc(slot_center, radius + 1.0, start_angle, end_angle, 48, Color(ring_color.r, ring_color.g, ring_color.b, ring_alpha), 2.5, true)
	if firing:
		draw_arc(slot_center, radius + 5.0, start_angle, start_angle + TAU * pulse, 48, Color(ring_color.r, ring_color.g, ring_color.b, 0.24), 2.0, true)
	if index == 0:
		draw_line(slot_center + Vector2(-6.0, 4.0), slot_center + Vector2(6.0, -4.0), Color("#f3ffff", 0.82), 1.5, true)
		draw_line(slot_center + Vector2(-2.0, -8.0), slot_center + Vector2(2.0, 8.0), Color(weapon_color.r, weapon_color.g, weapon_color.b, 0.75), 1.1, true)
	else:
		var rocket_points := PackedVector2Array([
			slot_center + Vector2(7.0, 0.0),
			slot_center + Vector2(-6.0, -5.0),
			slot_center + Vector2(-3.0, 0.0),
			slot_center + Vector2(-6.0, 5.0)
		])
		draw_colored_polygon(rocket_points, Color("#fff4c5", 0.88))
		draw_line(slot_center + Vector2(-8.0, 6.0), slot_center + Vector2(-14.0, 10.0), Color(weapon_color.r, weapon_color.g, weapon_color.b, 0.58), 1.5, true)
		draw_line(slot_center + Vector2(-8.0, -6.0), slot_center + Vector2(-14.0, -10.0), Color(weapon_color.r, weapon_color.g, weapon_color.b, 0.58), 1.5, true)
	if hovered:
		_draw_weapon_tooltip(slot_center, label, weapon_color)

func _draw_weapon_range_overlay() -> void:
	var hovered_index: int = _hovered_weapon_index()
	if hovered_index == -1:
		return
	var center: Vector2 = map._to_screen(map.game.player_pos)
	var weapon_color: Color = map.player_laser_color if hovered_index == 0 else Color("#ffcf5a")
	var range_radius: float = map.player_weapon_range if hovered_index == 0 else map.player_missile_range
	draw_circle(center, range_radius, Color(weapon_color.r, weapon_color.g, weapon_color.b, 0.026))
	draw_circle(center, range_radius * 0.74, Color(weapon_color.r, weapon_color.g, weapon_color.b, 0.020))
	draw_circle(center, range_radius * 0.46, Color(weapon_color.r, weapon_color.g, weapon_color.b, 0.016))
	_draw_dashed_circle(center, range_radius, weapon_color)

func _draw_weapon_tooltip(slot_center: Vector2, text: String, color: Color) -> void:
	var tooltip_pos := slot_center + Vector2(32.0, -12.0)
	var tooltip_size := Vector2(82.0, 28.0)
	draw_rect(Rect2(tooltip_pos, tooltip_size), Color("#071013", 0.88), true)
	draw_rect(Rect2(tooltip_pos, tooltip_size), Color(color.r, color.g, color.b, 0.42), false, 1.0)
	draw_string(get_theme_default_font(), tooltip_pos + Vector2(10.0, 19.0), text, HORIZONTAL_ALIGNMENT_LEFT, 68.0, 12, Color("#eafff4", 0.94))

func _draw_location_name_labels() -> void:
	for i in range(map.game.districts.size()):
		var d = map.game.districts[i]
		var screen_pos: Vector2 = map._to_screen(d.pos)
		if not Rect2(Vector2(-260.0, -220.0), size + Vector2(520.0, 440.0)).has_point(screen_pos):
			continue
		var has_sprite: bool = map.location_textures.has(d.name)
		var label_center: Vector2 = screen_pos + Vector2(0.0, -122.0 if has_sprite else -52.0)
		var neon_color: Color = _location_neon_color(d.faction)
		_draw_neon_sign(d.name, label_center, neon_color, i, sign_hover_levels.get(i, 0.0))

func _draw_neon_sign(text: String, center: Vector2, color: Color, seed: int, hover_amount: float) -> void:
	var font: Font = neon_font if neon_font != null else get_theme_default_font()
	var font_size := 23
	var total_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var cursor := center + Vector2(-total_size.x * 0.5, 0.0)
	var time: float = Time.get_ticks_msec() * 0.001
	var tube_color := color.lightened(0.55 + hover_amount * 0.25)
	for i in range(text.length()):
		var ch := text.substr(i, 1)
		var ch_size: Vector2 = font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
		if ch == " ":
			cursor.x += max(ch_size.x, 8.0)
			continue
		var phase: float = float(seed * 37 + i * 19)
		var shimmer: float = 0.90 + 0.10 * sin(time * (3.2 + float(i % 3) * 0.7) + phase)
		var weak_letter: bool = map._hash01(seed * 97 + i * 41) < 0.28
		var blink_gate: float = sin(time * (8.5 + float(i % 2) * 1.8) + phase * 0.31)
		var blink: float = lerp(0.34, 0.58, hover_amount) if weak_letter and blink_gate > 0.72 else 1.0
		var intensity: float = min(1.65, shimmer * blink * (1.0 + hover_amount * 0.55))
		var letter_color: Color = tube_color
		if weak_letter:
			var fault_mix: float = 0.36 + 0.26 * sin(time * 5.7 + phase)
			var fault_color: Color = _fault_neon_color(color, seed + i)
			letter_color = tube_color.lerp(fault_color, fault_mix)
		var char_pos := cursor
		var glow_alpha: float = min(0.88, (0.34 + hover_amount * 0.28) * intensity)
		for offset in [Vector2(-4.0, 0.0), Vector2(4.0, 0.0), Vector2(0.0, -4.0), Vector2(0.0, 4.0)]:
			draw_string(font, char_pos + offset, ch, HORIZONTAL_ALIGNMENT_LEFT, ch_size.x + 6.0, font_size, Color(letter_color.r, letter_color.g, letter_color.b, glow_alpha * 0.30))
		for offset in [Vector2(-2.2, 0.0), Vector2(2.2, 0.0), Vector2(0.0, -2.2), Vector2(0.0, 2.2)]:
			draw_string(font, char_pos + offset, ch, HORIZONTAL_ALIGNMENT_LEFT, ch_size.x + 4.0, font_size, Color(letter_color.r, letter_color.g, letter_color.b, glow_alpha))
		for offset in [Vector2(-1.0, 0.0), Vector2(1.0, 0.0), Vector2(0.0, -1.0), Vector2(0.0, 1.0)]:
			draw_string(font, char_pos + offset, ch, HORIZONTAL_ALIGNMENT_LEFT, ch_size.x + 3.0, font_size, Color(letter_color.r, letter_color.g, letter_color.b, min(1.0, 0.70 * intensity)))
		draw_string(font, char_pos + Vector2(1.0, 1.0), ch, HORIZONTAL_ALIGNMENT_LEFT, ch_size.x + 3.0, font_size, Color("#011012", 0.80))
		draw_string(font, char_pos, ch, HORIZONTAL_ALIGNMENT_LEFT, ch_size.x + 3.0, font_size, Color("#ffffff", min(1.0, 0.78 + 0.26 * intensity)).lerp(letter_color.lightened(0.55), 0.42))
		cursor.x += ch_size.x + 1.0

func _location_neon_color(faction_key: String) -> Color:
	match faction_key:
		"city":
			return Color("#00eaff")
		"agro":
			return Color("#ff9f1c")
		"oasis":
			return Color("#00f6ff")
		"data":
			return Color("#9b2cff")
		"eco":
			return Color("#ff2bd6")
		"pirates":
			return Color("#ff1744")
		"observers":
			return Color("#45a3ff")
		_:
			return Color("#ff2bd6")

func _fault_neon_color(base: Color, seed: int) -> Color:
	var palette := [
		Color("#ff2bd6"),
		Color("#ff7a00"),
		Color("#9b2cff"),
		Color("#ff1744"),
		Color("#00eaff"),
		Color("#fff45c")
	]
	var index: int = int(floor(map._hash01(seed * 131 + 17) * float(palette.size()))) % palette.size()
	var candidate: Color = palette[index]
	if abs(candidate.r - base.r) + abs(candidate.g - base.g) + abs(candidate.b - base.b) < 0.45:
		candidate = palette[(index + 2) % palette.size()]
	return candidate.lightened(0.12)

func _weapon_slot_center(index: int) -> Vector2:
	return Vector2(58.0 + float(index) * 58.0, max(88.0, size.y - 74.0))

func _hovered_weapon_index() -> int:
	var mouse_pos := get_local_mouse_position()
	for i in range(2):
		var center := _weapon_slot_center(i)
		var rect := Rect2(center - Vector2(30.0, 30.0), Vector2(60.0, 60.0))
		if rect.has_point(mouse_pos):
			return i
	return -1

func _weapon_hud_rect() -> Rect2:
	var center := _weapon_slot_center(0)
	return Rect2(center - Vector2(48.0, 44.0), Vector2(224.0, 88.0))

func _draw_dashed_circle(center: Vector2, radius: float, color: Color) -> void:
	var segments := 192
	var dash_segments := 2
	var gap_segments := 1
	var spin: float = Time.get_ticks_msec() * 0.00018
	for i in range(segments):
		var cycle := dash_segments + gap_segments
		if i % cycle >= dash_segments:
			continue
		var a0: float = spin + TAU * float(i) / float(segments)
		var a1: float = spin + TAU * float(i + 1) / float(segments)
		var p0: Vector2 = center + Vector2(cos(a0), sin(a0)) * radius
		var p1: Vector2 = center + Vector2(cos(a1), sin(a1)) * radius
		draw_line(p0, p1, Color(color.r, color.g, color.b, 0.13), 4.2, true)
		draw_line(p0, p1, Color(color.r, color.g, color.b, 0.66), 1.15, true)

func _draw_minimap() -> void:
	var map_size := Vector2(205, 136)
	var pos := Vector2(size.x - map_size.x - 18, 18)
	map.minimap_rect = Rect2(pos, map_size)
	map.pirate_debug_button_rect = Rect2(pos + Vector2(0.0, map_size.y + 8.0), Vector2(38.0, 34.0))
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
	_draw_pirate_debug_button(map.pirate_debug_button_rect)

func _draw_pirate_debug_button(button_rect: Rect2) -> void:
	var hovered: bool = button_rect.has_point(get_local_mouse_position())
	var accent := Color("#ff4a3d")
	var bg_alpha: float = 0.90 if hovered else 0.76
	var glow_alpha: float = 0.18 if hovered else 0.08
	draw_rect(button_rect.grow(6.0), Color(accent.r, accent.g, accent.b, glow_alpha), true)
	draw_rect(button_rect, Color("#0d1215", bg_alpha), true)
	draw_rect(button_rect, Color(accent.r, accent.g, accent.b, 0.62 if hovered else 0.38), false, 1.2)
	var center: Vector2 = button_rect.get_center()
	draw_line(center + Vector2(-8.0, 0.0), center + Vector2(8.0, 0.0), Color("#ffd6d1", 0.92), 2.2, true)
	draw_line(center + Vector2(0.0, -8.0), center + Vector2(0.0, 8.0), Color("#ffd6d1", 0.92), 2.2, true)
	if hovered:
		var tooltip_pos := button_rect.position + Vector2(46.0, 4.0)
		var tooltip_size := Vector2(112.0, 26.0)
		draw_rect(Rect2(tooltip_pos, tooltip_size), Color("#071013", 0.88), true)
		draw_rect(Rect2(tooltip_pos, tooltip_size), Color(accent.r, accent.g, accent.b, 0.42), false, 1.0)
		draw_string(get_theme_default_font(), tooltip_pos + Vector2(9.0, 18.0), "Добавить пирата", HORIZONTAL_ALIGNMENT_LEFT, 96.0, 11, Color("#ffe8e5"))
