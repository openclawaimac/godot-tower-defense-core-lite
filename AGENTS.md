# AGENTS.md: Godot Tower Defense Core Lite

## What this is
Godot Tower Defense Core Lite is a free, MIT-licensed **Godot 4 tower defense starter kit / template** written in typed GDScript for Godot 4.7 (tested on 4.7.2). It provides headless-testable game logic plus a small demo. The paid Pro edition (€6, commercial EULA) has the same API plus more features: https://huginhelm.itch.io/godot-tower-defense-core
Website: https://openclawaimac.github.io/godot-tower-defense-core/

## Structure
- `addons/td_core/td_content.gd` – TDContent: towers, enemies, waves, map from one JSON file, validate()
- `addons/td_core/td_map.gd` – TDMap: path/blocked/buildable cell grid
- `addons/td_core/td_enemy.gd` – TDEnemy: path following, hp, armor, slow, flying
- `addons/td_core/td_tower.gd` – TDTower: targeting modes, splash, slow, upgrades
- `addons/td_core/td_wave_spawner.gd` – TDWaveSpawner: waves, placement, sell, win/lose
- `addons/td_core/td_economy.gd` – TDEconomy: gold, lives
- `examples/` – lite_demo.tscn (playable 3-wave demo), data/content.json
- `tests/` – strict headless suite
- `tools/` – run_tests.sh, make_release.sh

## Run the tests
```bash
godot --headless --path . --import   # once, after clone or after adding a class_name
bash tools/run_tests.sh /path/to/godot   # or set GODOT=...; must print "RESULT: PASS 54 checks" and exit 0
```
The runner fails on non-zero exit, any `SCRIPT ERROR`, or a missing `RESULT: PASS` line.

## How to extend
- New towers/enemies/waves/maps: edit `examples/data/content.json`, then check `TDContent.validate()`.
- Drive the game headless with `auto_tick = false` + `advance(delta)`.
- Wire signals (`defeated`, win/lose, wave events) to your own UI and art.
- Add tests for new behaviour: a section in `tests/run_tests.gd` (`await H.section("test_x", test_x)`), then update `tests/expected.json`.

## Rules
- Godot 4.7.2, typed GDScript (untyped declarations are errors). Run `godot --headless --path . --import` after adding a class_name.
- Tests: `bash tools/run_tests.sh /path/to/godot` must print `RESULT: PASS`. Add a section in `tests/run_tests.gd` and update `tests/expected.json`.
- Content is data (`examples/data/content.json`), not new classes. Keep the API identical to the Pro edition.

## Lite vs Pro
Lite = free, MIT, 54 tests, core systems + minimal demo. Pro = €6, commercial per-seat EULA, 128 tests, full feature set and playable demo, same API. See README.md "Lite vs Pro" or https://openclawaimac.github.io/godot-tower-defense-core/. Get Pro: https://huginhelm.itch.io/godot-tower-defense-core
