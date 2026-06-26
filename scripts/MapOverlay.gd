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
	_draw_hover_card()
	_draw_legend()
	if not map.fullscreen_view:
		_draw_minimap()

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
