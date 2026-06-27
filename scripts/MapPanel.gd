extends Panel

const WORLD_SIZE := Vector2(5200, 3500)
const NODE_HIT_RADIUS := 42.0
const VEHICLE_TEXTURE_SCALE := 0.052
const MAP_BACKGROUND := Color("#111c1f")
const CLOUD_POOL_SIZE := 104
const RAIN_STREAK_COUNT := 180
const RAIN_IMPACT_RATE := 240.0
const WHEEL_SPRAY_RATE := 34.0

var car_texture: Texture2D
var light_front_texture: Texture2D
var light_back_texture: Texture2D
var pirate_car_texture: Texture2D
var pirate_light_front_texture: Texture2D
var pirate_light_back_texture: Texture2D
var pirate_cannon_texture: Texture2D
var wheel_left_texture: Texture2D
var wheel_right_texture: Texture2D
var location_textures := {}
var location_light_textures := {}
var wheel_left_center := Vector2(-10, -23)
var wheel_right_center := Vector2(10, -23)
var front_light_texture: Texture2D
var rear_light_texture: Texture2D
var front_left_light: PointLight2D
var front_right_light: PointLight2D
var rear_left_light: PointLight2D
var rear_right_light: PointLight2D
var vehicle_root: Node2D
var car_sprite: Sprite2D
var front_overlay_sprite: Sprite2D
var back_overlay_sprite: Sprite2D
var wheel_left_pivot: Node2D
var wheel_right_pivot: Node2D
var wheel_left_sprite: Sprite2D
var wheel_right_sprite: Sprite2D
var pirate_root: Node2D
var pirate_car_sprite: Sprite2D
var pirate_front_overlay_sprite: Sprite2D
var pirate_back_overlay_sprite: Sprite2D
var pirate_cannon_sprite: Sprite2D
var pirate_front_left_light: PointLight2D
var pirate_front_right_light: PointLight2D
var pirate_rear_left_light: PointLight2D
var pirate_rear_right_light: PointLight2D
var pirate_laser_root: Node2D
var pirate_laser_outer_glow: Line2D
var pirate_laser_glow: Line2D
var pirate_laser_inner_glow: Line2D
var pirate_laser_line: Line2D
var pirate_laser_light: PointLight2D
var pirate_laser_lights: Array[PointLight2D] = []
var world_root: Node2D
var heat_root: Node2D
var routes_root: Node2D
var travel_route_root: Node2D
var clouds_root: Node2D
var districts_root: Node2D
var rain_surface_root: Node2D
var wheel_spray_root: Node2D
var car_shadow_sprite: Sprite2D
var car_shadow_material: ShaderMaterial
var destination_marker_root: Node2D
var destination_marker_glow: Polygon2D
var destination_marker_core: Polygon2D
var destination_marker_ring: Line2D
var destination_marker_light: PointLight2D
var health_bar_root: Node2D
var health_bar_aura: Polygon2D
var health_bar_bg: Polygon2D
var health_bar_glow: Polygon2D
var health_bar_fill: Polygon2D
var health_bar_border: Line2D
var health_bar_line_glow: Line2D
var health_bar_line_fill: Line2D
var health_bar_light: PointLight2D
var pirate_health_bar_root: Node2D
var pirate_health_bar_glow: Line2D
var pirate_health_bar_fill: Line2D
var pirate_health_bar_light: PointLight2D
var canvas_modulate: CanvasModulate
var route_lines := {}
var heat_nodes := []
var district_nodes := []
var current_route_points: Array[Vector2] = []
var cloud_textures := []
var cloud_props := []
var cloud_rng := RandomNumberGenerator.new()
var cloud_wind_velocity := Vector2(7.0, -3.0)
var rain_seed := 0
var rain_impact_accumulator := 0.0
var rain_impacts: Array[Dictionary] = []
var rain_splash_textures: Array[Texture2D] = []
var wheel_spray_accumulator := 0.0
var pirate_wheel_spray_accumulator := 0.0
var wheel_sprays: Array[Dictionary] = []
var overlay: Control

var game: Control
var camera_offset := Vector2.ZERO
var hovered_district := -1
var hover_screen_pos := Vector2.ZERO
var minimap_rect := Rect2()
var fullscreen_view := false
var centered_initially := false
var minimap_dragging := false
var road_bump_rng := RandomNumberGenerator.new()
var bump_timer := 0.0
var bump_phase := 0.0
var bump_duration := 0.0
var bump_strength := 0.0
var bump_roll_strength := 0.0
var shadow_sweep_timer := 0.4
var shadow_sweep_phase := 0.0
var shadow_sweep_duration := 0.0
var shadow_sweep_intensity := 0.0
var shadow_sweep_angle := 0.0
var shadow_sweep_start := Vector2.ZERO
var shadow_sweep_end := Vector2.ZERO
var shadow_sweep_texture_scale := 1.0
var headlight_glitch_timer := 5.0
var headlight_glitch_phase := 0.0
var headlight_glitch_duration := 0.0
var headlight_glitch_side := 0
var pirate_active := false
var pirate_spawn_timer := 10.0
var pirate_pos := Vector2.ZERO
var pirate_angle := 0.0
var pirate_speed := 155.0
var pirate_fire_timer := 2.6
var pirate_fire_phase := 0.0
var pirate_fire_duration := 0.0
var pirate_laser_start := Vector2.ZERO
var pirate_laser_end := Vector2.ZERO
var pirate_hull := 100
var pirate_laser_blur := 1.0
var pirate_laser_damage_applied := false
var damage_popups: Array[Dictionary] = []

func bind(game_ref: Control) -> void:
	game = game_ref
	mouse_filter = Control.MOUSE_FILTER_STOP
	_load_vehicle_textures()
	_setup_world_nodes()
	_setup_vehicle_node()
	_setup_pirate_node()
	_setup_destination_marker_node()
	_setup_health_bar_node()
	_setup_overlay()
	set_process(true)
	set_process_input(true)

func set_fullscreen_view(enabled: bool) -> void:
	fullscreen_view = enabled

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_load_vehicle_textures()
	_setup_world_nodes()
	_setup_vehicle_node()
	_setup_pirate_node()
	_setup_destination_marker_node()
	_setup_health_bar_node()
	_setup_overlay()
	set_process(true)
	set_process_input(true)

func _input(event: InputEvent) -> void:
	if game == null or game._is_map_blocked(self):
		return
	if not _is_active_map_view():
		return
	if event is InputEventMouseMotion and minimap_dragging:
		_center_from_minimap(get_local_mouse_position())
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed:
		var local_mouse := get_local_mouse_position()
		if not Rect2(Vector2.ZERO, size).has_point(local_mouse):
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			_handle_left_click(local_mouse)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_center_on(game.player_pos)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		minimap_dragging = false

func _load_vehicle_textures() -> void:
	if car_texture != null and pirate_car_texture != null:
		return
	car_texture = _load_png_texture("res://assets/vehicles/car-top.png")
	light_front_texture = _load_png_texture("res://assets/vehicles/light-front.png")
	light_back_texture = _load_png_texture("res://assets/vehicles/light-back.png")
	pirate_car_texture = _load_png_texture("res://assets/vehicles/pirates/pirate1/car-top.png")
	pirate_light_front_texture = _load_png_texture("res://assets/vehicles/pirates/pirate1/light-front.png")
	pirate_light_back_texture = _load_png_texture("res://assets/vehicles/pirates/pirate1/light-back.png")
	pirate_cannon_texture = _load_png_texture("res://assets/vehicles/pirates/pirate1/cannon.png")
	location_textures["Новый Колодец"] = _load_png_texture("res://assets/locations/new-well/new-well.png")
	location_light_textures["Новый Колодец"] = _load_png_texture("res://assets/locations/new-well/new-well_lights.png")
	location_textures["Агрокупол N-12"] = _load_png_texture("res://assets/locations/agro-dome.png")
	location_textures["Кластер Минерва"] = _load_png_texture("res://assets/locations/data-cluster.png")
	location_textures["Мандат-7"] = _load_png_texture("res://assets/locations/observer-post/observer-post.png")
	location_light_textures["Мандат-7"] = _load_png_texture("res://assets/locations/observer-post/observer-post_lights.png")
	location_textures["Сухой Порт"] = _load_png_texture("res://assets/locations/pirate-cam.png")
	location_textures["Пыльная Развязка"] = _load_png_texture("res://assets/locations/pirate-cam.png")
	cloud_textures.append_array(_load_png_textures_from_dir("res://assets/clouds"))
	var left_wheel := _load_wheel_texture("res://assets/vehicles/wheel-left.png")
	var right_wheel := _load_wheel_texture("res://assets/vehicles/wheel-right.png")
	wheel_left_texture = left_wheel["texture"]
	wheel_right_texture = right_wheel["texture"]
	wheel_left_center = left_wheel["center"]
	wheel_right_center = right_wheel["center"]
	front_light_texture = _make_cone_light_texture()
	rear_light_texture = _make_radial_light_texture(Color.WHITE)

func _load_png_texture(path: String, key_light_background := false) -> Texture2D:
	var image := Image.new()
	var err := image.load(path)
	if err != OK:
		return null
	image.convert(Image.FORMAT_RGBA8)
	if key_light_background:
		_remove_baked_checker_background(image)
	return ImageTexture.create_from_image(image)

func _load_png_textures_from_dir(path: String) -> Array:
	var textures := []
	var dir := DirAccess.open(path)
	if dir == null:
		return textures
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.get_extension().to_lower() == "png":
			var texture = _load_png_texture("%s/%s" % [path, file_name])
			if texture != null:
				textures.append(texture)
		file_name = dir.get_next()
	dir.list_dir_end()
	return textures

func _load_wheel_texture(path: String) -> Dictionary:
	var image := Image.new()
	var err := image.load(path)
	if err != OK:
		return {"texture": null, "center": Vector2.ZERO}
	image.convert(Image.FORMAT_RGBA8)
	_remove_baked_checker_background(image)
	var center := _alpha_center_to_vehicle_space(image)
	return {"texture": ImageTexture.create_from_image(image), "center": center}

func _alpha_center_to_vehicle_space(image: Image) -> Vector2:
	var sum := Vector2.ZERO
	var count := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.12:
				sum += Vector2(x, y)
				count += 1
	if count == 0:
		return Vector2.ZERO
	var pixel_center = sum / float(count)
	var image_center = Vector2(image.get_width(), image.get_height()) * 0.5
	return (pixel_center - image_center) * VEHICLE_TEXTURE_SCALE

func _remove_baked_checker_background(image: Image) -> void:
	var width := image.get_width()
	var height := image.get_height()
	for y in range(height):
		for x in range(width):
			var color := image.get_pixel(x, y)
			var max_channel = max(color.r, max(color.g, color.b))
			var min_channel = min(color.r, min(color.g, color.b))
			var brightness = (color.r + color.g + color.b) / 3.0
			if brightness > 0.72 and max_channel - min_channel < 0.08:
				color.a = 0.0
				image.set_pixel(x, y, color)

func _setup_world_nodes() -> void:
	if world_root != null or game == null:
		return
	world_root = Node2D.new()
	world_root.z_index = 0
	world_root.z_as_relative = true
	add_child(world_root)

	heat_root = Node2D.new()
	heat_root.z_index = 0
	world_root.add_child(heat_root)

	routes_root = Node2D.new()
	routes_root.z_index = 2
	world_root.add_child(routes_root)

	travel_route_root = Node2D.new()
	travel_route_root.z_index = 4
	world_root.add_child(travel_route_root)

	clouds_root = Node2D.new()
	clouds_root.z_index = 18
	world_root.add_child(clouds_root)

	districts_root = Node2D.new()
	districts_root.z_index = 14
	world_root.add_child(districts_root)

	rain_surface_root = Node2D.new()
	rain_surface_root.z_index = 16
	world_root.add_child(rain_surface_root)

	wheel_spray_root = Node2D.new()
	wheel_spray_root.z_index = 9
	world_root.add_child(wheel_spray_root)

	_setup_canvas_modulate()
	_rebuild_world_nodes()
	road_bump_rng.randomize()
	cloud_rng.randomize()
	rain_seed = road_bump_rng.randi()
	_reset_cloud_wind()

func _setup_canvas_modulate() -> void:
	if canvas_modulate != null:
		return
	canvas_modulate = CanvasModulate.new()
	canvas_modulate.color = Color("#566164")
	add_child(canvas_modulate)

func _setup_overlay() -> void:
	if overlay != null:
		return
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index = 60
	add_child(overlay)
	overlay.set_script(preload("res://scripts/MapOverlay.gd"))
	overlay.call("bind", self)

func _rebuild_world_nodes() -> void:
	if game == null or heat_root == null:
		return
	for child in heat_root.get_children():
		child.queue_free()
	for child in routes_root.get_children():
		child.queue_free()
	for child in districts_root.get_children():
		child.queue_free()
	route_lines.clear()
	heat_nodes.clear()
	district_nodes.clear()

	for i in range(game.districts.size()):
		var heat := Polygon2D.new()
		heat.polygon = _make_circle_polygon(120.0, 40)
		heat.position = game.districts[i].pos
		heat.color = Color("#3fa7c9", 0.08)
		heat_root.add_child(heat)
		heat_nodes.append(heat)

	var drawn := {}
	for from in game.routes.keys():
		for to in game.routes[from]:
			var key = "%d-%d" % [min(from, to), max(from, to)]
			if drawn.has(key):
				continue
			drawn[key] = true
			var line := Line2D.new()
			line.points = PackedVector2Array([game.districts[from].pos, game.districts[to].pos])
			line.width = 7.5
			line.default_color = Color("#d8e4e5", 0.12)
			line.antialiased = true
			routes_root.add_child(line)
			route_lines[key] = {"line": line, "from": from, "to": to}

	for i in range(game.districts.size()):
		var node := Node2D.new()
		node.position = game.districts[i].pos
		districts_root.add_child(node)

		var sprite: Sprite2D = null
		var light_sprite: Sprite2D = null
		var location_glow: PointLight2D = null
		var marker := Polygon2D.new()
		var location_texture = location_textures.get(game.districts[i].name)
		if location_texture != null:
			sprite = Sprite2D.new()
			sprite.texture = location_texture
			sprite.scale = Vector2(0.208, 0.208)
			sprite.z_index = 1
			node.add_child(sprite)
			var location_light_texture = location_light_textures.get(game.districts[i].name)
			if location_light_texture != null:
				light_sprite = Sprite2D.new()
				light_sprite.texture = location_light_texture
				light_sprite.scale = sprite.scale
				light_sprite.z_index = 3
				var light_material := CanvasItemMaterial.new()
				light_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
				light_sprite.material = light_material
				node.add_child(light_sprite)
				location_glow = PointLight2D.new()
				location_glow.texture = _make_radial_light_texture(Color.WHITE)
				location_glow.color = Color("#ffd985")
				location_glow.energy = 0.62
				location_glow.texture_scale = 2.55
				location_glow.z_index = 2
				node.add_child(location_glow)
			var occluder := LightOccluder2D.new()
			occluder.occluder = _make_box_occluder(Vector2(150, 120))
			occluder.z_index = 2
			node.add_child(occluder)
			marker.polygon = _make_circle_polygon(22.0, 32)
			marker.color = Color(game.FACTIONS[game.districts[i].faction].color, 0.0)
		else:
			marker.polygon = _make_circle_polygon(17.0, 32)
			marker.color = game.FACTIONS[game.districts[i].faction].color
		marker.z_index = 0
		node.add_child(marker)

		var ring := Line2D.new()
		ring.points = _make_ring_points(22.0, 48)
		ring.width = 2.0
		ring.default_color = Color("#e7ecef", 0.75)
		ring.antialiased = true
		node.add_child(ring)

		district_nodes.append({"root": node, "marker": marker, "ring": ring, "sprite": sprite, "light_sprite": light_sprite, "location_glow": location_glow, "index": i})

func _make_circle_polygon(radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(segments):
		var angle = TAU * float(i) / float(segments)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points

func _make_ring_points(radius: float, segments: int) -> PackedVector2Array:
	var points := _make_circle_polygon(radius, segments)
	points.append(points[0])
	return points

func _make_box_occluder(size: Vector2) -> OccluderPolygon2D:
	var occluder := OccluderPolygon2D.new()
	var half := size * 0.5
	occluder.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y)
	])
	occluder.closed = true
	return occluder

func _setup_vehicle_node() -> void:
	if vehicle_root != null:
		return
	vehicle_root = Node2D.new()
	vehicle_root.z_index = 10
	vehicle_root.z_as_relative = true
	add_child(vehicle_root)

	wheel_left_pivot = Node2D.new()
	wheel_left_pivot.position = wheel_left_center
	wheel_left_pivot.z_index = 0
	wheel_left_pivot.z_as_relative = true
	vehicle_root.add_child(wheel_left_pivot)

	wheel_left_sprite = Sprite2D.new()
	wheel_left_sprite.texture = wheel_left_texture
	wheel_left_sprite.scale = Vector2(VEHICLE_TEXTURE_SCALE, VEHICLE_TEXTURE_SCALE)
	wheel_left_sprite.position = -wheel_left_center
	wheel_left_sprite.z_index = 0
	wheel_left_sprite.z_as_relative = true
	wheel_left_sprite.light_mask = 1
	wheel_left_pivot.add_child(wheel_left_sprite)

	wheel_right_pivot = Node2D.new()
	wheel_right_pivot.position = wheel_right_center
	wheel_right_pivot.z_index = 0
	wheel_right_pivot.z_as_relative = true
	vehicle_root.add_child(wheel_right_pivot)

	wheel_right_sprite = Sprite2D.new()
	wheel_right_sprite.texture = wheel_right_texture
	wheel_right_sprite.scale = Vector2(VEHICLE_TEXTURE_SCALE, VEHICLE_TEXTURE_SCALE)
	wheel_right_sprite.position = -wheel_right_center
	wheel_right_sprite.z_index = 0
	wheel_right_sprite.z_as_relative = true
	wheel_right_sprite.light_mask = 1
	wheel_right_pivot.add_child(wheel_right_sprite)

	car_sprite = Sprite2D.new()
	car_sprite.texture = car_texture
	car_sprite.scale = Vector2(VEHICLE_TEXTURE_SCALE, VEHICLE_TEXTURE_SCALE)
	car_sprite.z_index = 1
	car_sprite.z_as_relative = true
	car_sprite.light_mask = 1
	vehicle_root.add_child(car_sprite)

	car_shadow_sprite = Sprite2D.new()
	car_shadow_sprite.texture = car_texture
	car_shadow_sprite.scale = Vector2(VEHICLE_TEXTURE_SCALE, VEHICLE_TEXTURE_SCALE)
	car_shadow_sprite.z_index = 2
	car_shadow_sprite.z_as_relative = true
	car_shadow_sprite.visible = false
	car_shadow_material = _make_car_shadow_material()
	if not cloud_textures.is_empty():
		car_shadow_material.set_shader_parameter("shadow_texture", cloud_textures[0])
	car_shadow_sprite.material = car_shadow_material
	vehicle_root.add_child(car_shadow_sprite)

	front_overlay_sprite = Sprite2D.new()
	front_overlay_sprite.texture = light_front_texture
	front_overlay_sprite.scale = Vector2(VEHICLE_TEXTURE_SCALE, VEHICLE_TEXTURE_SCALE)
	front_overlay_sprite.visible = false
	front_overlay_sprite.z_index = 3
	front_overlay_sprite.light_mask = 1
	vehicle_root.add_child(front_overlay_sprite)

	back_overlay_sprite = Sprite2D.new()
	back_overlay_sprite.texture = light_back_texture
	back_overlay_sprite.scale = Vector2(VEHICLE_TEXTURE_SCALE, VEHICLE_TEXTURE_SCALE)
	back_overlay_sprite.visible = false
	back_overlay_sprite.z_index = 3
	back_overlay_sprite.light_mask = 1
	vehicle_root.add_child(back_overlay_sprite)

	front_left_light = _make_front_light()
	front_right_light = _make_front_light()
	vehicle_root.add_child(front_left_light)
	vehicle_root.add_child(front_right_light)

	rear_left_light = PointLight2D.new()
	rear_left_light.texture = rear_light_texture
	rear_left_light.color = Color("#ff3030")
	rear_left_light.energy = 0.0
	rear_left_light.texture_scale = 0.18
	vehicle_root.add_child(rear_left_light)

	rear_right_light = PointLight2D.new()
	rear_right_light.texture = rear_light_texture
	rear_right_light.color = Color("#ff3030")
	rear_right_light.energy = 0.0
	rear_right_light.texture_scale = 0.18
	vehicle_root.add_child(rear_right_light)

func _setup_pirate_node() -> void:
	if pirate_root != null:
		return
	pirate_laser_root = Node2D.new()
	pirate_laser_root.z_index = 53
	pirate_laser_root.z_as_relative = false
	pirate_laser_root.visible = false
	add_child(pirate_laser_root)

	pirate_laser_outer_glow = Line2D.new()
	pirate_laser_outer_glow.width = 34.0
	pirate_laser_outer_glow.default_color = Color("#ff2020", 0.08)
	pirate_laser_outer_glow.antialiased = true
	var laser_outer_material := CanvasItemMaterial.new()
	laser_outer_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	pirate_laser_outer_glow.material = laser_outer_material
	pirate_laser_root.add_child(pirate_laser_outer_glow)

	pirate_laser_glow = Line2D.new()
	pirate_laser_glow.width = 18.0
	pirate_laser_glow.default_color = Color("#ff2a2a", 0.24)
	pirate_laser_glow.antialiased = true
	var laser_glow_material := CanvasItemMaterial.new()
	laser_glow_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	pirate_laser_glow.material = laser_glow_material
	pirate_laser_root.add_child(pirate_laser_glow)

	pirate_laser_inner_glow = Line2D.new()
	pirate_laser_inner_glow.width = 8.0
	pirate_laser_inner_glow.default_color = Color("#ff4545", 0.34)
	pirate_laser_inner_glow.antialiased = true
	var laser_inner_material := CanvasItemMaterial.new()
	laser_inner_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	pirate_laser_inner_glow.material = laser_inner_material
	pirate_laser_root.add_child(pirate_laser_inner_glow)

	pirate_laser_line = Line2D.new()
	pirate_laser_line.width = 2.2
	pirate_laser_line.default_color = Color("#ff5b5b", 0.92)
	pirate_laser_line.antialiased = true
	var laser_line_material := CanvasItemMaterial.new()
	laser_line_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	pirate_laser_line.material = laser_line_material
	pirate_laser_root.add_child(pirate_laser_line)

	pirate_laser_light = PointLight2D.new()
	pirate_laser_light.texture = _make_radial_light_texture(Color.WHITE)
	pirate_laser_light.color = Color("#ff3030")
	pirate_laser_light.energy = 0.0
	pirate_laser_light.texture_scale = 2.6
	pirate_laser_root.add_child(pirate_laser_light)
	for i in range(5):
		var laser_light := PointLight2D.new()
		laser_light.texture = _make_radial_light_texture(Color.WHITE)
		laser_light.color = Color("#ff3030")
		laser_light.energy = 0.0
		laser_light.texture_scale = 1.45
		pirate_laser_root.add_child(laser_light)
		pirate_laser_lights.append(laser_light)

	pirate_root = Node2D.new()
	pirate_root.z_index = 11
	pirate_root.z_as_relative = false
	pirate_root.visible = false
	add_child(pirate_root)

	pirate_car_sprite = Sprite2D.new()
	pirate_car_sprite.texture = pirate_car_texture
	pirate_car_sprite.scale = Vector2(VEHICLE_TEXTURE_SCALE, VEHICLE_TEXTURE_SCALE)
	pirate_car_sprite.z_index = 1
	pirate_car_sprite.light_mask = 1
	pirate_root.add_child(pirate_car_sprite)

	pirate_front_overlay_sprite = Sprite2D.new()
	pirate_front_overlay_sprite.texture = pirate_light_front_texture
	pirate_front_overlay_sprite.scale = Vector2(VEHICLE_TEXTURE_SCALE, VEHICLE_TEXTURE_SCALE)
	pirate_front_overlay_sprite.z_index = 3
	pirate_front_overlay_sprite.light_mask = 1
	pirate_root.add_child(pirate_front_overlay_sprite)

	pirate_back_overlay_sprite = Sprite2D.new()
	pirate_back_overlay_sprite.texture = pirate_light_back_texture
	pirate_back_overlay_sprite.scale = Vector2(VEHICLE_TEXTURE_SCALE, VEHICLE_TEXTURE_SCALE)
	pirate_back_overlay_sprite.z_index = 3
	pirate_back_overlay_sprite.light_mask = 1
	pirate_root.add_child(pirate_back_overlay_sprite)

	pirate_cannon_sprite = Sprite2D.new()
	pirate_cannon_sprite.texture = pirate_cannon_texture
	pirate_cannon_sprite.scale = Vector2(VEHICLE_TEXTURE_SCALE, VEHICLE_TEXTURE_SCALE)
	pirate_cannon_sprite.z_index = 4
	pirate_cannon_sprite.light_mask = 1
	pirate_root.add_child(pirate_cannon_sprite)

	pirate_front_left_light = _make_front_light()
	pirate_front_right_light = _make_front_light()
	pirate_front_left_light.color = Color("#ffd88a")
	pirate_front_right_light.color = Color("#ffd88a")
	pirate_root.add_child(pirate_front_left_light)
	pirate_root.add_child(pirate_front_right_light)

	pirate_rear_left_light = PointLight2D.new()
	pirate_rear_left_light.texture = rear_light_texture
	pirate_rear_left_light.color = Color("#ff3030")
	pirate_rear_left_light.texture_scale = 0.18
	pirate_root.add_child(pirate_rear_left_light)

	pirate_rear_right_light = PointLight2D.new()
	pirate_rear_right_light.texture = rear_light_texture
	pirate_rear_right_light.color = Color("#ff3030")
	pirate_rear_right_light.texture_scale = 0.18
	pirate_root.add_child(pirate_rear_right_light)

func _setup_destination_marker_node() -> void:
	if destination_marker_root != null:
		return
	destination_marker_root = Node2D.new()
	destination_marker_root.z_index = 52
	destination_marker_root.z_as_relative = false
	destination_marker_root.visible = false
	add_child(destination_marker_root)

	destination_marker_glow = Polygon2D.new()
	destination_marker_glow.color = Color("#eaffe8", 0.20)
	destination_marker_glow.z_index = 0
	var glow_material := CanvasItemMaterial.new()
	glow_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	destination_marker_glow.material = glow_material
	destination_marker_root.add_child(destination_marker_glow)

	destination_marker_core = Polygon2D.new()
	destination_marker_core.color = Color("#eaffe8", 0.34)
	destination_marker_core.z_index = 1
	var core_material := CanvasItemMaterial.new()
	core_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	destination_marker_core.material = core_material
	destination_marker_root.add_child(destination_marker_core)

	destination_marker_ring = Line2D.new()
	destination_marker_ring.width = 1.4
	destination_marker_ring.default_color = Color("#f4fff0", 0.88)
	destination_marker_ring.antialiased = true
	destination_marker_ring.z_index = 2
	var ring_material := CanvasItemMaterial.new()
	ring_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	destination_marker_ring.material = ring_material
	destination_marker_root.add_child(destination_marker_ring)

	destination_marker_light = PointLight2D.new()
	destination_marker_light.texture = _make_radial_light_texture(Color.WHITE)
	destination_marker_light.color = Color("#d9ffd5")
	destination_marker_light.energy = 0.72
	destination_marker_light.texture_scale = 1.25
	destination_marker_root.add_child(destination_marker_light)

func _setup_health_bar_node() -> void:
	if health_bar_root != null:
		return
	health_bar_root = Node2D.new()
	health_bar_root.z_index = 55
	health_bar_root.z_as_relative = false
	add_child(health_bar_root)

	health_bar_aura = Polygon2D.new()
	health_bar_aura.z_index = 0
	health_bar_aura.color = Color("#65ff91", 0.12)
	var aura_material := CanvasItemMaterial.new()
	aura_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	health_bar_aura.material = aura_material
	health_bar_root.add_child(health_bar_aura)
	health_bar_aura.visible = false

	health_bar_glow = Polygon2D.new()
	health_bar_glow.z_index = 1
	health_bar_glow.color = Color("#6dff9a", 0.34)
	var glow_material := CanvasItemMaterial.new()
	glow_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	health_bar_glow.material = glow_material
	health_bar_root.add_child(health_bar_glow)
	health_bar_glow.visible = false

	health_bar_bg = Polygon2D.new()
	health_bar_bg.z_index = 2
	health_bar_bg.color = Color("#031007", 0.86)
	health_bar_root.add_child(health_bar_bg)
	health_bar_bg.visible = false

	health_bar_fill = Polygon2D.new()
	health_bar_fill.z_index = 3
	health_bar_fill.color = Color("#74ff9f", 1.0)
	var fill_material := CanvasItemMaterial.new()
	fill_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	health_bar_fill.material = fill_material
	health_bar_root.add_child(health_bar_fill)
	health_bar_fill.visible = false

	health_bar_border = Line2D.new()
	health_bar_border.z_index = 4
	health_bar_border.width = 1.0
	health_bar_border.default_color = Color("#d8ffe3", 0.70)
	health_bar_border.antialiased = true
	health_bar_root.add_child(health_bar_border)
	health_bar_border.visible = false

	health_bar_line_glow = Line2D.new()
	health_bar_line_glow.z_index = 4
	health_bar_line_glow.width = 13.0
	health_bar_line_glow.default_color = Color("#65ff91", 0.24)
	health_bar_line_glow.antialiased = true
	health_bar_line_glow.material = glow_material
	health_bar_root.add_child(health_bar_line_glow)

	health_bar_line_fill = Line2D.new()
	health_bar_line_fill.z_index = 5
	health_bar_line_fill.width = 5.0
	health_bar_line_fill.default_color = Color("#8cffad", 0.98)
	health_bar_line_fill.antialiased = true
	health_bar_line_fill.material = fill_material
	health_bar_root.add_child(health_bar_line_fill)

	health_bar_light = PointLight2D.new()
	health_bar_light.z_index = 5
	health_bar_light.texture = _make_radial_light_texture(Color.WHITE)
	health_bar_light.color = Color("#65ff91")
	health_bar_light.energy = 1.8
	health_bar_light.texture_scale = 2.25
	health_bar_root.add_child(health_bar_light)

	pirate_health_bar_root = Node2D.new()
	pirate_health_bar_root.z_index = 55
	pirate_health_bar_root.z_as_relative = false
	pirate_health_bar_root.visible = false
	add_child(pirate_health_bar_root)

	pirate_health_bar_glow = Line2D.new()
	pirate_health_bar_glow.width = 12.0
	pirate_health_bar_glow.default_color = Color("#ff4a4a", 0.24)
	pirate_health_bar_glow.antialiased = true
	var pirate_glow_material := CanvasItemMaterial.new()
	pirate_glow_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	pirate_health_bar_glow.material = pirate_glow_material
	pirate_health_bar_root.add_child(pirate_health_bar_glow)

	pirate_health_bar_fill = Line2D.new()
	pirate_health_bar_fill.width = 5.0
	pirate_health_bar_fill.default_color = Color("#ff6f6f", 0.98)
	pirate_health_bar_fill.antialiased = true
	var pirate_fill_material := CanvasItemMaterial.new()
	pirate_fill_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	pirate_health_bar_fill.material = pirate_fill_material
	pirate_health_bar_root.add_child(pirate_health_bar_fill)

	pirate_health_bar_light = PointLight2D.new()
	pirate_health_bar_light.texture = _make_radial_light_texture(Color.WHITE)
	pirate_health_bar_light.color = Color("#ff4a4a")
	pirate_health_bar_light.energy = 1.35
	pirate_health_bar_light.texture_scale = 1.75
	pirate_health_bar_root.add_child(pirate_health_bar_light)

func _make_front_light() -> PointLight2D:
	var light := PointLight2D.new()
	light.texture = front_light_texture
	light.color = Color("#ffd88a")
	light.energy = 0.0
	light.texture_scale = 0.94
	return light

func _make_car_shadow_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform sampler2D shadow_texture;
uniform vec2 shadow_offset = vec2(0.5, 0.5);
uniform float shadow_angle = 0.0;
uniform float shadow_scale = 1.0;
uniform float shadow_intensity = 0.0;

void fragment() {
	vec4 car = texture(TEXTURE, UV);
	vec2 centered = UV - vec2(0.5);
	float cs = cos(shadow_angle);
	float sn = sin(shadow_angle);
	vec2 rotated = vec2(centered.x * cs - centered.y * sn, centered.x * sn + centered.y * cs);
	vec2 cloud_uv = rotated / max(0.001, shadow_scale) + shadow_offset;
	float inside = step(0.0, cloud_uv.x) * step(cloud_uv.x, 1.0) * step(0.0, cloud_uv.y) * step(cloud_uv.y, 1.0);
	vec4 cloud = texture(shadow_texture, cloud_uv);
	float shade = smoothstep(0.10, 0.72, cloud.a) * inside * car.a * shadow_intensity;
	COLOR = vec4(0.0, 0.0, 0.0, shade);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("shadow_intensity", 0.0)
	return material

func _make_radial_light_texture(color: Color) -> Texture2D:
	var image := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	var center := Vector2(64, 64)
	for y in range(128):
		for x in range(128):
			var distance = center.distance_to(Vector2(x, y)) / 64.0
			var alpha = pow(max(0.0, 1.0 - distance), 2.2)
			image.set_pixel(x, y, Color(color.r, color.g, color.b, alpha))
	return ImageTexture.create_from_image(image)

func _make_cone_light_texture() -> Texture2D:
	var image := Image.create(640, 256, false, Image.FORMAT_RGBA8)
	var origin := Vector2(320, 128)
	for y in range(256):
		for x in range(640):
			var point := Vector2(x, y)
			var offset: Vector2 = point - origin
			if offset.x <= 0.0:
				image.set_pixel(x, y, Color(1, 1, 1, 0))
				continue
			var distance: float = offset.length()
			var narrow_spread: float = abs(offset.y) / max(1.0, offset.x * 0.34)
			var wide_spread: float = abs(offset.y) / max(1.0, offset.x * 0.78)
			var core: float = pow(max(0.0, 1.0 - distance / 430.0), 2.0) * pow(max(0.0, 1.0 - narrow_spread), 1.6)
			var haze: float = pow(max(0.0, 1.0 - distance / 560.0), 2.8) * pow(max(0.0, 1.0 - wide_spread), 2.4)
			var alpha: float = min(0.70, core * 0.72 + haze * 0.26)
			image.set_pixel(x, y, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(image)

func _process(delta: float) -> void:
	if game == null:
		return
	if not centered_initially and size.x > 0.0 and size.y > 0.0:
		centered_initially = true
		_center_on(game.player_pos)
	_update_road_bump(delta)
	_update_headlight_glitch(delta)
	_update_vehicle_lights()
	if not _is_active_map_view():
		_despawn_pirate()
		_update_damage_popups(delta)
		return
	_update_pirate(delta)
	_update_damage_popups(delta)
	_update_rain_impacts(delta)
	_update_wheel_sprays(delta)
	_update_shadow_sweep(delta)
	_update_destination_marker()
	_update_world_nodes(delta)
	_update_cloud_props(delta)
	_update_travel_route()
	queue_redraw()
	if game._is_map_blocked(self):
		return
	var viewport_mouse := get_viewport().get_mouse_position()
	var viewport_size := get_viewport_rect().size
	var local_mouse := get_local_mouse_position()
	if Rect2(Vector2.ZERO, size).has_point(local_mouse):
		hover_screen_pos = local_mouse
		_update_hover(local_mouse)
	var edge := 74.0
	var speed := 620.0
	var pan := Vector2.ZERO
	if viewport_mouse.x < edge:
		pan.x -= 1.0 - viewport_mouse.x / edge
	elif viewport_mouse.x > viewport_size.x - edge:
		pan.x += 1.0 - (viewport_size.x - viewport_mouse.x) / edge
	if viewport_mouse.y < edge:
		pan.y -= 1.0 - viewport_mouse.y / edge
	elif viewport_mouse.y > viewport_size.y - edge:
		pan.y += 1.0 - (viewport_size.y - viewport_mouse.y) / edge
	if pan != Vector2.ZERO:
		camera_offset += pan.normalized() * speed * delta
		_clamp_camera()
		queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if game == null:
		return
	if game._is_map_blocked(self):
		return
	if not _is_active_map_view():
		return

	if event is InputEventMouseMotion:
		hover_screen_pos = event.position
		if minimap_dragging:
			_center_from_minimap(event.position)
			queue_redraw()
		elif minimap_rect.has_point(event.position) and not fullscreen_view:
			hovered_district = -1
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			queue_redraw()
		else:
			_update_hover(event.position)
		return


func _handle_left_click(local_pos: Vector2) -> void:
	if minimap_rect.has_point(local_pos) and not fullscreen_view:
		minimap_dragging = true
		_center_from_minimap(local_pos)
	elif hovered_district != -1:
		game._map_location_clicked(hovered_district)
	else:
		game._map_point_clicked(_to_world(local_pos))
	_update_hover(local_pos)
	queue_redraw()

func _is_active_map_view() -> bool:
	if fullscreen_view:
		return game.fullscreen_map_panel != null and game.fullscreen_map_panel.visible
	return game.fullscreen_map_panel == null or not game.fullscreen_map_panel.visible

func _center_from_minimap(local_pos: Vector2) -> void:
	var map_size := minimap_rect.size
	var scale = min(map_size.x / WORLD_SIZE.x, map_size.y / WORLD_SIZE.y)
	var pad = (map_size - WORLD_SIZE * scale) * 0.5
	var world_pos = (local_pos - minimap_rect.position - pad) / scale
	world_pos.x = clamp(world_pos.x, 0.0, WORLD_SIZE.x)
	world_pos.y = clamp(world_pos.y, 0.0, WORLD_SIZE.y)
	_center_on(world_pos)

func _draw() -> void:
	if game == null:
		return
	_clamp_camera()
	draw_rect(Rect2(Vector2.ZERO, size), MAP_BACKGROUND, true)
	_draw_ground()
	_draw_node_labels()
	_draw_vehicle()
	if overlay != null:
		overlay.queue_redraw()

func _draw_ground() -> void:
	var step := 120
	var start_x := int(camera_offset.x / step) * step
	var start_y := int(camera_offset.y / step) * step
	for x in range(start_x, int(camera_offset.x + size.x) + step, step):
		draw_line(_to_screen(Vector2(x, camera_offset.y)), _to_screen(Vector2(x, camera_offset.y + size.y)), Color("#d5e1e3", 0.055), 1.0)
	for y in range(start_y, int(camera_offset.y + size.y) + step, step):
		draw_line(_to_screen(Vector2(camera_offset.x, y)), _to_screen(Vector2(camera_offset.x + size.x, y)), Color("#d5e1e3", 0.055), 1.0)

func _draw_rain() -> void:
	if game == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var time: float = Time.get_ticks_msec() * 0.001
	var gust_angle: float = -0.22 + sin(time * 0.17) * 0.05
	var base_rain_direction := Vector2(gust_angle, 1.0).normalized()
	var wrap_size := size + Vector2(260.0, 260.0)
	for i in range(RAIN_STREAK_COUNT):
		var h1: float = _hash01(rain_seed + i * 37)
		var h2: float = _hash01(rain_seed + i * 53 + 11)
		var h3: float = _hash01(rain_seed + i * 71 + 23)
		var h4: float = _hash01(rain_seed + i * 89 + 41)
		var h5: float = _hash01(rain_seed + i * 97 + 67)
		var rain_direction: Vector2 = base_rain_direction.rotated(lerp(-0.10, 0.10, h4))
		var speed: float = lerp(155.0, 360.0, pow(h3, 0.72))
		var travel: Vector2 = rain_direction * time * speed
		var x: float = fposmod(h1 * wrap_size.x + travel.x, wrap_size.x) - 130.0
		var y: float = fposmod(h2 * wrap_size.y + travel.y, wrap_size.y) - 130.0
		var start := Vector2(x, y)
		var length: float = lerp(10.0, 70.0, pow(h5, 1.75))
		var end := start - rain_direction * length
		var mid_world: Vector2 = _to_world((start + end) * 0.5)
		var headlight_factor: float = _headlight_weather_factor(mid_world)
		var alpha: float = lerp(0.045, 0.18, h3) + headlight_factor * lerp(0.20, 0.42, h5)
		var rain_color: Color = Color("#d8eeee").lerp(Color("#caffd7"), min(0.75, headlight_factor))
		rain_color.a = min(alpha, 0.68)
		draw_line(start, end, rain_color, lerp(0.65, 1.45, headlight_factor), true)

func _update_rain_impacts(delta: float) -> void:
	if game == null or rain_surface_root == null or size.x <= 0.0 or size.y <= 0.0:
		return
	rain_impact_accumulator += delta * RAIN_IMPACT_RATE
	while rain_impact_accumulator >= 1.0:
		rain_impact_accumulator -= 1.0
		_spawn_rain_impact()
	for i in range(rain_impacts.size() - 1, -1, -1):
		var impact: Dictionary = rain_impacts[i]
		var sprite: Sprite2D = impact["sprite"] as Sprite2D
		var age: float = float(impact["age"]) + delta
		impact["age"] = age
		var life: float = float(impact["life"])
		if age >= life:
			if is_instance_valid(sprite):
				sprite.queue_free()
			rain_impacts.remove_at(i)
		else:
			if is_instance_valid(sprite):
				_update_rain_impact_sprite(impact)
			rain_impacts[i] = impact

func _spawn_rain_impact() -> void:
	if rain_surface_root == null:
		return
	if rain_splash_textures.is_empty():
		_build_rain_splash_textures()
	var world_pos: Vector2
	var prefer_headlight: bool = road_bump_rng.randf() < 0.82
	if prefer_headlight:
		var forward := Vector2.RIGHT.rotated(game.vehicle_angle)
		if game.is_traveling and game.vehicle_velocity.length() > 2.0:
			forward = game.vehicle_velocity.normalized()
		var along: float = road_bump_rng.randf_range(75.0, 620.0)
		var side := forward.orthogonal()
		var spread: float = along * 0.44 + 24.0
		world_pos = game.player_pos + forward * along + side * road_bump_rng.randf_range(-spread, spread)
	else:
		world_pos = camera_offset + Vector2(
			road_bump_rng.randf_range(0.0, size.x),
			road_bump_rng.randf_range(0.0, size.y)
		)
	world_pos.x = clamp(world_pos.x, 0.0, WORLD_SIZE.x)
	world_pos.y = clamp(world_pos.y, 0.0, WORLD_SIZE.y)
	var light_factor: float = _headlight_weather_factor(world_pos)
	var sprite := Sprite2D.new()
	var seed: int = road_bump_rng.randi()
	sprite.texture = rain_splash_textures[posmod(seed, rain_splash_textures.size())]
	sprite.position = world_pos
	sprite.rotation = road_bump_rng.randf_range(-0.25, 0.25)
	sprite.z_index = 0
	var impact := {
		"sprite": sprite,
		"world_pos": world_pos,
		"age": 0.0,
		"life": road_bump_rng.randf_range(0.42, 0.78),
		"scale": road_bump_rng.randf_range(0.075, 0.14),
		"seed": seed,
		"light": light_factor
	}
	rain_surface_root.add_child(sprite)
	rain_impacts.append(impact)
	_update_rain_impact_sprite(impact)
	if rain_impacts.size() > 620:
		var old_impact: Dictionary = rain_impacts.pop_front()
		var old_sprite: Sprite2D = old_impact["sprite"] as Sprite2D
		if is_instance_valid(old_sprite):
			old_sprite.queue_free()

func _update_rain_impact_sprite(impact: Dictionary) -> void:
	var sprite: Sprite2D = impact["sprite"] as Sprite2D
	if not is_instance_valid(sprite):
		return
	var age: float = float(impact["age"])
	var life: float = max(0.01, float(impact["life"]))
	var t: float = clamp(age / life, 0.0, 1.0)
	var world_pos: Vector2 = impact["world_pos"]
	var light_factor: float = max(float(impact["light"]), _headlight_weather_factor(world_pos))
	var base_scale: float = float(impact["scale"])
	var fade: float = pow(1.0 - t, 1.18)
	sprite.scale = Vector2.ONE * lerp(base_scale * 0.55, base_scale * 1.55, t)
	var color: Color = Color("#cfe8e8").lerp(Color("#e8ffe2"), min(0.9, light_factor))
	color.a = fade * lerp(0.38, 0.82, light_factor)
	sprite.modulate = color

func _update_wheel_sprays(delta: float) -> void:
	if game == null or wheel_spray_root == null:
		return
	var moving: bool = game.is_traveling and game.vehicle_current_speed > 28.0 and game.vehicle_velocity.length() > 2.0
	if moving:
		var speed_factor: float = clamp(game.vehicle_current_speed / max(1.0, game.vehicle_speed), 0.0, 1.35)
		wheel_spray_accumulator += delta * WHEEL_SPRAY_RATE * lerp(0.35, 1.0, min(1.0, speed_factor))
		while wheel_spray_accumulator >= 1.0:
			wheel_spray_accumulator -= 1.0
			var spray_chance: float = lerp(0.34, 0.72, min(1.0, speed_factor))
			if road_bump_rng.randf() < spray_chance:
				_spawn_wheel_spray(game.player_pos, game.vehicle_velocity, game.vehicle_current_speed, game.vehicle_speed, game.vehicle_is_braking, speed_factor)
	else:
		wheel_spray_accumulator = min(wheel_spray_accumulator, 0.6)
	if pirate_active and pirate_root != null and pirate_root.visible:
		var pirate_forward: Vector2 = Vector2.RIGHT.rotated(pirate_angle)
		var pirate_velocity: Vector2 = pirate_forward * pirate_speed
		var pirate_speed_factor: float = clamp(pirate_speed / 190.0, 0.0, 1.25)
		pirate_wheel_spray_accumulator += delta * WHEEL_SPRAY_RATE * 0.62
		while pirate_wheel_spray_accumulator >= 1.0:
			pirate_wheel_spray_accumulator -= 1.0
			if road_bump_rng.randf() < 0.50:
				_spawn_wheel_spray(pirate_pos, pirate_velocity, pirate_speed, 190.0, false, pirate_speed_factor)
	else:
		pirate_wheel_spray_accumulator = min(pirate_wheel_spray_accumulator, 0.6)
	for i in range(wheel_sprays.size() - 1, -1, -1):
		var spray: Dictionary = wheel_sprays[i]
		var line: Line2D = spray["line"] as Line2D
		var age: float = float(spray["age"]) + delta
		spray["age"] = age
		var life: float = float(spray["life"])
		if age >= life:
			if is_instance_valid(line):
				line.queue_free()
			wheel_sprays.remove_at(i)
		else:
			if is_instance_valid(line):
				_update_wheel_spray_line(spray)
			wheel_sprays[i] = spray

func _spawn_wheel_spray(vehicle_pos: Vector2, vehicle_velocity: Vector2, current_speed: float, max_speed: float, braking: bool, speed_factor: float) -> void:
	if wheel_spray_root == null or vehicle_velocity.length() <= 2.0:
		return
	var forward: Vector2 = vehicle_velocity.normalized()
	var side: Vector2 = forward.orthogonal()
	var rear_center: Vector2 = vehicle_pos - forward * 28.0
	var wheel_side: float = -1.0 if road_bump_rng.randi_range(0, 1) == 0 else 1.0
	var origin: Vector2 = rear_center + side * wheel_side * road_bump_rng.randf_range(10.0, 13.5)
	origin += forward * road_bump_rng.randf_range(-3.0, 3.0)
	var spray_velocity: Vector2 = -forward * road_bump_rng.randf_range(34.0, 86.0)
	spray_velocity += side * wheel_side * road_bump_rng.randf_range(8.0, 28.0)
	spray_velocity += side * road_bump_rng.randf_range(-7.0, 7.0)
	var line := Line2D.new()
	line.antialiased = true
	line.width = road_bump_rng.randf_range(0.35, 0.85)
	line.default_color = Color("#cfe9e8", 0.0)
	wheel_spray_root.add_child(line)
	var spray := {
		"line": line,
		"origin": origin,
		"velocity": spray_velocity,
		"age": 0.0,
		"life": road_bump_rng.randf_range(0.12, 0.28),
		"length": road_bump_rng.randf_range(3.0, 9.0) * lerp(0.65, 1.15, min(1.0, speed_factor)),
		"width": line.width,
		"alpha": road_bump_rng.randf_range(0.10, 0.34),
		"speed_ratio": clamp(current_speed / max(1.0, max_speed), 0.0, 1.25),
		"brake": 1.0 if braking else 0.0,
		"seed": road_bump_rng.randf_range(0.0, TAU)
	}
	wheel_sprays.append(spray)
	_update_wheel_spray_line(spray)
	if wheel_sprays.size() > 100:
		var old_spray: Dictionary = wheel_sprays.pop_front()
		var old_line: Line2D = old_spray["line"] as Line2D
		if is_instance_valid(old_line):
			old_line.queue_free()

func _update_wheel_spray_line(spray: Dictionary) -> void:
	var line: Line2D = spray["line"] as Line2D
	if not is_instance_valid(line):
		return
	var age: float = float(spray["age"])
	var life: float = max(0.01, float(spray["life"]))
	var t: float = clamp(age / life, 0.0, 1.0)
	var origin: Vector2 = spray["origin"]
	var velocity: Vector2 = spray["velocity"]
	var drift: Vector2 = velocity * age
	var direction: Vector2 = velocity.normalized() if velocity.length() > 0.01 else Vector2.LEFT
	var jitter: Vector2 = direction.orthogonal() * sin(float(spray["seed"]) + t * TAU) * 1.3 * (1.0 - t)
	var tail: Vector2 = origin + drift + jitter
	var head: Vector2 = tail - direction * float(spray["length"]) * lerp(1.0, 0.25, t)
	line.points = PackedVector2Array([head, tail])
	line.width = max(0.1, lerp(float(spray["width"]), 0.12, t))
	var brake_factor: float = float(spray["brake"]) * pow(1.0 - t, 0.7)
	var color: Color = Color("#cfe9e8").lerp(Color("#ff6b63"), brake_factor * 0.34)
	color.a = pow(1.0 - t, 1.45) * float(spray["alpha"]) * lerp(0.70, 1.18, min(1.0, float(spray["speed_ratio"])))
	line.default_color = color

func _update_shadow_sweep(delta: float) -> void:
	if car_shadow_sprite == null or car_shadow_material == null or game == null:
		return
	if not game.is_traveling or game.vehicle_current_speed < 24.0:
		shadow_sweep_phase = max(0.0, shadow_sweep_phase - delta * 2.4)
		_set_car_shadow_intensity(0.0)
		return
	if shadow_sweep_phase <= 0.0:
		shadow_sweep_timer -= delta
		if shadow_sweep_timer <= 0.0:
			if road_bump_rng.randf() < 0.78:
				_start_shadow_sweep()
			shadow_sweep_timer = road_bump_rng.randf_range(0.35, 1.35)
	else:
		shadow_sweep_phase = max(0.0, shadow_sweep_phase - delta)
	var intensity := 0.0
	if shadow_sweep_phase > 0.0 and shadow_sweep_duration > 0.0:
		var progress: float = 1.0 - shadow_sweep_phase / shadow_sweep_duration
		var envelope: float = sin(progress * PI)
		intensity = shadow_sweep_intensity * envelope
		car_shadow_material.set_shader_parameter("shadow_offset", shadow_sweep_start.lerp(shadow_sweep_end, progress))
	_set_car_shadow_intensity(intensity)

func _start_shadow_sweep() -> void:
	if cloud_textures.is_empty() or car_shadow_material == null:
		return
	shadow_sweep_duration = road_bump_rng.randf_range(0.58, 1.55)
	shadow_sweep_phase = shadow_sweep_duration
	shadow_sweep_intensity = road_bump_rng.randf_range(0.16, 0.36)
	shadow_sweep_angle = road_bump_rng.randf_range(-1.15, 1.15)
	var travel_dir: Vector2 = Vector2.RIGHT.rotated(road_bump_rng.randf_range(-0.85, 0.85))
	var uv_span: float = road_bump_rng.randf_range(0.62, 1.05)
	var side_offset: float = road_bump_rng.randf_range(-0.20, 0.20)
	shadow_sweep_start = Vector2(0.5, 0.5) - travel_dir * uv_span + travel_dir.orthogonal() * side_offset
	shadow_sweep_end = Vector2(0.5, 0.5) + travel_dir * uv_span + travel_dir.orthogonal() * road_bump_rng.randf_range(-0.20, 0.20)
	shadow_sweep_texture_scale = road_bump_rng.randf_range(0.36, 0.82)
	car_shadow_material.set_shader_parameter("shadow_texture", cloud_textures[road_bump_rng.randi_range(0, cloud_textures.size() - 1)])
	car_shadow_material.set_shader_parameter("shadow_angle", shadow_sweep_angle)
	car_shadow_material.set_shader_parameter("shadow_scale", shadow_sweep_texture_scale)
	car_shadow_material.set_shader_parameter("shadow_offset", shadow_sweep_start)

func _set_car_shadow_intensity(intensity: float) -> void:
	car_shadow_sprite.visible = intensity > 0.01
	car_shadow_material.set_shader_parameter("shadow_intensity", intensity)

func _build_rain_splash_textures() -> void:
	if not rain_splash_textures.is_empty():
		return
	for variant in range(5):
		rain_splash_textures.append(_make_rain_splash_texture(variant))

func _make_rain_splash_texture(variant: int) -> Texture2D:
	var texture_size := 96
	var image := Image.create(texture_size, texture_size, false, Image.FORMAT_RGBA8)
	var center := Vector2(texture_size * 0.5, texture_size * 0.5)
	for y in range(texture_size):
		for x in range(texture_size):
			var offset := Vector2(x, y) - center
			var distance: float = offset.length()
			var angle: float = atan2(offset.y, offset.x)
			var alpha: float = 0.0
			alpha += _ring_alpha(distance, 22.0 + variant * 1.4, 1.5)
			alpha += _ring_alpha(distance, 32.0 - variant * 1.1, 1.7) * 0.65
			alpha += _ring_alpha(distance, 12.0 + variant, 1.35) * 0.38
			var broken: float = 0.55 + 0.45 * sin(angle * float(variant + 3) + distance * 0.19)
			var sparkle: float = 0.0
			for spoke in range(4):
				var spoke_angle: float = TAU * float(spoke) / 4.0 + variant * 0.31
				var spoke_diff: float = abs(wrapf(angle - spoke_angle, -PI, PI))
				sparkle = max(sparkle, max(0.0, 1.0 - spoke_diff / 0.08) * max(0.0, 1.0 - distance / 38.0))
			alpha = min(1.0, alpha * broken + sparkle * 0.34)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(image)

func _ring_alpha(distance: float, radius: float, width: float) -> float:
	return exp(-pow((distance - radius) / max(0.1, width), 2.0))

func _hash01(value: int) -> float:
	return fposmod(sin(float(value) * 12.9898) * 43758.5453, 1.0)

func _headlight_weather_factor(world_pos: Vector2) -> float:
	var forward := Vector2.RIGHT.rotated(game.vehicle_angle)
	if game.is_traveling and game.vehicle_velocity.length() > 2.0:
		forward = game.vehicle_velocity.normalized()
	var side := forward.orthogonal()
	var relative: Vector2 = world_pos - game.player_pos
	var along: float = relative.dot(forward)
	if along <= 0.0 or along > 700.0:
		return 0.0
	var lateral: float = abs(relative.dot(side))
	var spread: float = along * 0.54 + 38.0
	var cone: float = clamp(1.0 - lateral / spread, 0.0, 1.0)
	var distance_fade: float = clamp(1.0 - along / 700.0, 0.0, 1.0)
	return pow(cone, 1.15) * pow(distance_fade, 0.55)

func _draw_node_labels() -> void:
	for i in range(game.districts.size()):
		var d = game.districts[i]
		var pos = _to_screen(d.pos)
		var label_pos = pos + Vector2(26, -9)
		draw_string(get_theme_default_font(), label_pos, d.name, HORIZONTAL_ALIGNMENT_LEFT, 210, 13, Color("#e7ecef"))
		var stats = "W%d E%d S%d" % [d.water, d.power, d.security]
		draw_string(get_theme_default_font(), label_pos + Vector2(0, 17), stats, HORIZONTAL_ALIGNMENT_LEFT, 150, 11, Color("#aebbc2"))

func _draw_vehicle() -> void:
	var pos: Vector2 = _to_screen(game.player_pos)
	var angle: float = game.vehicle_angle
	if game.is_traveling and game.vehicle_velocity.length() > 2.0:
		angle = game.vehicle_velocity.angle()
	_update_vehicle_node(pos, angle)

	if vehicle_root == null:
		_draw_fallback_vehicle(pos, angle)
		_draw_vehicle_lights(pos, angle)

func _update_road_bump(delta: float) -> void:
	if game == null or not game.is_traveling or game.vehicle_current_speed < 35.0:
		bump_phase = max(0.0, bump_phase - delta * 3.0)
		return
	bump_timer -= delta
	if bump_timer <= 0.0:
		bump_timer = road_bump_rng.randf_range(0.55, 1.8)
		bump_duration = road_bump_rng.randf_range(0.28, 0.58)
		bump_strength = road_bump_rng.randf_range(1.0, 2.9)
		if road_bump_rng.randf() < 0.55:
			var roll_side: float = -1.0 if road_bump_rng.randi_range(0, 1) == 0 else 1.0
			bump_roll_strength = roll_side * road_bump_rng.randf_range(0.65, 1.35)
		else:
			bump_roll_strength = 0.0
		bump_phase = bump_duration
	if bump_phase > 0.0:
		bump_phase = max(0.0, bump_phase - delta)

func _update_headlight_glitch(delta: float) -> void:
	if headlight_glitch_phase > 0.0:
		headlight_glitch_phase = max(0.0, headlight_glitch_phase - delta)
		return
	headlight_glitch_timer -= delta
	if headlight_glitch_timer <= 0.0:
		headlight_glitch_timer = road_bump_rng.randf_range(8.0, 18.0)
		headlight_glitch_duration = road_bump_rng.randf_range(0.22, 0.55)
		headlight_glitch_phase = headlight_glitch_duration
		headlight_glitch_side = road_bump_rng.randi_range(0, 1)

func _headlight_glitch_multiplier(side: int) -> float:
	if headlight_glitch_phase <= 0.0 or side != headlight_glitch_side or headlight_glitch_duration <= 0.0:
		return 1.0
	var t: float = 1.0 - headlight_glitch_phase / headlight_glitch_duration
	var envelope: float = sin(t * PI)
	var flicker: float = 0.5 + 0.5 * sin(t * TAU * 18.0)
	var blackout: float = 1.0 if flicker >= 0.42 else 0.22
	return lerp(1.0, blackout, envelope)

func _bump_pitch() -> float:
	if bump_phase <= 0.0 or bump_duration <= 0.0:
		return 0.0
	var t: float = 1.0 - bump_phase / bump_duration
	return sin(t * PI) * sin(t * TAU * 1.35) * bump_strength

func _bump_rotation() -> float:
	if bump_phase <= 0.0 or bump_duration <= 0.0:
		return 0.0
	var t: float = 1.0 - bump_phase / bump_duration
	return sin(t * TAU * 1.35) * sin(t * PI) * bump_strength * 0.0028

func _bump_roll() -> float:
	if bump_phase <= 0.0 or bump_duration <= 0.0:
		return 0.0
	var t: float = 1.0 - bump_phase / bump_duration
	return sin(t * PI) * sin(t * TAU * 1.1) * bump_roll_strength

func _update_vehicle_lights() -> void:
	_update_vehicle_node()

func _update_pirate(delta: float) -> void:
	if pirate_root == null or game == null:
		return
	if game.at_location:
		pirate_spawn_timer = min(pirate_spawn_timer, 7.0)
		_despawn_pirate()
		return
	if not pirate_active:
		if not game.is_traveling:
			return
		pirate_spawn_timer -= delta
		if pirate_spawn_timer <= 0.0:
			if road_bump_rng.randf() < 0.45:
				_spawn_pirate()
			pirate_spawn_timer = road_bump_rng.randf_range(12.0, 26.0)
			return
	pirate_root.visible = true
	_update_pirate_motion(delta)
	if not pirate_active:
		return
	_update_pirate_laser(delta)
	_update_pirate_node()

func _spawn_pirate() -> void:
	var player_forward: Vector2 = Vector2.RIGHT.rotated(game.vehicle_angle)
	if game.vehicle_velocity.length() > 2.0:
		player_forward = game.vehicle_velocity.normalized()
	var side: Vector2 = player_forward.orthogonal()
	pirate_pos = game.player_pos - player_forward * road_bump_rng.randf_range(420.0, 640.0) + side * road_bump_rng.randf_range(-180.0, 180.0)
	pirate_pos.x = clamp(pirate_pos.x, 0.0, WORLD_SIZE.x)
	pirate_pos.y = clamp(pirate_pos.y, 0.0, WORLD_SIZE.y)
	pirate_angle = player_forward.angle()
	pirate_speed = road_bump_rng.randf_range(145.0, 190.0)
	pirate_fire_timer = road_bump_rng.randf_range(1.2, 3.0)
	pirate_fire_phase = 0.0
	pirate_active = true
	pirate_root.visible = true
	_update_pirate_node()

func _update_pirate_motion(delta: float) -> void:
	var to_player: Vector2 = game.player_pos - pirate_pos
	var distance: float = to_player.length()
	if distance > 1500.0:
		_despawn_pirate()
		return
	if distance <= 1.0:
		return
	var desired_angle: float = to_player.angle()
	var angle_delta: float = wrapf(desired_angle - pirate_angle, -PI, PI)
	var turn_rate: float = 1.9
	pirate_angle += clamp(angle_delta, -turn_rate * delta, turn_rate * delta)
	var target_speed: float = clamp(distance * 0.42, 95.0, pirate_speed)
	if distance < 190.0:
		target_speed = 70.0
	pirate_pos += Vector2.RIGHT.rotated(pirate_angle) * target_speed * delta
	pirate_pos.x = clamp(pirate_pos.x, 0.0, WORLD_SIZE.x)
	pirate_pos.y = clamp(pirate_pos.y, 0.0, WORLD_SIZE.y)

func _update_pirate_laser(delta: float) -> void:
	if not pirate_active or not pirate_root.visible:
		pirate_laser_root.visible = false
		pirate_laser_light.energy = 0.0
		for laser_light in pirate_laser_lights:
			laser_light.energy = 0.0
		return
	if pirate_fire_phase > 0.0:
		pirate_fire_phase = max(0.0, pirate_fire_phase - delta)
	else:
		pirate_fire_timer -= delta
		if pirate_fire_timer <= 0.0:
			pirate_fire_duration = road_bump_rng.randf_range(0.14, 0.28)
			pirate_fire_phase = pirate_fire_duration
			pirate_laser_blur = road_bump_rng.randf_range(0.72, 1.45)
			pirate_laser_damage_applied = false
			pirate_fire_timer = road_bump_rng.randf_range(2.3, 5.2)
	var firing: bool = pirate_fire_phase > 0.0
	pirate_laser_root.visible = firing
	if not firing:
		pirate_laser_damage_applied = false
		pirate_laser_light.energy = 0.0
		for laser_light in pirate_laser_lights:
			laser_light.energy = 0.0
		return
	if not pirate_laser_damage_applied:
		var damage_amount: int = road_bump_rng.randi_range(7, 12)
		var damage_pos: Vector2 = game.player_pos
		game.hull = clampi(game.hull - damage_amount, 0, 100)
		pirate_laser_damage_applied = true
		game._refresh()
		_update_health_bar_node(_to_screen(game.player_pos))
		_spawn_damage_popup(damage_amount, damage_pos, clamp(float(game.hull) / 100.0, 0.0, 1.0))
	var to_player: Vector2 = game.player_pos - pirate_pos
	var cannon_forward: Vector2 = to_player.normalized() if to_player.length() > 0.01 else Vector2.RIGHT.rotated(pirate_angle)
	pirate_laser_start = pirate_pos + cannon_forward * 28.0
	pirate_laser_end = game.player_pos
	var laser_alpha: float = sin((1.0 - pirate_fire_phase / max(0.01, pirate_fire_duration)) * PI)
	var jitter: Vector2 = cannon_forward.orthogonal() * sin(Time.get_ticks_msec() * 0.031) * 3.5 * pirate_laser_blur
	var start_screen: Vector2 = _to_screen(pirate_laser_start)
	var end_screen: Vector2 = _to_screen(pirate_laser_end)
	pirate_laser_outer_glow.width = 26.0 * pirate_laser_blur
	pirate_laser_outer_glow.default_color = Color("#ff2020", 0.08 + laser_alpha * 0.10)
	pirate_laser_glow.width = 15.0 * pirate_laser_blur
	pirate_laser_glow.default_color = Color("#ff2424", 0.18 + laser_alpha * 0.28)
	pirate_laser_inner_glow.width = 7.0 * pirate_laser_blur
	pirate_laser_inner_glow.default_color = Color("#ff4545", 0.28 + laser_alpha * 0.24)
	pirate_laser_line.default_color = Color("#ff6868", 0.76 + laser_alpha * 0.24)
	pirate_laser_outer_glow.points = PackedVector2Array([start_screen - jitter, end_screen + jitter])
	pirate_laser_glow.points = PackedVector2Array([start_screen + jitter * 0.45, end_screen - jitter * 0.45])
	pirate_laser_inner_glow.points = PackedVector2Array([start_screen - jitter * 0.2, end_screen + jitter * 0.2])
	pirate_laser_line.points = PackedVector2Array([start_screen, end_screen])
	pirate_laser_light.position = (start_screen + end_screen) * 0.5
	pirate_laser_light.energy = 3.2 + laser_alpha * 2.2
	pirate_laser_light.texture_scale = 3.8 + laser_alpha * 1.4
	for i in range(pirate_laser_lights.size()):
		var laser_light: PointLight2D = pirate_laser_lights[i]
		var t: float = float(i + 1) / float(pirate_laser_lights.size() + 1)
		laser_light.position = _to_screen(pirate_laser_start.lerp(pirate_laser_end, t))
		laser_light.energy = 1.6 + laser_alpha * 1.4
		laser_light.texture_scale = 1.75 + laser_alpha * 0.65

func _despawn_pirate() -> void:
	pirate_active = false
	pirate_fire_phase = 0.0
	pirate_laser_damage_applied = false
	pirate_pos = Vector2(-10000.0, -10000.0)
	if pirate_root != null:
		pirate_root.visible = false
		pirate_root.position = pirate_pos
	if pirate_laser_root != null:
		pirate_laser_root.visible = false
	if pirate_laser_light != null:
		pirate_laser_light.energy = 0.0
	for laser_light in pirate_laser_lights:
		laser_light.energy = 0.0
	if pirate_health_bar_root != null:
		pirate_health_bar_root.visible = false

func _update_pirate_node() -> void:
	if not pirate_active:
		return
	var screen_pos: Vector2 = _to_screen(pirate_pos)
	var to_player: Vector2 = game.player_pos - pirate_pos
	var cannon_angle: float = to_player.angle() if to_player.length() > 0.01 else pirate_angle
	pirate_root.position = screen_pos
	pirate_root.rotation = pirate_angle + PI * 0.5
	pirate_front_left_light.position = Vector2(-7, -31)
	pirate_front_right_light.position = Vector2(7, -31)
	pirate_front_left_light.rotation = -PI * 0.5
	pirate_front_right_light.rotation = -PI * 0.5
	pirate_front_left_light.energy = 0.82
	pirate_front_right_light.energy = 0.82
	pirate_front_left_light.texture_scale = 0.94
	pirate_front_right_light.texture_scale = 0.94
	pirate_front_overlay_sprite.modulate = Color(1.0, 1.0, 1.0, 0.92)
	pirate_back_overlay_sprite.modulate = Color(1.0, 1.0, 1.0, 0.45)
	pirate_rear_left_light.position = Vector2(-8, 30)
	pirate_rear_right_light.position = Vector2(8, 30)
	pirate_rear_left_light.energy = 0.34
	pirate_rear_right_light.energy = 0.34
	pirate_cannon_sprite.rotation = cannon_angle - pirate_angle
	_update_pirate_health_bar_node(screen_pos)

func _update_pirate_health_bar_node(screen_pos: Vector2) -> void:
	if pirate_health_bar_root == null:
		return
	var bar_width: float = 62.0
	var health_ratio: float = clamp(float(pirate_hull) / 100.0, 0.0, 1.0)
	var fill_width: float = max(1.0, bar_width * health_ratio)
	var health_color: Color = _health_color(health_ratio)
	pirate_health_bar_root.visible = pirate_active
	pirate_health_bar_root.position = screen_pos + Vector2(-bar_width * 0.5, -58.0)
	pirate_health_bar_glow.points = PackedVector2Array([Vector2.ZERO, Vector2(fill_width, 0.0)])
	pirate_health_bar_fill.points = pirate_health_bar_glow.points
	pirate_health_bar_glow.default_color = _color_with_alpha(health_color, lerp(0.16, 0.30, health_ratio))
	pirate_health_bar_fill.default_color = _color_with_alpha(health_color.lightened(0.22), lerp(0.68, 1.0, health_ratio))
	pirate_health_bar_light.color = health_color
	pirate_health_bar_light.position = Vector2(fill_width * 0.5, 0.0)
	pirate_health_bar_light.energy = lerp(0.72, 1.55, health_ratio)
	pirate_health_bar_light.texture_scale = lerp(1.05, 1.95, health_ratio)

func _update_destination_marker() -> void:
	if destination_marker_root == null or game == null:
		return
	if not game.is_traveling:
		destination_marker_root.visible = false
		return
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.004)
	var outer_radius: float = lerp(18.0, 25.0, pulse)
	var core_radius: float = lerp(7.0, 10.0, pulse)
	destination_marker_root.visible = true
	destination_marker_root.position = _to_screen(game.travel_final_pos)
	destination_marker_glow.polygon = _make_circle_polygon(outer_radius, 48)
	destination_marker_glow.color = Color("#dfffd8", lerp(0.09, 0.18, pulse))
	destination_marker_core.polygon = _make_circle_polygon(core_radius, 40)
	destination_marker_core.color = Color("#f5fff1", lerp(0.22, 0.34, pulse))
	destination_marker_ring.points = _make_ring_points(lerp(14.0, 19.0, pulse), 48)
	destination_marker_ring.default_color = Color("#f8fff4", lerp(0.52, 0.78, pulse))
	destination_marker_light.energy = lerp(0.62, 1.05, pulse)
	destination_marker_light.texture_scale = lerp(1.15, 1.65, pulse)

func _update_vehicle_node(screen_pos = null, angle = null) -> void:
	if vehicle_root == null:
		return
	var pos = _to_screen(game.player_pos) if screen_pos == null else screen_pos
	var vehicle_angle = game.vehicle_angle if angle == null else angle
	if game.is_traveling and game.vehicle_velocity.length() > 2.0 and angle == null:
		vehicle_angle = game.vehicle_velocity.angle()
	var pitch: float = _bump_pitch()
	var roll: float = _bump_roll()
	vehicle_root.position = pos
	vehicle_root.rotation = vehicle_angle + PI * 0.5 + _bump_rotation()
	vehicle_root.scale = Vector2(1.0 + abs(pitch) * 0.005 + abs(roll) * 0.003, 1.0 - abs(pitch) * 0.006)
	vehicle_root.skew = roll * 0.032
	var wheel_angle = game.vehicle_steer * 0.75
	wheel_left_pivot.rotation = wheel_angle
	wheel_right_pivot.rotation = wheel_angle

	var headlight_pitch: float = clamp(pitch / max(0.1, bump_strength), -1.0, 1.0) if bump_strength > 0.0 else 0.0
	var headlight_bounce: float = abs(headlight_pitch)
	var headlight_roll: float = clamp(roll, -1.0, 1.0)
	var front_energy: float = (0.88 + headlight_bounce * 0.42) if game.is_traveling else 0.38
	var left_bounce: float = headlight_bounce + max(0.0, headlight_roll) * 0.25
	var right_bounce: float = headlight_bounce + max(0.0, -headlight_roll) * 0.25
	front_left_light.position = Vector2(-7, -31 - left_bounce * 6.0)
	front_right_light.position = Vector2(7, -31 - right_bounce * 6.0)
	front_left_light.rotation = -PI * 0.5
	front_right_light.rotation = -PI * 0.5
	front_left_light.energy = front_energy * (1.0 + max(0.0, headlight_roll) * 0.22) * _headlight_glitch_multiplier(0)
	front_right_light.energy = front_energy * (1.0 + max(0.0, -headlight_roll) * 0.22) * _headlight_glitch_multiplier(1)
	front_left_light.texture_scale = 0.94 + left_bounce * 0.28
	front_right_light.texture_scale = 0.94 + right_bounce * 0.28
	front_left_light.enabled = true
	front_right_light.enabled = true
	front_overlay_sprite.visible = true
	var front_overlay_alpha: float = 1.0 if game.is_traveling else 0.46
	front_overlay_sprite.modulate = Color(1.0, 1.0, 1.0, front_overlay_alpha)

	var brake_energy := 1.35 if game.vehicle_is_braking else 0.48
	var rear_energy := brake_energy if (game.vehicle_is_braking or not game.is_traveling) else 0.0
	rear_left_light.position = Vector2(-8, 30)
	rear_right_light.position = Vector2(8, 30)
	rear_left_light.energy = rear_energy
	rear_right_light.energy = rear_energy
	rear_left_light.texture_scale = 0.24 if game.vehicle_is_braking else 0.16
	rear_right_light.texture_scale = rear_left_light.texture_scale
	rear_left_light.enabled = rear_energy > 0.0
	rear_right_light.enabled = rear_energy > 0.0
	back_overlay_sprite.visible = not game.is_traveling or game.vehicle_is_braking
	_update_health_bar_node(pos)

func _update_health_bar_node(screen_pos: Vector2) -> void:
	if health_bar_root == null or game == null:
		return
	var bar_size := Vector2(68.0, 8.0)
	var health_ratio: float = clamp(float(game.hull) / 100.0, 0.0, 1.0)
	var fill_width: float = max(1.0, bar_size.x * health_ratio)
	var health_color: Color = _health_color(health_ratio)
	health_bar_root.position = screen_pos + Vector2(-bar_size.x * 0.5, -62.0)
	health_bar_root.visible = true
	health_bar_bg.polygon = _make_rect_polygon(Vector2.ZERO, bar_size)
	health_bar_fill.polygon = _make_rect_polygon(Vector2.ZERO, Vector2(fill_width, bar_size.y))
	health_bar_glow.polygon = _make_rect_polygon(Vector2(-8.0, -7.0), Vector2(fill_width + 16.0, bar_size.y + 14.0))
	health_bar_aura.polygon = _make_rect_polygon(Vector2(-28.0, -22.0), Vector2(fill_width + 56.0, bar_size.y + 44.0))
	health_bar_aura.color = _color_with_alpha(health_color, lerp(0.08, 0.18, health_ratio))
	health_bar_glow.color = _color_with_alpha(health_color, lerp(0.18, 0.42, health_ratio))
	health_bar_fill.color = _color_with_alpha(health_color.lightened(0.18), lerp(0.72, 1.0, health_ratio))
	health_bar_line_glow.points = PackedVector2Array([Vector2.ZERO, Vector2(fill_width, 0.0)])
	health_bar_line_fill.points = health_bar_line_glow.points
	health_bar_line_glow.default_color = _color_with_alpha(health_color, lerp(0.16, 0.30, health_ratio))
	health_bar_line_fill.default_color = _color_with_alpha(health_color.lightened(0.22), lerp(0.70, 1.0, health_ratio))
	health_bar_light.color = health_color
	health_bar_light.position = Vector2(fill_width * 0.5, bar_size.y * 0.5)
	health_bar_light.energy = lerp(1.05, 2.2, health_ratio)
	health_bar_light.texture_scale = lerp(1.55, 2.65, health_ratio)
	health_bar_border.points = PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(bar_size.x, 0.0),
		Vector2(bar_size.x, bar_size.y),
		Vector2(0.0, bar_size.y),
		Vector2(0.0, 0.0)
	])

func _health_color(health_ratio: float) -> Color:
	var red := Color("#ff3d3d")
	var yellow := Color("#ffd166")
	var green := Color("#65ff91")
	if health_ratio < 0.5:
		return red.lerp(yellow, health_ratio / 0.5)
	return yellow.lerp(green, (health_ratio - 0.5) / 0.5)

func _color_with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)

func _spawn_damage_popup(amount: int, world_pos: Vector2, health_ratio: float) -> void:
	var label := Label.new()
	label.text = "-%d" % amount
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 72
	label.z_as_relative = false
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(86.0, 44.0)
	label.pivot_offset = label.size * 0.5
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_shadow_color", Color("#06130b", 0.80))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(label)

	var damage_color: Color = _health_color(health_ratio).lightened(0.12)
	damage_popups.append({
		"label": label,
		"world_pos": world_pos,
		"age": 0.0,
		"life": 1.0,
		"color": damage_color
	})
	_update_damage_popup_label(damage_popups[damage_popups.size() - 1])

func _update_damage_popups(delta: float) -> void:
	for i in range(damage_popups.size() - 1, -1, -1):
		var popup: Dictionary = damage_popups[i]
		var label: Label = popup["label"] as Label
		if not is_instance_valid(label):
			damage_popups.remove_at(i)
			continue

		var age: float = float(popup["age"]) + delta
		popup["age"] = age
		damage_popups[i] = popup
		_update_damage_popup_label(popup)

		var life: float = float(popup["life"])
		if age >= life:
			label.queue_free()
			damage_popups.remove_at(i)

func _update_damage_popup_label(popup: Dictionary) -> void:
	var label: Label = popup["label"] as Label
	if not is_instance_valid(label):
		return
	var age: float = float(popup["age"])
	var life: float = max(0.01, float(popup["life"]))
	var t: float = clamp(age / life, 0.0, 1.0)
	var world_pos: Vector2 = popup["world_pos"]
	var screen_pos: Vector2 = _to_screen(world_pos)
	var base_color: Color = popup["color"]
	var fade: float = 1.0 - smoothstep(0.18, 1.0, t)
	label.position = screen_pos + Vector2(-43.0, -82.0)
	label.scale = Vector2.ONE * lerp(0.82, 1.55, t)
	label.modulate = Color(base_color.r, base_color.g, base_color.b, fade)

func _make_rect_polygon(position: Vector2, rect_size: Vector2) -> PackedVector2Array:
	return PackedVector2Array([
		position,
		position + Vector2(rect_size.x, 0.0),
		position + rect_size,
		position + Vector2(0.0, rect_size.y)
	])

func _update_world_nodes(delta: float) -> void:
	if world_root == null or game == null:
		return
	var hover_lerp: float = clamp(delta * 8.0, 0.0, 1.0)
	world_root.position = -camera_offset

	for i in range(heat_nodes.size()):
		var d = game.districts[i]
		var water = float(d.water) / 100.0
		var color = Color("#b55a45").lerp(Color("#3fa7c9"), water)
		heat_nodes[i].color = Color(color.r, color.g, color.b, 0.10)

	for key in route_lines.keys():
		var entry = route_lines[key]
		var line: Line2D = entry.line
		var from: int = entry.from
		var to: int = entry.to
		var is_current_route: bool = game.at_location and (from == game.current_district or to == game.current_district)
		line.default_color = Color("#d8e4e5", 0.18) if is_current_route else Color("#d8e4e5", 0.12)
		line.width = 10.5 if is_current_route else 7.5

	for entry in district_nodes:
		var index: int = entry.index
		var marker: Polygon2D = entry.marker
		var ring: Line2D = entry.ring
		var sprite: Sprite2D = entry.sprite
		var light_sprite: Sprite2D = entry.light_sprite
		var location_glow: PointLight2D = entry.location_glow
		var has_sprite: bool = entry.sprite != null
		var is_hovered: bool = index == hovered_district
		var is_selected: bool = index == game.selected_district
		var radius: float = 32.0 if has_sprite else (24.0 if game.at_location and index == game.current_district else 17.0)
		marker.polygon = _make_circle_polygon(radius, 32)
		marker.color = Color(game.FACTIONS[game.districts[index].faction].color, 0.0) if has_sprite else game.FACTIONS[game.districts[index].faction].color
		if sprite != null:
			var target_modulate := Color.WHITE
			var target_scale := Vector2(0.208, 0.208)
			if is_hovered:
				target_modulate = Color(1.22, 1.22, 1.14, 1.0)
				target_scale = Vector2(0.220, 0.220)
			elif is_selected:
				target_modulate = Color(1.08, 1.08, 1.04, 1.0)
				target_scale = Vector2(0.214, 0.214)
			sprite.modulate = sprite.modulate.lerp(target_modulate, hover_lerp)
			sprite.scale = sprite.scale.lerp(target_scale, hover_lerp)
			if light_sprite != null:
				var time: float = Time.get_ticks_msec() * 0.001
				var flicker: float = 0.82 + sin(time * 1.15 + float(index) * 1.7) * 0.018 + sin(time * 2.4 + float(index)) * 0.010
				light_sprite.scale = sprite.scale
				light_sprite.modulate = Color(1.0, 0.88, 0.55, flicker)
				if location_glow != null:
					var glow_wave: float = 0.5 + 0.5 * sin(time * 0.55 + float(index) * 0.9)
					location_glow.energy = lerp(0.58, 0.68, glow_wave)
					location_glow.texture_scale = lerp(2.35, 2.85, glow_wave)
		var target_ring_radius: float = radius + 4.0
		var target_ring_color := Color("#e7ecef", 0.75)
		var target_ring_width: float = 2.0
		if is_hovered:
			target_ring_radius = radius + 13.0
			target_ring_color = Color("#f4f1de", 0.62)
			target_ring_width = 3.0
		elif is_selected:
			target_ring_radius = radius + 9.0
			target_ring_color = Color("#e7ecef", 0.62)
			target_ring_width = 2.5
		var current_ring_radius: float = ring.points[0].length() if ring.points.size() > 0 else target_ring_radius
		ring.points = _make_ring_points(lerp(current_ring_radius, target_ring_radius, hover_lerp), 48)
		ring.default_color = ring.default_color.lerp(target_ring_color, hover_lerp)
		ring.width = lerp(ring.width, target_ring_width, hover_lerp)

func _update_cloud_props(delta: float) -> void:
	if clouds_root == null or game == null:
		return
	while cloud_textures.size() > 0 and cloud_props.size() < CLOUD_POOL_SIZE:
		_spawn_cloud_prop()
	_update_cloud_visibility(delta)

func _reset_cloud_wind() -> void:
	var angle: float = cloud_rng.randf_range(-0.65, 0.35)
	var speed: float = cloud_rng.randf_range(5.0, 10.0)
	cloud_wind_velocity = Vector2.RIGHT.rotated(angle) * speed

func _spawn_cloud_prop() -> void:
	var sprite := Sprite2D.new()
	var texture: Texture2D = cloud_textures[cloud_rng.randi_range(0, cloud_textures.size() - 1)]
	sprite.texture = texture
	sprite.rotation = cloud_rng.randf_range(-0.35, 0.35)
	sprite.scale = Vector2.ONE * cloud_rng.randf_range(0.36, 0.76)
	sprite.modulate = Color(1, 1, 1, 0)
	sprite.z_index = 1
	clouds_root.add_child(sprite)
	var drift_scale: float = cloud_rng.randf_range(0.75, 1.25)
	var prop := {
		"sprite": sprite,
		"velocity": cloud_wind_velocity * drift_scale,
		"max_alpha": cloud_rng.randf_range(0.52, 0.90),
		"age": 0.0
	}
	cloud_props.append(prop)
	_reposition_cloud_prop(prop, false)

func _update_cloud_visibility(delta: float) -> void:
	var stale: Array = []
	for prop in cloud_props:
		var sprite: Sprite2D = prop["sprite"]
		if not is_instance_valid(sprite):
			stale.append(prop)
			continue
		var new_age: float = prop["age"] + delta
		prop["age"] = new_age
		sprite.position += prop["velocity"] * delta
		var age: float = new_age
		var max_alpha: float = prop["max_alpha"]
		var fade_in: float = clamp(age / 1.2, 0.0, 1.0)
		var light_factor: float = _city_cloud_light_factor(sprite.position)
		var route_light_factor: float = _route_cloud_light_factor(sprite.position)
		var health_light_factor: float = _health_cloud_light_factor(sprite.position)
		var laser_light_factor: float = _laser_cloud_light_factor(sprite.position)
		var destination_light_factor: float = _destination_cloud_light_factor(sprite.position)
		var target_alpha: float = max_alpha * fade_in * lerp(1.0, 1.34, light_factor)
		target_alpha *= lerp(1.0, 1.04, route_light_factor)
		target_alpha *= lerp(1.0, 1.65, health_light_factor)
		target_alpha *= lerp(1.0, 1.85, laser_light_factor)
		target_alpha *= lerp(1.0, 1.50, destination_light_factor)
		target_alpha = min(target_alpha, 0.95)
		var target_tint: Color = Color(0.88, 0.96, 0.98, 1.0).lerp(Color(1.0, 0.72, 0.36, 1.0), light_factor * 0.85)
		target_tint = target_tint.lerp(Color(0.44, 1.0, 0.66, 1.0), route_light_factor * 0.12)
		target_tint = target_tint.lerp(Color(0.36, 1.0, 0.56, 1.0), health_light_factor)
		target_tint = target_tint.lerp(Color(1.0, 0.18, 0.16, 1.0), laser_light_factor)
		target_tint = target_tint.lerp(Color(0.92, 1.0, 0.86, 1.0), destination_light_factor)
		var color: Color = sprite.modulate
		var tint_lerp: float = clamp(delta * 2.4, 0.0, 1.0)
		color.r = lerp(color.r, target_tint.r, tint_lerp)
		color.g = lerp(color.g, target_tint.g, tint_lerp)
		color.b = lerp(color.b, target_tint.b, tint_lerp)
		color.a = lerp(color.a, target_alpha, 0.10)
		sprite.modulate = color
		if not _cloud_visible_bounds().has_point(sprite.position):
			_reposition_cloud_prop(prop, true)
	for prop in stale:
		cloud_props.erase(prop)

func _cloud_visible_bounds() -> Rect2:
	var padding: float = 860.0
	return Rect2(camera_offset - Vector2(padding, padding), size + Vector2(padding * 2.0, padding * 2.0))

func _reposition_cloud_prop(prop: Dictionary, from_wind_edge: bool) -> void:
	var sprite: Sprite2D = prop["sprite"]
	var bounds: Rect2 = _cloud_visible_bounds()
	if not from_wind_edge:
		sprite.position = Vector2(
			cloud_rng.randf_range(bounds.position.x, bounds.end.x),
			cloud_rng.randf_range(bounds.position.y, bounds.end.y)
		)
		return
	var velocity: Vector2 = prop["velocity"]
	var wind: Vector2 = velocity.normalized()
	if wind.length() <= 0.01:
		wind = Vector2.RIGHT
	var side: Vector2 = wind.orthogonal()
	var center: Vector2 = bounds.get_center()
	var half_span: float = max(bounds.size.x, bounds.size.y) * 0.62
	var edge_offset: float = max(bounds.size.x, bounds.size.y) * 0.52
	sprite.position = center - wind * edge_offset + side * cloud_rng.randf_range(-half_span, half_span)
	prop["age"] = 1.2

func _city_cloud_light_factor(world_pos: Vector2) -> float:
	if game == null:
		return 0.0
	var best: float = 0.0
	for district in game.districts:
		var district_name: String = district.name
		if not location_light_textures.has(district_name):
			continue
		var district_pos: Vector2 = district.pos
		var radius: float = 900.0
		if district_name == "Новый Колодец":
			radius = 1080.0
		var distance: float = world_pos.distance_to(district_pos)
		var raw_light: float = clamp(1.0 - distance / radius, 0.0, 1.0)
		best = max(best, raw_light * raw_light)
	return best

func _route_cloud_light_factor(world_pos: Vector2) -> float:
	if current_route_points.size() < 2:
		return 0.0
	var best: float = 0.0
	for i in range(current_route_points.size() - 1):
		var a: Vector2 = current_route_points[i]
		var b: Vector2 = current_route_points[i + 1]
		var segment: Vector2 = b - a
		var segment_len_sq: float = segment.length_squared()
		if segment_len_sq <= 0.01:
			continue
		var t: float = clamp((world_pos - a).dot(segment) / segment_len_sq, 0.0, 1.0)
		var closest: Vector2 = a + segment * t
		var distance: float = world_pos.distance_to(closest)
		var raw_light: float = clamp(1.0 - distance / 190.0, 0.0, 1.0)
		best = max(best, pow(raw_light, 2.2))
	return min(best * 0.18, 1.0)

func _health_cloud_light_factor(world_pos: Vector2) -> float:
	if game == null:
		return 0.0
	var health_ratio: float = clamp(float(game.hull) / 100.0, 0.0, 1.0)
	if health_ratio <= 0.0:
		return 0.0
	var bar_world_pos: Vector2 = game.player_pos + Vector2(0.0, -62.0)
	var distance: float = world_pos.distance_to(bar_world_pos)
	var raw_light: float = clamp(1.0 - distance / 360.0, 0.0, 1.0)
	return pow(raw_light, 1.05) * lerp(0.65, 1.0, health_ratio)

func _destination_cloud_light_factor(world_pos: Vector2) -> float:
	if game == null or not game.is_traveling:
		return 0.0
	var distance: float = world_pos.distance_to(game.travel_final_pos)
	var raw_light: float = clamp(1.0 - distance / 300.0, 0.0, 1.0)
	return pow(raw_light, 1.2)

func _laser_cloud_light_factor(world_pos: Vector2) -> float:
	if pirate_fire_phase <= 0.0:
		return 0.0
	var segment: Vector2 = pirate_laser_end - pirate_laser_start
	var segment_len_sq: float = segment.length_squared()
	if segment_len_sq <= 0.01:
		return 0.0
	var t: float = clamp((world_pos - pirate_laser_start).dot(segment) / segment_len_sq, 0.0, 1.0)
	var closest: Vector2 = pirate_laser_start + segment * t
	var distance: float = world_pos.distance_to(closest)
	var flash: float = sin((1.0 - pirate_fire_phase / max(0.01, pirate_fire_duration)) * PI)
	var raw_light: float = clamp(1.0 - distance / 260.0, 0.0, 1.0)
	return pow(raw_light, 1.15) * lerp(0.55, 1.0, flash)

func _update_travel_route() -> void:
	if travel_route_root == null:
		return
	for child in travel_route_root.get_children():
		child.queue_free()
	if not game.is_traveling:
		current_route_points.clear()
		return
	var route_points := _predict_vehicle_route()
	if route_points.size() < 2:
		current_route_points.clear()
		return
	current_route_points = route_points
	_draw_dashed_polyline(route_points)

func _predict_vehicle_route() -> Array[Vector2]:
	var points: Array[Vector2] = []
	var sim_angle: float = game.vehicle_angle
	if game.is_traveling and game.vehicle_velocity.length() > 2.0:
		sim_angle = game.vehicle_velocity.angle()
	var sim_pos: Vector2 = game.player_pos + Vector2.RIGHT.rotated(sim_angle) * 30.0
	var sim_speed: float = max(55.0, game.vehicle_current_speed)
	var targets: Array[Vector2] = []
	targets.append(game.travel_target_pos)
	for waypoint in game.travel_waypoints:
		targets.append(waypoint as Vector2)
	points.append(sim_pos)
	for target_index in range(targets.size()):
		var target: Vector2 = targets[target_index]
		var reached_target: bool = false
		var max_steps: int = clampi(int(sim_pos.distance_to(target) / max(1.0, sim_speed * 0.10)) + 90, 90, 420)
		for i in range(max_steps):
			var to_target: Vector2 = target - sim_pos
			var distance: float = to_target.length()
			var is_final_target: bool = target_index == targets.size() - 1
			var arrival_distance: float = game.CITY_GATE_ARRIVAL_DISTANCE if game.travel_target_district != -1 and is_final_target else game.WAYPOINT_PASS_RADIUS
			if distance < arrival_distance:
				reached_target = true
				break
			var desired_angle := to_target.angle()
			var angle_delta := wrapf(desired_angle - sim_angle, -PI, PI)
			var steer: float = clamp(angle_delta, -game.vehicle_max_steer, game.vehicle_max_steer)
			sim_angle += (sim_speed / game.vehicle_wheelbase) * tan(steer) * 0.10
			sim_pos += Vector2.RIGHT.rotated(sim_angle) * sim_speed * 0.10
			if i % 3 == 0:
				points.append(sim_pos)
		if reached_target:
			sim_pos = target
			points.append(target)
		else:
			break
	return points

func _draw_dashed_polyline(points: Array[Vector2]) -> void:
	var left_track: Array[Vector2] = []
	var right_track: Array[Vector2] = []
	var track_half_width := 6.0
	for i in range(points.size()):
		var tangent: Vector2
		if i == 0:
			tangent = points[min(i + 1, points.size() - 1)] - points[i]
		elif i == points.size() - 1:
			tangent = points[i] - points[i - 1]
		else:
			tangent = points[i + 1] - points[i - 1]
		if tangent.length() <= 0.01:
			tangent = Vector2.RIGHT
		var normal := tangent.normalized().orthogonal()
		left_track.append(points[i] + normal * track_half_width)
		right_track.append(points[i] - normal * track_half_width)
	_draw_single_dashed_track(left_track)
	_draw_single_dashed_track(right_track)

func _draw_single_dashed_track(points: Array[Vector2]) -> void:
	var dash := 6.0
	var gap := 11.0
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
				var dash_points := PackedVector2Array([a + direction * cursor, a + direction * (cursor + step)])
				var glow := Line2D.new()
				glow.points = dash_points
				glow.width = 4.0
				glow.default_color = Color("#52ff8a", 0.16)
				glow.antialiased = true
				var glow_material := CanvasItemMaterial.new()
				glow_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
				glow.material = glow_material
				travel_route_root.add_child(glow)

				var line := Line2D.new()
				line.points = dash_points
				line.width = 1.35
				line.default_color = Color("#9dffba", 0.58)
				line.antialiased = true
				var line_material := CanvasItemMaterial.new()
				line_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
				line.material = line_material
				travel_route_root.add_child(line)
			cursor += step
			remaining -= step
			if remaining <= 0.01:
				draw_dash = not draw_dash
				remaining = dash if draw_dash else gap

func _draw_vehicle_lights(pos: Vector2, angle: float) -> void:
	var forward := Vector2.RIGHT.rotated(angle)
	var side := Vector2.DOWN.rotated(angle)
	if game.is_traveling:
		var left_lamp = pos + forward * 27 + side * 7
		var right_lamp = pos + forward * 27 - side * 7
		var beam_len := 46.0
		var beam_width := 16.0
		for lamp in [left_lamp, right_lamp]:
			var beam := PackedVector2Array([
				lamp,
				lamp + forward * beam_len + side * beam_width,
				lamp + forward * (beam_len + 14),
				lamp + forward * beam_len - side * beam_width
			])
			draw_colored_polygon(beam, Color("#fff2c2", 0.20))
			draw_circle(lamp, 4.5, Color("#fff6d5", 0.85))
		if game.vehicle_is_braking:
			_draw_tail_lights(pos, forward, side, true)
	else:
		_draw_tail_lights(pos, forward, side, false)

func _draw_tail_lights(pos: Vector2, forward: Vector2, side: Vector2, braking: bool) -> void:
	var left_tail = pos - forward * 27 + side * 7
	var right_tail = pos - forward * 27 - side * 7
	var core = Color("#ff3030", 1.0) if braking else Color("#ff3030", 0.92)
	var glow = Color("#ff3030", 0.32) if braking else Color("#ff3030", 0.18)
	var radius = 5.2 if braking else 4.2
	var glow_radius = 13.0 if braking else 9.0
	draw_circle(left_tail, radius, core)
	draw_circle(right_tail, radius, core)
	draw_circle(left_tail, glow_radius, glow)
	draw_circle(right_tail, glow_radius, glow)

func _draw_fallback_vehicle(pos: Vector2, angle: float) -> void:
	var forward := Vector2.RIGHT.rotated(angle)
	var side := Vector2.DOWN.rotated(angle)
	var body := PackedVector2Array([
		pos + forward * 17,
		pos - forward * 13 + side * 10,
		pos - forward * 18,
		pos - forward * 13 - side * 10
	])
	var outline := PackedVector2Array(body)
	outline.append(body[0])
	draw_colored_polygon(body, Color("#e9c46a"))
	draw_polyline(outline, Color("#1d2327"), 2.0, true)

func _draw_hover_card() -> void:
	if hovered_district == -1:
		return
	var d = game.districts[hovered_district]
	var faction = game.FACTIONS[d.faction]
	var card_pos = hover_screen_pos + Vector2(18, 18)
	var card_size := Vector2(285, 116)
	if card_pos.x + card_size.x > size.x - 12:
		card_pos.x = hover_screen_pos.x - card_size.x - 18
	if card_pos.y + card_size.y > size.y - 12:
		card_pos.y = hover_screen_pos.y - card_size.y - 18
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
	for key in game.FACTIONS.keys():
		var f = game.FACTIONS[key]
		draw_circle(Vector2(x + offset, y), 7, f.color)
		draw_string(get_theme_default_font(), Vector2(x + offset + 12, y + 5), f.title, HORIZONTAL_ALIGNMENT_LEFT, 128, 11, Color("#cfd8dc"))
		offset += 126

func _draw_minimap() -> void:
	var map_size := Vector2(205, 136)
	var pos := Vector2(size.x - map_size.x - 18, 18)
	minimap_rect = Rect2(pos, map_size)
	draw_rect(Rect2(pos, map_size), Color("#0d1215", 0.88), true)
	draw_rect(Rect2(pos, map_size), Color("#e7ecef", 0.25), false, 1.0)
	var scale = min(map_size.x / WORLD_SIZE.x, map_size.y / WORLD_SIZE.y)
	var pad = (map_size - WORLD_SIZE * scale) * 0.5
	for from in game.routes.keys():
		for to in game.routes[from]:
			if from > to:
				continue
			draw_line(pos + pad + game.districts[from].pos * scale, pos + pad + game.districts[to].pos * scale, Color("#506672", 0.55), 1.0, true)
	for i in range(game.districts.size()):
		var d = game.districts[i]
		var radius := 5.0 if game.at_location and i == game.current_district else 3.0
		draw_circle(pos + pad + d.pos * scale, radius, game.FACTIONS[d.faction].color)
	draw_circle(pos + pad + game.player_pos * scale, 4.5, Color("#e9c46a"))
	if pirate_active:
		var pirate_minimap_pos: Vector2 = pos + pad + pirate_pos * scale
		draw_circle(pirate_minimap_pos, 5.0, Color("#ff3030", 0.30))
		draw_circle(pirate_minimap_pos, 3.2, Color("#ff5b5b"))
		draw_arc(pirate_minimap_pos, 6.2, 0.0, TAU, 20, Color("#ffb0b0", 0.85), 1.0)
	var view_rect := Rect2(pos + pad + camera_offset * scale, size * scale)
	draw_rect(view_rect, Color("#f4f1de", 0.08), true)
	draw_rect(view_rect, Color("#f4f1de", 0.80), false, 1.0)
	draw_string(get_theme_default_font(), pos + Vector2(10, map_size.y - 10), "Открыть карту", HORIZONTAL_ALIGNMENT_LEFT, 180, 11, Color("#cfd8dc"))

func _update_hover(screen_pos: Vector2) -> void:
	var world_pos = _to_world(screen_pos)
	var nearest := -1
	var nearest_dist := 999999.0
	for i in range(game.districts.size()):
		var dist = world_pos.distance_to(game.districts[i].pos)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = i
	hovered_district = nearest if nearest_dist <= NODE_HIT_RADIUS else -1
	if hovered_district == -1:
		mouse_default_cursor_shape = Control.CURSOR_CROSS
	else:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	queue_redraw()

func _center_on(world_pos: Vector2) -> void:
	camera_offset = world_pos - size * 0.5
	_clamp_camera()
	queue_redraw()

func _clamp_camera() -> void:
	camera_offset.x = clamp(camera_offset.x, 0.0, max(0.0, WORLD_SIZE.x - size.x))
	camera_offset.y = clamp(camera_offset.y, 0.0, max(0.0, WORLD_SIZE.y - size.y))

func _to_screen(world_pos: Vector2) -> Vector2:
	return world_pos - camera_offset

func _to_world(screen_pos: Vector2) -> Vector2:
	return screen_pos + camera_offset
