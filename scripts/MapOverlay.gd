extends Control

var neon_font: Font
var sign_hover_levels := {}
var sign_layouts := {}
var map
var body_outline: Sprite2D
var outline_material: ShaderMaterial
var world_outlines := {}
var checkpoint_digits := {}

func bind(map_ref) -> void:
	map = map_ref
	body_outline = Sprite2D.new()
	var outline_shader := Shader.new()
	outline_shader.code = """
shader_type canvas_item;
render_mode unshaded;
varying vec4 outline_tint;
void vertex() {
	outline_tint = COLOR;
}
void fragment() {
	vec2 step_uv = TEXTURE_PIXEL_SIZE * 9.0;
	float body = texture(TEXTURE, UV).a;
	float around = max(
		max(texture(TEXTURE, UV + vec2(step_uv.x, 0.0)).a,
			texture(TEXTURE, UV - vec2(step_uv.x, 0.0)).a),
		max(texture(TEXTURE, UV + vec2(0.0, step_uv.y)).a,
			texture(TEXTURE, UV - vec2(0.0, step_uv.y)).a)
	);
	COLOR = vec4(outline_tint.rgb, max(around - body, 0.0) * outline_tint.a);
}
"""
	outline_material = ShaderMaterial.new()
	outline_material.shader = outline_shader
	body_outline.material = outline_material
	body_outline.self_modulate = Color(0.43, 0.95, 0.83, 0.42)
	body_outline.z_index = -1
	add_child(body_outline)
	var font_file := FontFile.new()
	if font_file.load_dynamic_font("res://assets/fonts/Jura.ttf") == OK:
		neon_font = font_file
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)

func _process(_delta: float) -> void:
	var body: Sprite2D = map.car_sprite if map != null else null
	body_outline.visible = is_instance_valid(body) and body.is_visible_in_tree()
	if body_outline.visible:
		body_outline.texture = map.player_body_diffuse()
		body_outline.transform = get_global_transform().affine_inverse() * body.get_global_transform()
	if map != null and map.game != null:
		_sync_world_outlines()
		for i in range(map.game.districts.size()):
			var current: float = sign_hover_levels.get(i, 0.0)
			var target := 1.0 if map.hovered_district == i else 0.0
			sign_hover_levels[i] = lerp(current, target, 0.14)
	queue_redraw()

func _sync_world_outlines() -> void:
	var seen := {}
	var inverse := get_global_transform().affine_inverse()
	var enemy_color := Color("#ff7869", 0.46)
	if map.pirate_active:
		var tint := Color(enemy_color, 0.88) if not map.primary_pirate_targeted_by.is_empty() else enemy_color
		_sync_outline(map.pirate_car_sprite, tint, inverse, seen)
	for enemy in map.debug_pirates:
		var root: Node2D = enemy.get("root")
		if is_instance_valid(root) and root.get_child_count() > 0:
			var marks: Array = enemy.get("targeted_by", [])
			_sync_outline(root.get_child(0) as Sprite2D, Color(enemy_color, 0.88) if not marks.is_empty() else enemy_color, inverse, seen)
	for entry in map.district_nodes:
		var index: int = entry.index
		var tint: Color = map._location_neon_color(map.game.districts[index].faction)
		tint.a = 0.36 if index == map.hovered_district else 0.20
		_sync_outline(entry.sprite, tint, inverse, seen)
	for id in world_outlines.keys():
		if not seen.has(id):
			world_outlines[id].queue_free()
			world_outlines.erase(id)

func _sync_outline(source: Sprite2D, tint: Color, inverse: Transform2D, seen: Dictionary) -> void:
	if not is_instance_valid(source) or not source.is_visible_in_tree() or source.texture == null:
		return
	var id := source.get_instance_id()
	seen[id] = true
	var outline: Sprite2D = world_outlines.get(id)
	if outline == null:
		outline = Sprite2D.new()
		outline.material = outline_material
		outline.z_index = -2
		outline.texture = source.texture
		outline.centered = source.centered
		outline.offset = source.offset
		add_child(outline)
		world_outlines[id] = outline
	outline.transform = inverse * source.get_global_transform()
	outline.self_modulate = tint

func _draw() -> void:
	if map == null or map.game == null:
		return
	_draw_rain()
	_draw_route_overlay()
	_draw_blocked_route()
	_draw_destination_overlay()
	_draw_weapon_range_overlay()
	_draw_location_name_labels()
	_draw_weapon_target_markers()
	_draw_hovered_vehicle_target()
	_draw_turns_to_cursor()
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
		checkpoint_digits.clear()
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
	_draw_turn_markers_overlay()

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
				if map.game.combat_mode:
					alpha_scale = 1.0 if i < map.route_first_leg_end else 0.26
				draw_line(p1, p2, Color("#45ff87", 0.18 * alpha_scale), 4.5, true)
				draw_line(p1, p2, Color("#baffcb", 0.62 * alpha_scale), 1.45, true)
			cursor += step
			remaining -= step
			if remaining <= 0.01:
				draw_dash = not draw_dash
				remaining = dash if draw_dash else gap
		traveled_len += segment_len

func _draw_blocked_route() -> void:
	var world_pos: Vector2 = map.game.route_blocked_pos
	if not world_pos.is_finite():
		return
	var point: Vector2 = map._to_screen(world_pos) + Vector2(0, 32)
	var marker := Rect2(point + Vector2(-60, -12), Vector2(120, 24))
	draw_rect(marker, Color("#18100c", 0.93))
	draw_rect(marker, Color("#ffad6d", 0.70), false, 1.0)
	draw_string(get_theme_default_font(), marker.position + Vector2(0, 16), "Путь перекрыт", HORIZONTAL_ALIGNMENT_CENTER, marker.size.x, 12, Color("#ffd2aa"))

func _draw_turn_markers_overlay() -> void:
	var markers: Array[Vector2] = map._planned_turn_marker_points()
	var next_digits := {}
	var now := Time.get_ticks_msec() * 0.001
	for i in range(markers.size()):
		var point: Vector2 = markers[i]
		var digit: Dictionary = checkpoint_digits.get(point, {"number": i + 1, "previous": 0, "since": now})
		if digit.number != i + 1:
			digit.previous = digit.number
			digit.number = i + 1
			digit.since = now
		next_digits[point] = digit
		var screen_pos: Vector2 = map._to_screen(point)
		if not Rect2(Vector2.ZERO, size).grow(32.0).has_point(screen_pos):
			continue
		var age: float = now - digit.since
		var brightness := 1.0 if i == 0 else 0.40
		if digit.previous > 0 and age < 0.15:
			_draw_nixie_number(screen_pos, digit.previous, brightness * (1.0 - smoothstep(0.0, 0.15, age)))
		_draw_nixie_number(screen_pos, i + 1, brightness * smoothstep(0.025, 0.22, age))
	checkpoint_digits = next_digits

func _draw_nixie_number(center: Vector2, number: int, brightness: float) -> void:
	var font: Font = neon_font if neon_font != null else get_theme_default_font()
	var digits := str(number)
	var font_size := 20
	var width := font.get_string_size(digits, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var baseline := (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	var origin := center + Vector2(-width * 0.5, baseline)
	draw_string_outline(font, origin, digits, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, 4, Color("#ff520c", brightness * 0.16))
	draw_string_outline(font, origin, digits, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, 2, Color("#ff791a", brightness * 0.56))
	draw_string(font, origin, digits, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color("#ffbf72", brightness))

func _route_length(points: Array[Vector2]) -> float:
	var total := 0.0
	for i in range(points.size() - 1):
		total += points[i].distance_to(points[i + 1])
	return total

func _sample_route_at_distance(points: Array[Vector2], target_distance: float) -> Vector2:
	var walked := 0.0
	for i in range(points.size() - 1):
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var segment_len := a.distance_to(b)
		if segment_len <= 0.01:
			continue
		if walked + segment_len >= target_distance:
			var local_t: float = clamp((target_distance - walked) / segment_len, 0.0, 1.0)
			return a.lerp(b, local_t)
		walked += segment_len
	return points[points.size() - 1]

func _draw_destination_overlay() -> void:
	if map.game.travel_destination_name == "" or not map.game.travel_final_pos.is_finite():
		return
	var screen_pos: Vector2 = map._to_screen(map.game.travel_final_pos)
	if not Rect2(Vector2(-40.0, -40.0), size + Vector2(80.0, 80.0)).has_point(screen_pos):
		return
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.007)
	var hovered := get_local_mouse_position().distance_squared_to(screen_pos) <= 24.0 * 24.0
	var mint := Color("#bcffdf") if hovered else Color("#76dfb6")
	var radius := 9.0 + pulse * 1.5
	for direction in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var corner: Vector2 = screen_pos + direction * radius
		var points := PackedVector2Array([
			corner - Vector2(direction.x * 5.0, 0.0),
			corner,
			corner - Vector2(0.0, direction.y * 5.0),
		])
		draw_polyline(points, Color(mint, 0.15), 4.0, true)
		draw_polyline(points, Color(mint, 1.0 if hovered else 0.82), 1.5, true)
	if hovered:
		draw_string(get_theme_default_font(), screen_pos + Vector2(20.0, -12.0), "Цель маршрута", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, mint)

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
	if is_instance_valid(map.aux_laser):
		_draw_weapon_slot(2, str(map.aux_turret_kit.get("name", "")), map._weapon_color(2), map.aux_laser_cooldown, float(map.aux_turret_kit.get("rate", 1.0)), false)
	if is_instance_valid(map.extra_rockets):
		_draw_weapon_slot(3, "Правая ракетная кассета", map._weapon_color(3), map.extra_rocket_cooldown, map.EXTRA_ROCKET_RATE, false)
	if map.player_turret_equipped:
		var weapon_name := "Импульсный излучатель" if map.player_pulse_equipped else ("Автопушка" if map.player_cannon_equipped else "Лазер")
		if map.player_rail_equipped:
			weapon_name = "Рельсовая пушка"
		elif map.player_shotgun_equipped:
			weapon_name = "Дробовая турель"
		_draw_weapon_slot(0, weapon_name, map.player_laser_color, map.player_weapon_cooldown, map.player_weapon_rate, map.player_fire_phase > 0.0)
	if map.player_missile_count > 0:
		_draw_weapon_slot(1, "Миномёт" if map.player_mortar_equipped else "Ракеты", Color("#ffcf5a"), map.player_missile_cooldown, map.player_missile_rate, false)

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
	if index != 1 and index != 3:
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
	var weapon_color: Color = Color("#88ffdd") if hovered_index == 2 else (map.player_laser_color if hovered_index == 0 else Color("#ffcf5a"))
	var range_radius: float = map.AUX_LASER_RANGE if hovered_index == 2 else (map.player_weapon_range if hovered_index == 0 else map.player_missile_range)
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

func _draw_weapon_target_markers() -> void:
	if map.game == null:
		return
	if map.pirate_active:
		_draw_primary_pirate_target_markers()
	for enemy in map.debug_pirates:
		_draw_targeted_by(enemy.get("pos", Vector2.ZERO), enemy.get("targeted_by", []))
	for car in map.friendly_cars:
		_draw_targeted_by(car.get("pos", Vector2.ZERO), car.get("targeted_by", []))

func _draw_primary_pirate_target_markers() -> void:
	var weapons: Array = map.primary_pirate_targeted_by.duplicate()
	for weapon_index in map.weapon_orders.keys():
		var order: Dictionary = map.weapon_orders[weapon_index]
		if str(order.get("id", "")) == "primary":
			var index: int = int(weapon_index)
			if not weapons.has(index):
				weapons.append(index)
	_draw_targeted_by(map.pirate_pos, weapons)

func _draw_target_marker_at(world_pos: Vector2, orders: Dictionary, target_id: String) -> void:
	var weapons := []
	for weapon_index in orders.keys():
		var order: Dictionary = orders[weapon_index]
		if str(order.get("id", "")) == target_id:
			weapons.append(int(weapon_index))
	_draw_targeted_by(world_pos, weapons)

func _draw_targeted_by(world_pos: Vector2, weapons: Array) -> void:
	if weapons.is_empty():
		return
	var base: Vector2 = map._to_screen(world_pos) + Vector2(-float(weapons.size() - 1) * 11.0, -48.0)
	for i in range(weapons.size()):
		var weapon_index: int = int(weapons[i])
		var color: Color = map._weapon_color(weapon_index)
		var center: Vector2 = base + Vector2(float(i) * 22.0, 0.0)
		draw_circle(center, 10.0, Color(color.r, color.g, color.b, 0.24))
		draw_circle(center, 7.0, Color("#081014", 0.88))
		draw_arc(center, 8.0, 0.0, TAU, 24, Color(color.r, color.g, color.b, 0.82), 1.2, true)
		draw_string(get_theme_default_font(), center + Vector2(-4.0, 4.0), map._weapon_label(weapon_index), HORIZONTAL_ALIGNMENT_LEFT, 12.0, 10, Color("#f8ffff"))

func _draw_hovered_vehicle_target() -> void:
	if map.hovered_vehicle_target.is_empty():
		return
	var target: Dictionary = map.hovered_vehicle_target
	var world_pos: Vector2 = target.get("pos", Vector2.ZERO)
	var screen_pos: Vector2 = map._to_screen(world_pos)
	if not Rect2(Vector2(-80.0, -80.0), size + Vector2(160.0, 160.0)).has_point(screen_pos):
		return
	var color := Color("#ff4b4b")
	var weapons: Array = []
	if target.get("type", "") == "friendly":
		color = Color("#8fd7ff")
	else:
		weapons = map._enemy_weapons_for_target(target)
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.010)
	var radius: float = lerp(31.0, 42.0, pulse)
	for i in range(weapons.size()):
		var weapon: Dictionary = weapons[i]
		var weapon_color: Color = weapon.get("color", color)
		var weapon_range: float = float(weapon.get("range", 0.0))
		if weapon_range <= 0.0:
			continue
		var alpha: float = 0.46 + float(i) * 0.08
		_draw_dashed_circle(screen_pos, weapon_range, Color(weapon_color.r, weapon_color.g, weapon_color.b, alpha))
		draw_circle(screen_pos, weapon_range, Color(weapon_color.r, weapon_color.g, weapon_color.b, 0.010 + float(i) * 0.004))
	draw_circle(screen_pos, radius + 14.0, Color(color.r, color.g, color.b, 0.055))
	draw_circle(screen_pos, radius + 6.0, Color(color.r, color.g, color.b, 0.075))
	draw_arc(screen_pos, radius, 0.0, TAU, 64, Color(color.r, color.g, color.b, 0.78), 2.0, true)
	draw_arc(screen_pos, radius + 7.0, 0.0, TAU, 64, Color(color.r, color.g, color.b, 0.32), 1.2, true)

func _draw_turns_to_cursor() -> void:
	if map.selected_weapon_index == -1 and not map.pirate_active and map.debug_pirates.is_empty():
		return
	var mouse_pos: Vector2 = get_local_mouse_position()
	if not Rect2(Vector2.ZERO, size).has_point(mouse_pos):
		return
	var world_pos: Vector2 = map._to_world(mouse_pos)
	var distance: float = map.game.player_pos.distance_to(world_pos)
	var turns: int = max(1, int(ceil(distance / 180.0)))
	var text := "%d ход." % turns
	var pos := mouse_pos + Vector2(18.0, -18.0)
	draw_rect(Rect2(pos + Vector2(-6.0, -17.0), Vector2(64.0, 24.0)), Color("#071013", 0.76), true)
	draw_string(get_theme_default_font(), pos, text, HORIZONTAL_ALIGNMENT_LEFT, 58.0, 12, Color("#d8fff2", 0.94))

func _draw_location_name_labels() -> void:
	for i in range(map.game.districts.size()):
		var d = map.game.districts[i]
		var screen_pos: Vector2 = map._to_screen(d.pos)
		if not Rect2(Vector2(-260.0, -220.0), size + Vector2(520.0, 440.0)).has_point(screen_pos):
			continue
		var has_sprite: bool = map.location_textures.has(d.name)
		var label_center: Vector2 = screen_pos + Vector2(0.0, -122.0 if has_sprite else -52.0)
		var neon_color: Color = map._location_neon_color(d.faction)
		if not has_sprite:
			draw_arc(screen_pos, 22.0, 0.0, TAU, 40, Color(neon_color, 0.38), 1.2, true)
		_draw_neon_sign(d.name, label_center, neon_color, i, sign_hover_levels.get(i, 0.0))

func _draw_neon_sign(text: String, center: Vector2, color: Color, seed: int, hover_amount: float) -> void:
	var font: Font = neon_font if neon_font != null else get_theme_default_font()
	var font_size := 25
	if not sign_layouts.has(text):
		var offsets := PackedFloat32Array()
		var width := 0.0
		for i in range(text.length()):
			offsets.append(width)
			width += font.get_char_size(text.unicode_at(i), font_size).x + 0.8
		sign_layouts[text] = {"offsets": offsets, "width": width}
	var layout: Dictionary = sign_layouts[text]
	var offsets: PackedFloat32Array = layout.offsets
	var origin := center + Vector2(-float(layout.width) * 0.5, 0.0)
	var time: float = Time.get_ticks_msec() * 0.001
	var tube_color := color.lightened(0.18 + hover_amount * 0.23)
	for i in range(text.length()):
		var ch := text.substr(i, 1)
		if ch == " ":
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
		var char_pos := origin + Vector2(offsets[i], 0.0)
		draw_string_outline(font, char_pos, ch, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, 5, Color(letter_color, 0.11 * intensity))
		draw_string_outline(font, char_pos, ch, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, 2, Color(letter_color, 0.56 * intensity))
		draw_string(font, char_pos, ch, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(letter_color.lightened(0.52), minf(1.0, intensity)))

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
	return map._weapon_index_at(get_local_mouse_position())

func _weapon_hud_rect() -> Rect2:
	var center := _weapon_slot_center(0)
	return Rect2(center - Vector2(48.0, 44.0), Vector2(282.0 if is_instance_valid(map.extra_rockets) else 224.0, 88.0))

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
	map.play_turn_button_rect = Rect2(pos + Vector2(46.0, map_size.y + 8.0), Vector2(159.0, 34.0))
	map.hold_turn_button_rect = Rect2(pos + Vector2(46.0, map_size.y + 48.0), Vector2(159.0, 34.0)) if map.game.combat_mode else Rect2()
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
	for car in map.friendly_cars:
		draw_circle(pos + pad + car.get("pos", Vector2.ZERO) * scale, 2.5, Color("#a8d8ff", 0.88))
	if map.pirate_active:
		var pirate_minimap_pos: Vector2 = pos + pad + map.pirate_pos * scale
		draw_circle(pirate_minimap_pos, 5.0, Color("#ff3030", 0.30))
		draw_circle(pirate_minimap_pos, 3.2, Color("#ff5b5b"))
		draw_arc(pirate_minimap_pos, 6.2, 0.0, TAU, 20, Color("#ffb0b0", 0.85), 1.0)
	for enemy in map.debug_pirates:
		var enemy_minimap_pos: Vector2 = pos + pad + enemy.get("pos", Vector2.ZERO) * scale
		draw_circle(enemy_minimap_pos, 4.2, Color("#ff3030", 0.22))
		draw_circle(enemy_minimap_pos, 2.7, Color("#ff5b5b", 0.94))
	var view_rect := Rect2(pos + pad + map.camera_offset * scale, size * scale)
	draw_rect(view_rect, Color("#f4f1de", 0.08), true)
	draw_rect(view_rect, Color("#f4f1de", 0.80), false, 1.0)
	draw_string(get_theme_default_font(), pos + Vector2(10, map_size.y - 10), "Перейти к точке", HORIZONTAL_ALIGNMENT_LEFT, 180, 11, Color("#cfd8dc"))
	_draw_pirate_debug_button(map.pirate_debug_button_rect)
	_draw_play_turn_button(map.play_turn_button_rect)
	if map.game.combat_mode:
		_draw_turn_action(map.hold_turn_button_rect, "Остаться на месте", map.game.can_hold_turn())

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

func _draw_play_turn_button(button_rect: Rect2) -> void:
	var label := "Выберите маршрут"
	if map.game.hold_turn_time > 0.0 or (map.game.is_traveling and map.game.combat_mode):
		label = "Ход выполняется"
	elif map.game.is_traveling:
		label = "Караван в пути"
	elif map.game.can_play_turn():
		label = "Выполнить ход"
	_draw_turn_action(button_rect, label, map.game.can_play_turn())

func _draw_turn_action(button_rect: Rect2, label: String, enabled: bool) -> void:
	var hovered: bool = button_rect.has_point(get_local_mouse_position())
	var accent := Color("#45ff87")
	var alpha: float = 0.92 if hovered and enabled else (0.72 if enabled else 0.34)
	draw_rect(button_rect.grow(6.0), Color(accent.r, accent.g, accent.b, 0.16 if hovered and enabled else 0.06), true)
	draw_rect(button_rect, Color("#0d1215", alpha), true)
	draw_rect(button_rect, Color(accent.r, accent.g, accent.b, 0.58 if enabled else 0.22), false, 1.2)
	var text_color := Color("#d7ffe4", 0.96 if enabled else 0.44)
	draw_string(get_theme_default_font(), button_rect.position + Vector2(0.0, 22.0), label, HORIZONTAL_ALIGNMENT_CENTER, button_rect.size.x, 12, text_color)
