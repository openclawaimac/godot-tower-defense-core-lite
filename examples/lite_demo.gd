extends Node2D
## Lite demo: a complete, playable 3-wave level on the TD core.
## 1/2 pick tower, left click build, right click sell, Space next wave, R restart.
## Art: Kenney Tower Defense (CC0), see assets/sources.

var content: TDContent
var spawner: TDWaveSpawner
var build_id: StringName = &"gun"
var info: Label
var status: String = ""
var _tex: Dictionary = {}

func tex(n: String) -> Texture2D:
	if not _tex.has(n):
		_tex[n] = load("res://assets/sprites/%s.png" % n)
	return _tex[n]

func _ready() -> void:
	info = Label.new()
	info.position = Vector2(16, 528)
	info.add_theme_font_size_override("font_size", 18)
	add_child(info)
	restart()

func restart() -> void:
	if spawner != null:
		spawner.queue_free()
	content = TDContent.load_file("res://examples/data/content.json")
	spawner = TDWaveSpawner.new()
	spawner.configure(content)
	add_child(spawner)
	spawner.all_waves_cleared.connect(func() -> void: status = "VICTORY! Press R to play again")
	spawner.economy.defeated.connect(func() -> void: status = "DEFEAT - press R to retry")
	status = "Space: start wave 1"

## Builds the selected tower at a map cell. Returns true on success.
func build_at(c: Vector2i) -> bool:
	var err: String = spawner.placement_error(c, content.tower_cost(build_id))
	if err != "":
		status = err.capitalize()
		return false
	return spawner.place_tower_at_cell(content.make_tower(build_id), c)

## Sells the tower at a cell. Returns the refund (0 if none).
func sell_at(c: Vector2i) -> int:
	var t: TDTower = spawner.tower_at_cell(c)
	return spawner.sell_tower(t) if t != null else 0

func _unhandled_input(event: InputEvent) -> void:
	var k: InputEventKey = event as InputEventKey
	if k != null and k.pressed and not k.echo:
		match k.keycode:
			KEY_1: build_id = &"gun"
			KEY_2: build_id = &"cannon"
			KEY_SPACE:
				if spawner.start_next_wave(): status = "Wave %d" % (spawner.wave_index + 1)
			KEY_R: restart()
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.pressed:
		var c: Vector2i = spawner.map.cell_at(get_global_mouse_position())
		if mb.button_index == MOUSE_BUTTON_LEFT: build_at(c)
		elif mb.button_index == MOUSE_BUTTON_RIGHT: sell_at(c)

func _process(_d: float) -> void:
	var e: TDEconomy = spawner.economy
	info.text = "Gold %d   Lives %d   Wave %d/%d   Build: %s (%d)  [1] Gatling [2] Cannon   %s" % [
		e.gold, e.lives, spawner.wave_index + 1, spawner.waves.size(), content.tower_def(build_id).get("name", build_id),
		content.tower_cost(build_id), status]
	queue_redraw()

func _draw() -> void:
	var m: TDMap = spawner.map
	var cs: float = m.cell_px
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.12, 0.16, 0.12))
	for y: int in m.rows:
		for x: int in m.cols:
			var c: Vector2i = Vector2i(x, y)
			draw_texture_rect(tex("grass_tex" if (x + y) % 3 else "grass"), Rect2(Vector2(c) * cs, Vector2(cs, cs)), false, Color(0.6, 0.68, 0.5))
	for c: Vector2i in m.path_cells():
		if m.in_bounds(c):
			draw_texture_rect(tex("dirt"), Rect2(Vector2(c) * cs, Vector2(cs, cs)), false)
	var i: int = 0
	for c: Vector2i in m.blocked:
		draw_texture_rect(tex("bush_big" if i % 2 == 0 else "rock_a"), Rect2(Vector2(c) * cs, Vector2(cs, cs)), false)
		i += 1
	for t: TDTower in spawner.towers:
		var r: Rect2 = Rect2(t.position - Vector2(32, 32), Vector2(64, 64))
		draw_texture_rect(tex("base_1"), r, false)
		draw_set_transform(t.position, t.aim_angle + PI / 2.0)
		draw_texture_rect(tex("tur_gun" if t.id == &"gun" else "tur_heavy_red"), Rect2(-32, -32, 64, 64), false)
		draw_set_transform(Vector2.ZERO)
	for en: TDEnemy in spawner.enemies:
		draw_set_transform(en.position, en.heading)
		draw_texture_rect(tex("soldier_green" if en.id == &"soldier" else "soldier_brown"), Rect2(-24, -24, 48, 48), false)
		draw_set_transform(Vector2.ZERO)
		draw_rect(Rect2(en.position + Vector2(-16, -28), Vector2(32.0 * clampf(en.hp / en.max_hp, 0.0, 1.0), 4)), Color(0.4, 1, 0.4))
