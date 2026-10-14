extends SceneTree
## Lite strict headless suite: tools/run_tests.sh. Exit 0 = PASS (RESULT: PASS).
## Subset of the Pro suite for the core, plus Lite-only checks.

const Harness = preload("res://tests/harness.gd")
var H: Harness
const PATH: PackedVector2Array = [Vector2(0, 0), Vector2(100, 0), Vector2(100, 100)]

func check(cond: bool, msg: String) -> void:
	H.check(cond, msg)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	H = Harness.new()
	if Harness.selftest_mode() == "crash":
		await H.section("harness_crash_selftest", H.crash_selftest)
		quit(H.finish())
		return
	if Harness.selftest_mode() == "exit":
		quit(0)
		return
	await H.section("test_economy", test_economy)
	await H.section("test_enemy", test_enemy)
	await H.section("test_targeting", test_targeting)
	await H.section("test_slow_splash_armor", test_slow_splash_armor)
	await H.section("test_tower_levels", test_tower_levels)
	await H.section("test_map", test_map)
	await H.section("test_wave_sim", test_wave_sim)
	await H.section("test_lite_content", test_lite_content)
	await H.section("test_lite_scope", test_lite_scope)
	await H.section("test_lite_demo", test_lite_demo)
	quit(H.finish())

func _enemy(hp: float, speed: float) -> TDEnemy:
	var e: TDEnemy = TDEnemy.new()
	e.setup(PATH, hp, speed, 5)
	root.add_child(e)
	return e

func test_economy() -> void:
	print("economy")
	var ec: TDEconomy = TDEconomy.new(100, 2)
	check(ec.spend(60) and not ec.spend(60) and ec.gold == 40, "spend respects gold")
	check(not ec.spend(-1) and ec.gold == 40, "negative spend refused")
	var lost: Array[bool] = [false]
	ec.defeated.connect(func() -> void: lost[0] = true)
	ec.leak(1); ec.leak(1); ec.leak(5)
	check(lost[0] and ec.lives == 0 and ec.is_defeated(), "defeat at 0 lives, further leaks ignored")
	ec.earn(25)
	check(ec.gold == 65, "earn adds gold")

func test_enemy() -> void:
	print("enemy")
	var e: TDEnemy = _enemy(10, 50)
	e.advance(3.0)
	check(e.position.is_equal_approx(Vector2(100, 50)) and is_equal_approx(e.progress, 150.0), "follows path around corner")
	check(is_equal_approx(e.heading, PI / 2.0), "heading follows movement direction")
	check(is_equal_approx(e.remaining_distance(), 50.0), "remaining distance to exit")
	var leaked: Array[int] = [0]
	e.leaked.connect(func(_x: TDEnemy) -> void: leaked[0] += 1)
	e.advance(5.0); e.advance(5.0)
	check(leaked[0] == 1, "leaks exactly once")
	var e2: TDEnemy = _enemy(8, 10)
	var dealt: float = e2.take_damage(3.0)
	check(is_equal_approx(dealt, 3.0) and is_equal_approx(e2.hp, 5.0), "take_damage returns damage dealt")
	e2.armor = 100.0
	check(is_equal_approx(e2.take_damage(50.0), 1.0), "armor floors damage at 1")
	e2.armor = 0.0
	e2.take_damage(100.0)
	check(e2.done and e2.hp <= 0.0, "kills when hp reaches 0")
	e.free(); e2.free()

func test_targeting() -> void:
	print("targeting")
	var a: TDEnemy = _enemy(5, 10); a.advance(5.0)
	var b: TDEnemy = _enemy(30, 10); b.advance(1.0)
	var t: TDTower = TDTower.new(); t.position = Vector2(30, 0); t.range_px = 200; root.add_child(t)
	var list: Array[TDEnemy] = [a, b]
	check(t.pick_target(list) == a, "FIRST picks furthest along")
	t.targeting = TDTower.Targeting.LAST
	check(t.pick_target(list) == b, "LAST picks least progressed")
	t.targeting = TDTower.Targeting.STRONGEST
	check(t.pick_target(list) == b, "STRONGEST picks max hp")
	t.range_px = 5
	check(t.pick_target(list) == null, "out of range -> none")
	t.range_px = 200; t.hits_ground = false
	check(t.pick_target(list) == null, "ground-only filter drops ground enemies")
	var air: TDEnemy = _enemy(10, 10); air.flying = true; list.append(air)
	t.hits_air = true; t.hits_ground = false
	check(t.pick_target(list) == air, "air-capable tower picks flyers")
	check(t.cycle_targeting() == TDTower.Targeting.CLOSEST, "cycle_targeting wraps")
	for n: Node in [a, b, air, t]: n.free()

func test_slow_splash_armor() -> void:
	print("slow / splash / armor")
	var a: TDEnemy = _enemy(20, 10); var b: TDEnemy = _enemy(20, 10); b.armor = 3.0
	var t: TDTower = TDTower.new(); t.splash_radius = 30; t.damage = 4; t.slow_factor = 0.5; t.slow_duration = 1.0; root.add_child(t)
	t.advance(0.1, [a, b] as Array[TDEnemy])
	check(is_equal_approx(a.hp, 16.0) and is_equal_approx(b.hp, 19.0), "splash hits both, armor reduces (min 1)")
	check(a.is_slowed(), "slow applied")
	a.advance(1.0)
	check(is_equal_approx(a.progress, 5.0), "slow halves movement")
	a.advance(1.0)
	check(is_equal_approx(a.progress, 15.0), "slow expires")
	for n: Node in [a, b, t]: n.free()

func test_tower_levels() -> void:
	print("tower levels")
	var t: TDTower = TDTower.new(); t.cost = 50; t.damage = 4; t.range_px = 100; t.fire_interval = 1.0
	t.levels = [{"cost": 40, "damage": 7, "range": 120, "interval": 0.8}, {"cost": 80, "damage": 12, "range": 140, "interval": 0.6}] as Array[Dictionary]
	var ec: TDEconomy = TDEconomy.new(200)
	check(t.max_level() == 3 and t.can_upgrade() and t.upgrade_cost() == 40, "data-driven upgrade cost")
	check(is_equal_approx(float(t.next_stats()["damage"]), 7.0), "next_stats previews the next level")
	check(t.upgrade(ec) and t.level == 2 and is_equal_approx(t.damage, 7.0) and ec.gold == 160, "upgrade applies data level")
	check(t.upgrade(ec) and not t.can_upgrade() and t.next_stats().is_empty(), "max level blocks further upgrades")
	check(t.sell_value() == int((50 + 40 + 80) * 0.7), "sell refunds 70%% of spent")
	check(is_equal_approx(t.dps(), 12.0 / 0.6), "dps = damage / interval")
	t.free()

func test_map() -> void:
	print("map")
	var m: TDMap = TDMap.from_dict({"cols": 8, "rows": 5, "cell": 64, "path": [[0, 2], [7, 2]], "blocked": [[3, 0], [4, 4]]})
	check(m.validate().is_empty(), "valid map has no errors")
	check(m.path_cells().size() == 8 and m.is_path(Vector2i(3, 2)), "path fills straight runs")
	check(m.can_build(Vector2i(3, 1)) and not m.can_build(Vector2i(3, 2)) and not m.can_build(Vector2i(3, 0)), "buildable = in bounds, not path, not blocked")
	check(m.cell_center(Vector2i(1, 1)) == Vector2(96, 96) and m.cell_at(Vector2(100, 130)) == Vector2i(1, 2), "cell <-> world")
	check(m.world_path().size() == 2 and m.air_path().size() == 2, "world and air paths")
	var bad: TDMap = TDMap.from_dict({"path": [[0, 0], [2, 2]], "blocked": [[1, 1]]})
	check(not bad.validate().is_empty(), "diagonal path + blocked-on-path are rejected")

func test_wave_sim() -> void:
	print("wave simulation")
	var c: TDContent = TDContent.new()
	c.load_dict({"start_gold": 100, "lives": 20, "hp_scale_per_wave": 1.0,
		"towers": [{"id": "gun", "cost": 50, "damage": 4, "range": 150, "interval": 0.25}],
		"enemies": [{"id": "soldier", "hp": 4, "speed": 40, "bounty": 3}],
		"waves": [{"groups": [{"enemy": "soldier", "count": 5, "interval": 0.5}], "bonus": 10}],
		"map": {"cols": 6, "rows": 4, "cell": 32, "path": [[0, 1], [5, 1]]}})
	var s: TDWaveSpawner = TDWaveSpawner.new(); s.auto_tick = false; s.configure(c); root.add_child(s)
	check(s.placement_error(Vector2i(2, 1), 50) == "on the path", "path cells refuse towers")
	check(s.placement_error(Vector2i(2, 0), 50) == "", "empty grass is free")
	var t: TDTower = c.make_tower(&"gun")
	check(s.place_tower_at_cell(t, Vector2i(2, 0)) and s.economy.gold == 50, "place at cell spends gold")
	check(s.tower_at_cell(Vector2i(2, 0)) == t, "tower_at_cell finds it")
	check(not s.place_tower_at_cell(c.make_tower(&"gun"), Vector2i(2, 0)), "occupied cell rejected")
	var preview: Dictionary = s.wave_preview(0)
	check(int(preview.get("soldier", 0)) == 5, "wave preview counts enemies")
	var cleared: Array[bool] = [false]
	s.all_waves_cleared.connect(func() -> void: cleared[0] = true)
	check(s.start_next_wave() and not s.start_next_wave(), "one wave at a time")
	for i: int in 400:
		s.advance(0.05)
	check(cleared[0] and s.won and s.economy.gold == 50 + 15 + 10, "clears wave, earns bounty + clear bonus (gold %d)" % s.economy.gold)
	var refund: int = s.sell_tower(t)
	check(refund == int(50 * 0.7) and s.towers.is_empty(), "sell refunds 70%% and removes the tower")
	s.free()

func test_lite_content() -> void:
	print("Lite content.json")
	var c: TDContent = TDContent.load_file("res://examples/data/content.json")
	check(c.validate().is_empty(), "Lite content validates %s" % [c.validate()])
	check(c.towers.size() == 2 and c.enemies.size() == 2 and c.waves.size() == 3, "2 towers, 2 enemies, 3 waves")
	var t: TDTower = c.make_tower(&"gun")
	check(t.cost == 60 and t.levels.size() == 2, "gatling from data, upgradable")
	t.free()

func test_lite_scope() -> void:
	print("Lite scope (no Pro game layer)")
	var bad: Array[String] = []
	for cls: Dictionary in ProjectSettings.get_global_class_list():
		if str(cls["class"]) in ["TDHud", "TDGame", "TDCameraRig", "TDSfx", "TDTheme", "TDMapView"]:
			bad.append(str(cls["class"]))
	check(bad.is_empty(), "no Pro game classes in Lite %s" % [bad])
	check(FileAccess.file_exists("res://assets/sources/kenney_tower-defense-top-down-License.txt"), "CC0 licence for the bundled sprites")

func test_lite_demo() -> void:
	print("Lite demo scene")
	var d: Node = (load("res://examples/lite_demo.tscn") as PackedScene).instantiate()
	root.add_child(d)
	for i: int in 3:
		await process_frame
	var s: TDWaveSpawner = d.get("spawner")
	check(s != null and s.economy.gold == 150 and s.economy.lives == 10, "demo starts with Lite content")
	check(d.call("build_at", Vector2i(2, 1)) and s.economy.gold == 90, "build gatling next to the path")
	check(not d.call("build_at", Vector2i(2, 2)), "path cell refused")
	d.set("build_id", &"cannon")
	check(d.call("build_at", Vector2i(5, 3)) and s.towers.size() == 2, "build cannon")
	s.auto_tick = false
	var won: Array[bool] = [false]
	s.all_waves_cleared.connect(func() -> void: won[0] = true)
	for w: int in 3:
		s.start_next_wave()
		for i: int in 2000:
			s.advance(0.05)
			if not s.is_wave_active():
				break
	check(won[0] or s.economy.lives < 10 or s.wave_index == 2, "three waves play to the end (won=%s lives=%d)" % [won[0], s.economy.lives])
	check(int(d.call("sell_at", Vector2i(2, 1))) > 0 and s.towers.size() == 1, "sell refunds")
	d.queue_free()
	await process_frame
