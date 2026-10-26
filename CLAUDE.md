# Swarmbreak

Godot 4 (4.3+) action RPG. The core mechanic: lure enemies into large packs,
then kill them with area-of-effect attacks. The fantasy is a huge, dense swarm
breaking all at once, so swarm scale and frame stability come before anything else.

**Target:** Steam Deck, 1280x800, locked 60 fps with 600+ enemies on screen.
Every system must fit that budget. Check the debug overlay (F3) after any change
to the swarm or rendering.

## Hard rules

- **Enemies are data, not nodes.** Enemies live as packed arrays in the swarm
  manager (`SwarmState`). Never create one Node per enemy, not even temporarily.
- **No physics bodies for enemies.** Neighbour queries and separation go through
  the spatial hash (`SpatialHash`). Do not use Area3D, CharacterBody3D, RigidBody3D
  or physics queries for enemies.
- **Render enemies with MultiMeshInstance3D, one per enemy type.** Upload the
  whole instance buffer once per frame (`MultiMesh.buffer`), not per-instance calls.
- **Pool everything spawned in combat.** Enemies, projectiles, VFX, damage numbers
  and pickups come from preallocated pools. No `new()`, `instantiate()` or
  `queue_free()` in the combat loop. Allocating at load or setup is fine.
- **Tuning values live in `data/`, not scripts.** Speeds, radii, counts, damage,
  timings and colors are exported on a `Resource` class in `scripts/config/` and
  set in a `.tres` file under `data/`. Scripts hold only structural constants
  (buffer strides, mesh detail, epsilons).
- **Controller-first twin-stick input.** Left stick moves (camera-relative), right
  stick aims. Mouse and keyboard are the second path: WASD moves, the mouse aims
  once it moves. Every action needs a controller binding first. Read input through
  actions in `project.godot`, never raw keycodes or joypad buttons.

## Style

- Typed GDScript everywhere: typed vars, params and returns. Use `:=` only when
  the type is obvious from the right-hand side.
- Small single-purpose scripts. One class per file with a `class_name` and a `##`
  doc comment that says what it owns.
- Hot loops (anything running per enemy per frame): pull packed arrays and
  members into locals first, and avoid function calls and Variant-typed values
  inside the loop; function calls are the biggest cost in GDScript. See
  `swarm_steering.gd` for the pattern.
- Between GDScript variables, packed arrays alias: `var a := state.positions`
  and writing `a[i]` changes `state.positions` (verified by
  `tests/unit/test_packed_array_semantics.gd`). Arrays read from engine
  properties, such as `MultiMesh.buffer`, are copies.
- Systems are ticked explicitly in a fixed order from `scripts/core/main.gd`
  rather than each node relying on its own `_process`.

## Layout

```
data/               Tuning resources (.tres). Edit these to tune the game.
  enemies/          One EnemyType per enemy kind.
  abilities/        Nova and bolt tuning.
  effects/          One EffectType per pooled visual effect.
scenes/main.tscn    Arena scene.
scripts/
  config/           Resource classes that define the shape of data/ files.
  core/main.gd      Wiring and per-frame tick order.
  arena/            Floor and border.
  camera/           Angled orthographic follow camera.
  player/           Player and twin-stick input.
  swarm/            Swarm state, flow field, spatial hash, steering, rendering.
  combat/           Damage queries, abilities, cooldowns, pooled bolts.
  effects/          Pooled visual effects.
  render/           InstanceBatch: MultiMesh helper for pooled things.
  debug/            Debug overlay.
shaders/            Shaders.
tests/              Headless unit tests, scenarios and benchmark.
tools/check.sh      Runs every headless check (what CI runs).
tools/fetch_web_templates.py  Installs only the web export templates (CI).
```

## Frame order

`main.gd` ticks everything in this order:

1. `Player.tick()`: movement and aim.
2. `SwarmManager.simulate()`:
   - `FlowField.update()` rebuilds the direction-to-player per 2 m cell, only
     when the player enters a new cell. Open ground points straight at the
     player; blocked cells switch to a chamfer distance transform.
   - `SpatialHash.build()` counting-sorts enemies into 1 m cells. No allocation.
   - `SwarmSteering.step()`: flow-field seek (straight chase near the player),
     separation from up to `max_separation_neighbours` neighbours, then
     integration, player push-out and arena clamp.
3. Damage: `PlayerCombat.tick()` (nova) and `ProjectileSystem.tick()` (bolts)
   call `SwarmManager.damage_circle()` / `first_hit()`. Killed enemies stay in
   place at health <= 0.
4. `SwarmManager.resolve_deaths()` compacts dead enemies out and spawns their
   death effects.
5. `SwarmManager.draw()`, `EffectSystem.tick()`, `CameraRig.tick()`.

Damage must happen between `simulate()` and `resolve_deaths()`: only then do
enemy indices match the spatial hash. Indices are not stable across frames, so
anything that tracks a specific enemy must handle that.

If profiling on Deck shows the GDScript hot loop is the bottleneck, port
`SwarmSteering.step` and `SpatialHash.build` to a GDExtension. Keep their
packed-array interfaces so nothing else has to change.

## Testing

Run `GODOT=/path/to/godot tools/check.sh`; CI runs the same script on every
push with Godot 4.3. It imports the project, then runs the unit tests
(`tests/unit/`), the scenarios (the real main scene driven by scripted input)
and the benchmark. Any `SCRIPT ERROR` or engine `ERROR:` in the logs fails the
run, except errors from the headless dummy renderer.

- New logic gets a unit test in `tests/unit/` (extend `TestSuite`, name methods
  `test_*`). New player-facing behaviour gets a scenario in `tests/run_scenarios.gd`.
- `.github/workflows/web.yml` exports the `Web` preset (`export_presets.cfg`)
  on every push and publishes `main` to GitHub Pages. The web build uses the
  Compatibility renderer and no threads, so keep features working there too,
  but never tune performance against it.
- The benchmark (`tests/benchmark.gd`) posts swarm tick times to the CI run
  summary. The runner's CPU is not a Steam Deck, but compare runs to catch
  regressions before they reach the Deck.

## Controls

| Action          | Controller          | Keyboard / mouse  |
|-----------------|---------------------|-------------------|
| Move            | Left stick          | WASD / arrows     |
| Aim             | Right stick         | Mouse             |
| Fire bolts      | RT, or hold aim     | Left mouse        |
| Nova            | RB                  | Space / right mouse |
| Spawn 100       | View / Back         | `=` or keypad `+` |
| Toggle overlay  | L3 (left stick)     | F3                |

## Git

- Commit `.import` and `.uid` files. Do not commit `.godot/`.
