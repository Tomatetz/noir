extends Control

const GOODS := {
	"water": {"title": "Вода", "base": 18, "mass": 1},
	"food": {"title": "Еда", "base": 14, "mass": 1},
	"power": {"title": "Аккумуляторы", "base": 28, "mass": 2},
	"meds": {"title": "Медикаменты", "base": 42, "mass": 1},
	"compute": {"title": "Серверные модули", "base": 90, "mass": 3},
	"people": {"title": "Пассажиры", "base": 35, "mass": 2}
}

const FACTIONS := {
	"agro": {"title": "Агрохолдинг", "color": Color("#8aa84f")},
	"city": {"title": "Город-оазис", "color": Color("#38a3a5")},
	"data": {"title": "Дата-центр", "color": Color("#7b68ee")},
	"eco": {"title": "Экоополчение", "color": Color("#63b36f")},
	"pirates": {"title": "Водные пираты", "color": Color("#c94c4c")},
	"observers": {"title": "Наблюдатели", "color": Color("#c7c7c7")}
}

const CITY_ENTRY_RADIUS := 128.0
const CITY_AVOID_RADIUS := 170.0
const CITY_NEAR_ENTRY_RADIUS := 280.0
const CITY_GATE_ARRIVAL_DISTANCE := 54.0
const CITY_EXIT_START_OFFSET := 58.0
const CITY_EXIT_DRIVE_DISTANCE := 115.0
const MIN_FIELD_CLICK_DISTANCE := 78.0
const WAYPOINT_PASS_RADIUS := 58.0
const CITY_ENTRY_DIRECTIONS := [
	Vector2.RIGHT,
	Vector2(0.70710678, 0.70710678),
	Vector2.DOWN,
	Vector2(-0.70710678, 0.70710678),
	Vector2.LEFT,
	Vector2(-0.70710678, -0.70710678),
	Vector2.UP,
	Vector2(0.70710678, -0.70710678)
]

var districts := []
var routes := {}
var current_district := 0
var credits := 520
var day := 1
var capacity := 18
var hull := 100
var water_tank := 10
var battery := 10
var ai_complex := 24
var eco_unrest := 18
var cargo := {}
var missions := []
var accepted_missions := []
var selected_district := -1
var player_pos := Vector2.ZERO
var vehicle_angle := 0.0
var vehicle_target_angle := 0.0
var at_location := true
var is_traveling := false
var travel_from := -1
var travel_to := -1
var travel_target_district := -1
var travel_start_pos := Vector2.ZERO
var travel_final_pos := Vector2.ZERO
var travel_target_pos := Vector2.ZERO
var travel_waypoints: Array[Vector2] = []
var travel_destination_name := ""
var travel_progress := 0.0
var travel_duration := 1.0
var travel_cost := {}
var open_location_after_travel := false
var travel_suppress_arrival_event := false
var vehicle_speed := 180.0
var vehicle_velocity := Vector2.ZERO
var vehicle_current_speed := 0.0
var vehicle_previous_speed := 0.0
var vehicle_is_braking := false
var vehicle_acceleration := 105.0
var vehicle_brake := 190.0
var vehicle_steer := 0.0
var vehicle_max_steer := 0.62
var vehicle_steer_rate := 1.65
var vehicle_wheelbase := 58.0
var rng := RandomNumberGenerator.new()

var root_split: HSplitContainer
var map_panel: Panel
var dashboard_bar: HBoxContainer
var dashboard_tooltip: Label
var modal_layer: CanvasLayer
var modal_panel: PanelContainer
var fullscreen_map_panel: PanelContainer
var fullscreen_map_view: Control
var pause_menu_panel: Control
var right_tabs: TabContainer
var status_label: Label
var location_label: Label
var district_info: RichTextLabel
var event_log: RichTextLabel
var market_list: VBoxContainer
var travel_list: VBoxContainer
var mission_list: VBoxContainer
var accepted_list: VBoxContainer

func _ready() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	rng.seed = 4702
	for good in GOODS:
		cargo[good] = 0
	cargo["water"] = 4
	cargo["food"] = 2
	_build_world()
	player_pos = districts[current_district].pos
	_build_ui()
	_log("Смена начинается в караванном терминале Нового Колодца.")
	_refresh()

func _process(delta: float) -> void:
	if not is_traveling:
		return
	if not travel_target_pos.is_finite() or not player_pos.is_finite():
		_cancel_bad_travel_state()
		return
	var to_target = travel_target_pos - player_pos
	var distance = to_target.length()
	var is_final_leg: bool = travel_waypoints.size() == 0
	var arrival_distance: float = CITY_GATE_ARRIVAL_DISTANCE if travel_target_district != -1 and is_final_leg else WAYPOINT_PASS_RADIUS
	if distance <= arrival_distance:
		map_panel.queue_redraw()
		_reach_travel_point()
		return
	if is_final_leg and distance <= 10.0 and vehicle_current_speed < 38.0:
		map_panel.queue_redraw()
		_reach_travel_point()
		return
	var desired_angle = to_target.angle()
	var angle_delta = wrapf(desired_angle - vehicle_angle, -PI, PI)
	var steer_target = clamp(angle_delta, -vehicle_max_steer, vehicle_max_steer)
	vehicle_steer = move_toward(vehicle_steer, steer_target, vehicle_steer_rate * delta)

	var turn_pressure = abs(angle_delta) / PI
	var target_speed: float = vehicle_speed if not is_final_leg else min(vehicle_speed, max(28.0, distance * 1.15))
	if turn_pressure > 0.42:
		target_speed *= 0.45
	if is_final_leg and distance < 90.0:
		target_speed = min(target_speed, max(22.0, distance * 0.9))
	var rate = vehicle_brake if vehicle_current_speed > target_speed else vehicle_acceleration
	vehicle_previous_speed = vehicle_current_speed
	vehicle_current_speed = move_toward(vehicle_current_speed, target_speed, rate * delta)
	vehicle_is_braking = vehicle_current_speed < vehicle_previous_speed - 0.5 or target_speed < vehicle_previous_speed - 8.0

	if abs(vehicle_steer) > 0.01 and vehicle_current_speed > 1.0:
		vehicle_angle += (vehicle_current_speed / vehicle_wheelbase) * tan(vehicle_steer) * delta

	var forward = Vector2.RIGHT.rotated(vehicle_angle)
	var projected_distance = to_target.dot(forward)
	if projected_distance <= 0.0 and distance < 42.0:
		map_panel.queue_redraw()
		_reach_travel_point()
		return
	vehicle_velocity = forward * vehicle_current_speed
	var step = max(1.0, vehicle_current_speed * delta)
	if distance <= step:
		player_pos += to_target.normalized() * max(0.0, distance - 7.0)
		travel_progress = _route_progress()
	else:
		player_pos += vehicle_velocity * delta
		travel_progress = _route_progress()
	map_panel.queue_redraw()
	if travel_progress >= 1.0:
		_finish_travel()

func _build_world() -> void:
	districts = [
		{"name": "Новый Колодец", "faction": "city", "pos": Vector2(760, 980), "water": 75, "food": 44, "power": 48, "security": 65, "compute": 18},
		{"name": "Сухой Порт", "faction": "pirates", "pos": Vector2(1900, 430), "water": 20, "food": 30, "power": 40, "security": 22, "compute": 12},
		{"name": "Агрокупол N-12", "faction": "agro", "pos": Vector2(2960, 1440), "water": 58, "food": 86, "power": 33, "security": 54, "compute": 22},
		{"name": "Кластер Минерва", "faction": "data", "pos": Vector2(4360, 820), "water": 28, "food": 22, "power": 82, "security": 70, "compute": 88},
		{"name": "Зеленый Кордон", "faction": "eco", "pos": Vector2(3920, 2640), "water": 36, "food": 51, "power": 26, "security": 44, "compute": 10},
		{"name": "Мандат-7", "faction": "observers", "pos": Vector2(2100, 2440), "water": 45, "food": 36, "power": 54, "security": 78, "compute": 45},
		{"name": "Пыльная Развязка", "faction": "pirates", "pos": Vector2(1080, 3000), "water": 17, "food": 24, "power": 31, "security": 18, "compute": 8}
	]
	routes = {
		0: [1, 2, 5, 6],
		1: [0, 2, 3],
		2: [0, 1, 3, 4, 5],
		3: [1, 2, 4],
		4: [2, 3, 5],
		5: [0, 2, 4, 6],
		6: [0, 5]
	}
	_generate_missions()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#111417")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var frame := VBoxContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_constant_override("separation", 8)
	frame.offset_left = 12
	frame.offset_top = 10
	frame.offset_right = -12
	frame.offset_bottom = -10
	add_child(frame)

	var top := HBoxContainer.new()
	top.custom_minimum_size = Vector2(0, 40)
	frame.add_child(top)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.add_theme_font_size_override("font_size", 13)
	status_label.add_theme_color_override("font_color", Color("#cfd8dc"))
	top.add_child(status_label)

	map_panel = Panel.new()
	map_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_panel.clip_contents = true
	frame.add_child(map_panel)

	map_panel.set_script(preload("res://scripts/MapPanel.gd"))
	map_panel.call("bind", self)

	_build_dashboard()
	_build_modal()
	_build_fullscreen_map()
	_build_pause_menu()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if pause_menu_panel != null and pause_menu_panel.visible:
			pause_menu_panel.visible = false
			get_viewport().set_input_as_handled()
		elif fullscreen_map_panel.visible:
			fullscreen_map_panel.visible = false
			get_viewport().set_input_as_handled()
		elif modal_panel.visible:
			_close_modal()
			get_viewport().set_input_as_handled()
		else:
			_open_pause_menu()
			get_viewport().set_input_as_handled()

func _build_dashboard() -> void:
	var dock := MarginContainer.new()
	dock.z_index = 80
	dock.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	dock.offset_left = -254
	dock.offset_top = -74
	dock.offset_right = -18
	dock.offset_bottom = -18
	dock.add_theme_constant_override("margin_left", 8)
	dock.add_theme_constant_override("margin_top", 8)
	dock.add_theme_constant_override("margin_right", 8)
	dock.add_theme_constant_override("margin_bottom", 8)
	add_child(dock)

	var panel := PanelContainer.new()
	dock.add_child(panel)

	dashboard_bar = HBoxContainer.new()
	dashboard_bar.add_theme_constant_override("separation", 6)
	panel.add_child(dashboard_bar)

	_add_dashboard_button("i", "Сводка", 0)
	_add_dashboard_button("$", "Биржа", 1)
	_add_dashboard_button(">", "Маршруты", 2)
	_add_dashboard_button("#", "Контракты", 3)

	dashboard_tooltip = Label.new()
	dashboard_tooltip.z_index = 81
	dashboard_tooltip.visible = false
	dashboard_tooltip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	dashboard_tooltip.offset_left = -254
	dashboard_tooltip.offset_top = -112
	dashboard_tooltip.offset_right = -18
	dashboard_tooltip.offset_bottom = -82
	dashboard_tooltip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dashboard_tooltip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dashboard_tooltip.add_theme_font_size_override("font_size", 14)
	dashboard_tooltip.add_theme_color_override("font_color", Color("#e7ecef"))
	add_child(dashboard_tooltip)

func _add_dashboard_button(icon: String, title: String, tab_index: int) -> void:
	var button := Button.new()
	button.text = icon
	button.tooltip_text = title
	button.custom_minimum_size = Vector2(46, 42)
	button.add_theme_font_size_override("font_size", 18)
	button.mouse_entered.connect(func(): _show_dashboard_tooltip(title))
	button.mouse_exited.connect(_hide_dashboard_tooltip)
	button.pressed.connect(func(): _open_modal(tab_index))
	dashboard_bar.add_child(button)

func _show_dashboard_tooltip(text: String) -> void:
	dashboard_tooltip.text = text
	dashboard_tooltip.visible = true

func _hide_dashboard_tooltip() -> void:
	dashboard_tooltip.visible = false

func _build_modal() -> void:
	_ensure_modal_layer()
	modal_panel = PanelContainer.new()
	modal_panel.visible = false
	modal_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_panel.offset_left = 0
	modal_panel.offset_top = 0
	modal_panel.offset_right = 0
	modal_panel.offset_bottom = 0
	modal_layer.add_child(modal_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	modal_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	var header := HBoxContainer.new()
	box.add_child(header)

	var title := Label.new()
	title.text = "Панель каравана"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("#e7ecef"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_button := Button.new()
	close_button.text = "x"
	close_button.tooltip_text = "Закрыть"
	close_button.custom_minimum_size = Vector2(42, 34)
	close_button.pressed.connect(_close_modal)
	header.add_child(close_button)

	right_tabs = TabContainer.new()
	right_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_tabs.add_theme_font_size_override("font_size", 15)
	box.add_child(right_tabs)

	_build_overview_tab()
	_build_market_tab()
	_build_travel_tab()
	_build_mission_tab()

func _open_modal(tab_index: int) -> void:
	fullscreen_map_panel.visible = false
	if pause_menu_panel != null:
		pause_menu_panel.visible = false
	modal_panel.visible = true
	right_tabs.current_tab = tab_index

func _close_modal() -> void:
	if modal_panel == null:
		return
	modal_panel.visible = false
	if at_location and current_district >= 0 and current_district < districts.size():
		var center: Vector2 = districts[current_district].pos
		var exit_direction: Vector2 = _random_city_exit_direction()
		var exit_start: Vector2 = center + exit_direction * max(12.0, CITY_ENTRY_RADIUS - CITY_EXIT_START_OFFSET)
		var exit_target: Vector2 = center + exit_direction * (CITY_ENTRY_RADIUS + CITY_EXIT_DRIVE_DISTANCE)
		player_pos = exit_start
		vehicle_angle = exit_direction.angle()
		vehicle_target_angle = vehicle_angle
		vehicle_velocity = Vector2.ZERO
		vehicle_current_speed = 0.0
		vehicle_previous_speed = 0.0
		vehicle_is_braking = false
		vehicle_steer = 0.0
		at_location = false
		_travel_to_point(exit_target, -1, "выезд из %s" % districts[current_district].name, false, true)

func _build_fullscreen_map() -> void:
	_ensure_modal_layer()
	fullscreen_map_panel = PanelContainer.new()
	fullscreen_map_panel.visible = false
	fullscreen_map_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fullscreen_map_panel.offset_left = 30
	fullscreen_map_panel.offset_top = 30
	fullscreen_map_panel.offset_right = -30
	fullscreen_map_panel.offset_bottom = -30
	modal_layer.add_child(fullscreen_map_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	fullscreen_map_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	var header := HBoxContainer.new()
	box.add_child(header)

	var title := Label.new()
	title.text = "Карта региона"
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_button := Button.new()
	close_button.text = "x"
	close_button.tooltip_text = "Закрыть"
	close_button.custom_minimum_size = Vector2(42, 34)
	close_button.pressed.connect(func(): fullscreen_map_panel.visible = false)
	header.add_child(close_button)

	fullscreen_map_view = Panel.new()
	fullscreen_map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fullscreen_map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fullscreen_map_view.clip_contents = true
	box.add_child(fullscreen_map_view)
	fullscreen_map_view.set_script(preload("res://scripts/MapPanel.gd"))
	fullscreen_map_view.call("bind", self)
	fullscreen_map_view.call("set_fullscreen_view", true)

func _open_fullscreen_map() -> void:
	modal_panel.visible = false
	if pause_menu_panel != null:
		pause_menu_panel.visible = false
	fullscreen_map_panel.visible = true
	fullscreen_map_view.queue_redraw()

func _is_map_blocked(map_view: Control) -> bool:
	if pause_menu_panel != null and pause_menu_panel.visible:
		return true
	if modal_panel != null and modal_panel.visible:
		return true
	if fullscreen_map_panel != null and fullscreen_map_panel.visible and map_view != fullscreen_map_view:
		return true
	return false

func _ensure_modal_layer() -> void:
	if modal_layer != null:
		return
	modal_layer = CanvasLayer.new()
	modal_layer.layer = 60
	add_child(modal_layer)

func _build_pause_menu() -> void:
	_ensure_modal_layer()
	pause_menu_panel = Control.new()
	pause_menu_panel.visible = false
	pause_menu_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.add_child(pause_menu_panel)

	var dim := ColorRect.new()
	dim.color = Color("#020608", 0.74)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_menu_panel.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_menu_panel.add_child(center)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(320, 0)
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)

	var title := Label.new()
	title.text = "Пауза"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("#f2fbff"))
	box.add_child(title)

	var restart_button := Button.new()
	restart_button.text = "Начать заново"
	restart_button.custom_minimum_size = Vector2(0, 46)
	restart_button.pressed.connect(func(): get_tree().reload_current_scene())
	box.add_child(restart_button)

	var quit_button := Button.new()
	quit_button.text = "Выход"
	quit_button.custom_minimum_size = Vector2(0, 46)
	quit_button.pressed.connect(func(): get_tree().quit())
	box.add_child(quit_button)

func _open_pause_menu() -> void:
	if pause_menu_panel == null:
		return
	if modal_panel != null:
		modal_panel.visible = false
	if fullscreen_map_panel != null:
		fullscreen_map_panel.visible = false
	pause_menu_panel.visible = true

func _make_tab_margin(tab_title: String) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.name = tab_title
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	return margin

func _add_fixed_label(parent: Container, text: String, width: int, color: Color, font_size := 14, alignment := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(width, 0)
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _demand_color(demand: String) -> Color:
	match demand:
		"острый":
			return Color("#f0b35a")
		"кризис":
			return Color("#e46d6d")
		"избыток":
			return Color("#8fcf8f")
		"стратег.":
			return Color("#a999ff")
		_:
			return Color("#c7d0d5")

func _build_overview_tab() -> void:
	var margin := _make_tab_margin("Сводка")
	right_tabs.add_child(margin)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	location_label = Label.new()
	location_label.add_theme_font_size_override("font_size", 17)
	box.add_child(location_label)

	district_info = RichTextLabel.new()
	district_info.fit_content = true
	district_info.bbcode_enabled = true
	district_info.custom_minimum_size = Vector2(0, 230)
	box.add_child(district_info)

	var actions := HBoxContainer.new()
	box.add_child(actions)

	var wait_button := Button.new()
	wait_button.text = "Ждать день"
	wait_button.pressed.connect(func(): _advance_day("Вы переждали сутки и пересчитали маршруты."))
	actions.add_child(wait_button)

	var repair_button := Button.new()
	repair_button.text = "Ремонт 40C"
	repair_button.pressed.connect(_repair)
	actions.add_child(repair_button)

	event_log = RichTextLabel.new()
	event_log.bbcode_enabled = true
	event_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(event_log)

func _build_market_tab() -> void:
	var margin := _make_tab_margin("Биржа")
	right_tabs.add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)

	market_list = VBoxContainer.new()
	market_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	market_list.add_theme_constant_override("separation", 6)
	scroll.add_child(market_list)

func _build_travel_tab() -> void:
	var margin := _make_tab_margin("Маршруты")
	right_tabs.add_child(margin)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	var hint := Label.new()
	hint.text = "Выберите район на карте или отправляйтесь по доступному маршруту."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14)
	box.add_child(hint)

	travel_list = VBoxContainer.new()
	travel_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	travel_list.add_theme_constant_override("separation", 6)
	box.add_child(travel_list)

func _build_mission_tab() -> void:
	var margin := _make_tab_margin("Контракты")
	right_tabs.add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 12)
	scroll.add_child(box)

	var open_title := Label.new()
	open_title.text = "Доска заявок"
	open_title.add_theme_font_size_override("font_size", 17)
	box.add_child(open_title)

	mission_list = VBoxContainer.new()
	mission_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mission_list.add_theme_constant_override("separation", 6)
	box.add_child(mission_list)

	var accepted_title := Label.new()
	accepted_title.text = "В пути"
	accepted_title.add_theme_font_size_override("font_size", 17)
	box.add_child(accepted_title)

	accepted_list = VBoxContainer.new()
	accepted_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	accepted_list.add_theme_constant_override("separation", 6)
	box.add_child(accepted_list)

func _refresh() -> void:
	selected_district = current_district if selected_district == -1 else selected_district
	var movement = " -> %s" % travel_destination_name if is_traveling else ""
	status_label.text = "Д%d | %dC | корпус %d%% | вода %d | заряд %d | груз %d/%d | ИИ %d%% | эко %d%%%s" % [day, credits, hull, water_tank, battery, _cargo_used(), capacity, ai_complex, eco_unrest, movement]
	if is_traveling:
		location_label.text = "В пути: %s" % travel_destination_name
	elif not at_location:
		location_label.text = "В поле: %.0f / %.0f" % [player_pos.x, player_pos.y]
	else:
		location_label.text = "Текущий узел: %s" % districts[current_district].name
	_update_district_info()
	_update_market()
	_update_travel()
	_update_missions()
	map_panel.queue_redraw()

func _update_district_info() -> void:
	var d = districts[selected_district]
	var faction = FACTIONS[d.faction]
	var prices = _prices_for(selected_district)
	var price_text := ""
	for good in GOODS:
		price_text += "%s: %dC  " % [GOODS[good].title, prices[good]]
	district_info.text = "[b]%s[/b]\nФракция: %s\nВода: %d   Еда: %d   Электричество: %d   Безопасность: %d   Вычисления: %d\n\nЦены:\n%s" % [d.name, faction.title, d.water, d.food, d.power, d.security, d.compute, price_text]

func _update_market() -> void:
	for child in market_list.get_children():
		child.queue_free()

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	market_list.add_child(header)
	_add_fixed_label(header, "Товар", 164, Color("#f2f2f2"), 13)
	_add_fixed_label(header, "Цена", 58, Color("#f2f2f2"), 13, HORIZONTAL_ALIGNMENT_RIGHT)
	_add_fixed_label(header, "Трюм", 52, Color("#f2f2f2"), 13, HORIZONTAL_ALIGNMENT_CENTER)
	_add_fixed_label(header, "", 48, Color("#f2f2f2"), 13)
	_add_fixed_label(header, "", 48, Color("#f2f2f2"), 13)
	_add_fixed_label(header, "Спрос", 76, Color("#f2f2f2"), 13)

	var prices = _prices_for(current_district)
	var d = districts[current_district]
	for good in GOODS:
		var demand = _demand_label(d, good)
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 44)
		row.add_theme_constant_override("separation", 8)
		market_list.add_child(row)
		_add_fixed_label(row, GOODS[good].title, 164, Color("#e7ecef"), 14)
		_add_fixed_label(row, "%dC" % prices[good], 58, Color("#e7ecef"), 14, HORIZONTAL_ALIGNMENT_RIGHT)
		_add_fixed_label(row, str(cargo[good]), 52, Color("#d4dde2"), 14, HORIZONTAL_ALIGNMENT_CENTER)
		var buy := Button.new()
		buy.text = "+1"
		buy.custom_minimum_size = Vector2(48, 34)
		buy.add_theme_font_size_override("font_size", 14)
		buy.disabled = credits < prices[good] or _cargo_used() + GOODS[good].mass > capacity
		buy.pressed.connect(func(g: String = good): _buy(g))
		row.add_child(buy)
		var sell := Button.new()
		sell.text = "-1"
		sell.custom_minimum_size = Vector2(48, 34)
		sell.add_theme_font_size_override("font_size", 14)
		sell.disabled = cargo[good] <= 0
		sell.pressed.connect(func(g: String = good): _sell(g))
		row.add_child(sell)
		_add_fixed_label(row, demand, 76, _demand_color(demand), 14)

func _add_market_label(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	market_list.add_child(label)

func _update_travel() -> void:
	for child in travel_list.get_children():
		child.queue_free()
	var targets = routes[current_district] if at_location else range(districts.size())
	for target in targets:
		var box := HBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_theme_constant_override("separation", 8)
		travel_list.add_child(box)
		var d = districts[target]
		var dist = _movement_cost(player_pos, d.pos)
		var danger = _route_danger(target)
		var label := Label.new()
		label.text = "%s | %s | вода %d, заряд %d, риск %d%%" % [d.name, FACTIONS[d.faction].title, dist.water, dist.power, danger]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(label)
		var button := Button.new()
		button.text = "В путь"
		button.disabled = is_traveling or water_tank < dist.water or battery < dist.power or hull <= 0
		button.pressed.connect(func(t: int = target): _travel(t))
		box.add_child(button)

func _update_missions() -> void:
	for node in mission_list.get_children():
		node.queue_free()
	for node in accepted_list.get_children():
		node.queue_free()

	for i in range(missions.size()):
		var m = missions[i]
		var box := _mission_card(m)
		var button := Button.new()
		button.text = "Взять"
		button.disabled = _cargo_used() + GOODS[m.good].mass * m.amount > capacity
		button.pressed.connect(func(index := i): _accept_mission(index))
		box.add_child(button)
		mission_list.add_child(box)

	for m in accepted_missions:
		var box := _mission_card(m)
		var status := Label.new()
		status.text = "Доставить в %s" % districts[m.to].name
		box.add_child(status)
		accepted_list.add_child(box)

func _mission_card(m: Dictionary) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.custom_minimum_size = Vector2(0, 76)
	box.add_theme_constant_override("separation", 4)
	var title := Label.new()
	title.text = "%s -> %s  |  %d x %s" % [districts[m.from].name, districts[m.to].name, m.amount, GOODS[m.good].title]
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.add_theme_font_size_override("font_size", 15)
	box.add_child(title)
	var meta := Label.new()
	meta.text = "Награда %dC, срок %d дн., заказчик: %s" % [m.reward, m.deadline, FACTIONS[districts[m.to].faction].title]
	meta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta.add_theme_color_override("font_color", Color("#b6c2c8"))
	meta.autowrap_mode = TextServer.AUTOWRAP_OFF
	meta.clip_text = true
	meta.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	meta.add_theme_font_size_override("font_size", 13)
	box.add_child(meta)
	return box

func _prices_for(index: int) -> Dictionary:
	var d = districts[index]
	var prices := {}
	for good in GOODS:
		var base = GOODS[good].base
		var pressure := 1.0
		match good:
			"water":
				pressure = 1.85 - float(d.water) / 90.0 + ai_complex / 180.0
			"food":
				pressure = 1.55 - float(d.food) / 110.0 + eco_unrest / 260.0
			"power":
				pressure = 1.45 - float(d.power) / 120.0 + ai_complex / 220.0
			"compute":
				pressure = 1.20 - float(d.compute) / 180.0 + (0.45 if d.faction == "data" else 0.0)
			"meds":
				pressure = 1.0 + (100 - d.security) / 130.0 + eco_unrest / 250.0
			"people":
				pressure = 0.9 + (100 - d.security) / 110.0
		prices[good] = max(3, int(round(base * pressure)))
	return prices

func _demand_label(d: Dictionary, good: String) -> String:
	if good == "water" and d.water < 35:
		return "острый"
	if good == "power" and d.power < 35:
		return "острый"
	if good == "food" and d.food > 70:
		return "избыток"
	if good == "compute" and d.faction == "data":
		return "стратег."
	if d.security < 30 and good in ["meds", "people"]:
		return "кризис"
	return "обычный"

func _buy(good: String) -> void:
	if is_traveling or not at_location:
		return
	var price = _prices_for(current_district)[good]
	if credits >= price and _cargo_used() + GOODS[good].mass <= capacity:
		credits -= price
		cargo[good] += 1
		_log("Куплено: %s за %dC." % [GOODS[good].title, price])
		_refresh()

func _sell(good: String) -> void:
	if is_traveling or not at_location:
		return
	if cargo[good] <= 0:
		return
	var price = _prices_for(current_district)[good]
	credits += price
	cargo[good] -= 1
	_apply_supply_effect(current_district, good, 3)
	_log("Продано: %s за %dC." % [GOODS[good].title, price])
	_check_mission_delivery()
	_refresh()

func _accept_mission(index: int) -> void:
	if is_traveling or not at_location:
		return
	if index < 0 or index >= missions.size():
		return
	var m = missions[index]
	var needed_space = GOODS[m.good].mass * m.amount
	if _cargo_used() + needed_space > capacity:
		return
	cargo[m.good] += m.amount
	accepted_missions.append(m)
	missions.remove_at(index)
	_log("Контракт принят: %s в %s." % [GOODS[m.good].title, districts[m.to].name])
	_refresh()

func _check_mission_delivery() -> void:
	var delivered := []
	for m in accepted_missions:
		if m.to == current_district and cargo[m.good] >= m.amount:
			cargo[m.good] -= m.amount
			credits += m.reward
			_apply_supply_effect(current_district, m.good, m.amount * 5)
			delivered.append(m)
			_log("Контракт закрыт: %s получила %s. Награда %dC." % [districts[m.to].name, GOODS[m.good].title, m.reward])
	for m in delivered:
		accepted_missions.erase(m)

func _travel(target: int, enter_after_arrival := false) -> void:
	var entry_pos := _city_entry_pos(target, player_pos)
	_travel_to_point(entry_pos, target, districts[target].name, enter_after_arrival)

func _travel_to_point(target_pos: Vector2, target_district := -1, destination_name := "точка маршрута", enter_after_arrival := false, suppress_arrival_event := false) -> void:
	if not target_pos.is_finite():
		return
	var cost = _movement_cost(player_pos, target_pos)
	if suppress_arrival_event:
		cost = {}
	if hull <= 0:
		_log("Маршрут недоступен: корпус поврежден.")
		_refresh()
		return
	travel_from = current_district
	travel_to = target_district
	travel_target_district = target_district
	travel_start_pos = player_pos
	travel_final_pos = target_pos
	travel_waypoints = _build_travel_waypoints(player_pos, target_pos, target_district)
	travel_target_pos = _next_travel_target()
	if travel_target_pos.distance_to(travel_start_pos) > 1.0:
		vehicle_target_angle = (travel_target_pos - travel_start_pos).angle()
		if not is_traveling or vehicle_velocity.length() < 1.0:
			vehicle_current_speed = 0.0
			vehicle_velocity = Vector2.ZERO
	travel_destination_name = destination_name
	travel_cost = cost
	travel_progress = 0.0
	travel_duration = max(0.1, travel_start_pos.distance_to(travel_target_pos) / vehicle_speed)
	is_traveling = true
	at_location = false
	open_location_after_travel = enter_after_arrival
	travel_suppress_arrival_event = suppress_arrival_event
	selected_district = target_district if target_district != -1 else selected_district
	modal_panel.visible = false
	_log("Машина сменила курс: %s." % destination_name)
	_refresh()

func _reach_travel_point() -> void:
	if travel_waypoints.size() > 0:
		travel_target_pos = _next_travel_target()
		travel_progress = _route_progress()
		return
	travel_progress = 1.0
	_finish_travel()

func _next_travel_target() -> Vector2:
	if travel_waypoints.size() > 0:
		var next_point: Vector2 = travel_waypoints.pop_front()
		return next_point
	return travel_final_pos

func _route_progress() -> float:
	var total_distance: float = max(1.0, travel_start_pos.distance_to(travel_final_pos))
	return clamp(1.0 - player_pos.distance_to(travel_final_pos) / total_distance, 0.0, 1.0)

func _city_entry_pos(index: int, from_pos: Vector2) -> Vector2:
	var center: Vector2 = districts[index].pos
	var direction: Vector2 = (from_pos - center).normalized()
	if direction.length() < 0.01:
		direction = CITY_ENTRY_DIRECTIONS[rng.randi_range(0, CITY_ENTRY_DIRECTIONS.size() - 1)] as Vector2
	return center + _nearest_city_entry_direction(direction) * CITY_ENTRY_RADIUS

func _random_city_exit_pos(index: int) -> Vector2:
	var direction: Vector2 = _random_city_exit_direction()
	var center: Vector2 = districts[index].pos
	return center + direction * CITY_ENTRY_RADIUS

func _random_city_exit_direction() -> Vector2:
	return CITY_ENTRY_DIRECTIONS[rng.randi_range(0, CITY_ENTRY_DIRECTIONS.size() - 1)] as Vector2

func _nearest_city_entry_direction(direction: Vector2) -> Vector2:
	var best_direction: Vector2 = CITY_ENTRY_DIRECTIONS[0] as Vector2
	var best_dot: float = -999.0
	for candidate in CITY_ENTRY_DIRECTIONS:
		var candidate_direction: Vector2 = candidate as Vector2
		var dot: float = direction.dot(candidate_direction)
		if dot > best_dot:
			best_dot = dot
			best_direction = candidate_direction
	return best_direction

func _build_travel_waypoints(from_pos: Vector2, target_pos: Vector2, target_district: int) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var approach_pos: Vector2 = target_pos
	if target_district != -1:
		var target_center: Vector2 = districts[target_district].pos
		if from_pos.distance_to(target_center) <= CITY_NEAR_ENTRY_RADIUS:
			points.append(target_pos)
			return points
		var entry_direction: Vector2 = (target_pos - target_center).normalized()
		if entry_direction.length() < 0.01:
			entry_direction = _nearest_city_entry_direction(from_pos - target_center)
		approach_pos = target_center + entry_direction * CITY_AVOID_RADIUS
	var obstacle_index: int = _first_city_on_segment(from_pos, approach_pos, target_district)
	if obstacle_index != -1:
		var center: Vector2 = districts[obstacle_index].pos
		var segment: Vector2 = approach_pos - from_pos
		var side: Vector2 = segment.normalized().orthogonal()
		if (from_pos - center).dot(side) < 0.0:
			side = -side
		points.append(center + side * CITY_AVOID_RADIUS)
	if target_district != -1 and from_pos.distance_to(approach_pos) > 24.0:
		points.append(approach_pos)
	points.append(target_pos)
	return points

func _first_city_on_segment(from_pos: Vector2, target_pos: Vector2, target_district: int) -> int:
	var best_index := -1
	var best_along := 999999.0
	var segment: Vector2 = target_pos - from_pos
	var segment_len_sq: float = segment.length_squared()
	if segment_len_sq < 1.0:
		return -1
	for i in range(districts.size()):
		if i == target_district:
			continue
		var center: Vector2 = districts[i].pos
		var along: float = clamp((center - from_pos).dot(segment) / segment_len_sq, 0.0, 1.0)
		var closest: Vector2 = from_pos + segment * along
		var distance: float = closest.distance_to(center)
		if distance < CITY_AVOID_RADIUS and along > 0.05 and along < 0.95 and along < best_along:
			best_along = along
			best_index = i
	return best_index

func _finish_travel() -> void:
	is_traveling = false
	water_tank = max(0, water_tank - travel_cost.get("water", 0))
	battery = max(0, battery - travel_cost.get("power", 0))
	if travel_target_district != -1:
		current_district = travel_target_district
		selected_district = travel_target_district
		at_location = true
		hull = 100
		_road_event(current_district)
		_advance_day("Машина прибыла в %s." % districts[current_district].name, false)
		_check_mission_delivery()
	elif travel_suppress_arrival_event:
		at_location = false
		_log("Машина выехала из города.")
	else:
		at_location = false
		_field_event()
		_log("Машина остановилась в точке %.0f / %.0f." % [player_pos.x, player_pos.y])
	travel_from = -1
	travel_to = -1
	travel_target_district = -1
	travel_waypoints.clear()
	travel_progress = 0.0
	travel_cost = {}
	travel_destination_name = ""
	travel_suppress_arrival_event = false
	vehicle_velocity = Vector2.ZERO
	vehicle_current_speed = 0.0
	vehicle_previous_speed = 0.0
	vehicle_is_braking = false
	vehicle_steer = 0.0
	_refresh()
	if open_location_after_travel:
		open_location_after_travel = false
		_enter_location(current_district)

func _cancel_bad_travel_state() -> void:
	is_traveling = false
	travel_from = -1
	travel_to = -1
	travel_target_district = -1
	travel_waypoints.clear()
	travel_progress = 0.0
	travel_cost = {}
	travel_destination_name = ""
	travel_suppress_arrival_event = false
	vehicle_velocity = Vector2.ZERO
	vehicle_current_speed = 0.0
	vehicle_previous_speed = 0.0
	vehicle_is_braking = false
	vehicle_steer = 0.0
	_log("Маршрут сброшен: навигация потеряла цель.")
	_refresh()

func _road_event(target: int) -> void:
	var danger = _route_danger(target)
	if rng.randi_range(1, 100) <= danger:
		var roll = rng.randi_range(1, 4)
		match roll:
			1:
				var loss = min(cargo["water"], rng.randi_range(1, 3))
				cargo["water"] -= loss
				hull -= rng.randi_range(5, 13)
				_log("Налет водных пиратов: потеряно %d воды, корпус поврежден." % loss)
			2:
				hull -= rng.randi_range(8, 18)
				_log("Песчаная буря сбила лидарную связку. Корпус: %d%%." % hull)
			3:
				eco_unrest = clampi(eco_unrest + 5, 0, 100)
				_log("На трассе блокпост экоополчения. Напряжение растет.")
			4:
				credits = max(0, credits - rng.randi_range(18, 45))
				_log("Неофициальный сбор за безопасность съел часть выручки.")
	else:
		if rng.randi_range(1, 100) <= 18:
			var found = rng.randi_range(1, 3)
			water_tank += found
			_log("По пути найден старый аварийный бак: +%d воды." % found)

func _field_event() -> void:
	if rng.randi_range(1, 100) <= 16:
		var wear = rng.randi_range(2, 7)
		hull = max(0, hull - wear)
		_log("Грунт оказался жестким: подвеска получила износ %d%%." % wear)

func _advance_day(message: String, refresh_now := true) -> void:
	day += 1
	ai_complex = clampi(ai_complex + rng.randi_range(1, 3), 0, 100)
	eco_unrest = clampi(eco_unrest + rng.randi_range(-1, 3) + (1 if ai_complex > 55 else 0), 0, 100)
	water_tank = min(12, water_tank + 1)
	battery = min(12, battery + 1)
	for i in range(districts.size()):
		var d = districts[i]
		d.water = clampi(d.water + rng.randi_range(-5, 4) - (2 if d.faction == "data" else 0), 5, 95)
		d.food = clampi(d.food + rng.randi_range(-3, 4), 5, 95)
		d.power = clampi(d.power + rng.randi_range(-4, 5) + (2 if d.faction == "data" else 0), 5, 95)
		d.security = clampi(d.security + rng.randi_range(-3, 3) - (2 if eco_unrest > 65 else 0), 8, 92)
		d.compute = clampi(d.compute + rng.randi_range(-2, 4) + (2 if d.faction == "data" else 0), 5, 95)
	if missions.size() < 5:
		_generate_missions(2)
	_update_deadlines()
	_log(message)
	if refresh_now:
		_refresh()

func _update_deadlines() -> void:
	var failed := []
	for m in accepted_missions:
		m.deadline -= 1
		if m.deadline < 0:
			failed.append(m)
	for m in failed:
		accepted_missions.erase(m)
		credits = max(0, credits - int(m.reward * 0.35))
		eco_unrest = clampi(eco_unrest + 4, 0, 100)
		_log("Срыв контракта ударил по репутации: %s ждала груз." % districts[m.to].name)

func _repair() -> void:
	if credits >= 40 and hull < 100:
		credits -= 40
		hull = min(100, hull + 22)
		_log("Механики подтянули подвеску и бронекапот. Корпус %d%%." % hull)
		_refresh()

func _generate_missions(count := 5) -> void:
	var goods = GOODS.keys()
	for n in range(count):
		var start = rng.randi_range(0, districts.size() - 1)
		var finish = rng.randi_range(0, districts.size() - 1)
		while finish == start:
			finish = rng.randi_range(0, districts.size() - 1)
		var good = goods[rng.randi_range(0, goods.size() - 1)]
		var amount = rng.randi_range(1, 4)
		var distance = districts[start].pos.distance_to(districts[finish].pos) / 100.0
		var reward = int((GOODS[good].base * amount) + distance * 28 + rng.randi_range(20, 80))
		missions.append({"from": start, "to": finish, "good": good, "amount": amount, "reward": reward, "deadline": rng.randi_range(3, 7)})

func _distance_cost(from: int, to: int) -> Dictionary:
	return _movement_cost(districts[from].pos, districts[to].pos)

func _movement_cost(from_pos: Vector2, to_pos: Vector2) -> Dictionary:
	var dist = from_pos.distance_to(to_pos)
	return {"water": max(1, int(round(dist / 360.0))), "power": max(1, int(round(dist / 430.0)))}

func _route_danger(target: int) -> int:
	var d = districts[target]
	var danger = 12 + int((100 - d.security) * 0.45) + int(eco_unrest * 0.12)
	if d.faction == "pirates":
		danger += 18
	return clampi(danger, 5, 78)

func _apply_supply_effect(index: int, good: String, amount: int) -> void:
	var d = districts[index]
	match good:
		"water":
			d.water = clampi(d.water + amount, 5, 95)
		"food":
			d.food = clampi(d.food + amount, 5, 95)
		"power":
			d.power = clampi(d.power + amount, 5, 95)
		"compute":
			d.compute = clampi(d.compute + amount, 5, 95)
		"meds":
			d.security = clampi(d.security + int(amount * 0.6), 8, 92)
		"people":
			d.security = clampi(d.security + int(amount * 0.4), 8, 92)

func _cargo_used() -> int:
	var used := 0
	for good in GOODS:
		used += cargo[good] * GOODS[good].mass
	return used

func _log(text: String) -> void:
	if event_log == null:
		return
	event_log.text = "[color=#9ad1d4]День %d[/color] %s\n%s" % [day, text, event_log.text]

func _map_location_clicked(index: int) -> void:
	selected_district = index
	if not is_traveling and at_location and index == current_district:
		_enter_location(index)
	else:
		_travel(index, true)

func _enter_location(index: int) -> void:
	selected_district = index
	current_district = index
	at_location = true
	_open_modal(0)
	_refresh()

func _map_point_clicked(world_pos: Vector2) -> void:
	if player_pos.distance_to(world_pos) < MIN_FIELD_CLICK_DISTANCE:
		return
	_travel_to_point(world_pos, -1, "поле %.0f / %.0f" % [world_pos.x, world_pos.y], false)
