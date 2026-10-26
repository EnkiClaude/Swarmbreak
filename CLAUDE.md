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
  members into locals first, avoid function calls and Variant-typed values inside
  the loop, and never index a packed array that is stored inside an `Array`
  (each write would copy it). See `swarm_steering.gd` for the pattern.
- Writing to a local copy of a packed array that is still referenced elsewhere
  triggers copy-on-write. Assign the result back, or drop the other reference first.
- Systems are ticked explicitly in a fixed order from `scripts/core/main.gd`
  rather than each node relying on its own `_process`.

## Layout

```
data/               Tuning resources (.tres). Edit these to tune the game.
  enemies/          One EnemyType per enemy kind.
scenes/main.tscn    M0 arena scene.
scripts/
  config/           Resource classes that define the shape of data/ files.
  core/main.gd      Wiring and per-frame tick order.
  arena/            Floor and border.
  camera/           Angled orthographic follow camera.
  player/           Player and twin-stick input.
  swarm/            Swarm state, flow field, spatial hash, steering, rendering.
  debug/            Debug overlay.
shaders/            Shaders.
```

## Swarm architecture

`SwarmManager.tick()` runs once per frame:

1. `FlowField.update()`: rebuilds direction-to-player per 2 m cell, only when the
   player enters a new cell. Costs come from a chamfer distance transform, so
   blocked cells are supported once the arena has obstacles.
2. `SpatialHash.build()`: counting sort of enemies into 1 m cells. No allocation.
3. `SwarmSteering.step()`: flow-field seek (straight chase near the player),
   separation from neighbours in the 3x3 hash cells, then integration, player
   push-out and arena clamp.
4. `SwarmRenderer.draw()`: packs positions per type into each MultiMesh buffer.

Despawning swaps the last live enemy into the freed slot, so enemy indices are
not stable across frames. Anything that needs to track a specific enemy must
handle that.

If profiling on Deck shows the GDScript hot loop is the bottleneck, port
`SwarmSteering.step` and `SpatialHash.build` to a GDExtension. Keep their
packed-array interfaces so nothing else has to change.

## Controls (M0)

| Action          | Controller          | Keyboard / mouse |
|-----------------|---------------------|------------------|
| Move            | Left stick          | WASD / arrows    |
| Aim             | Right stick         | Mouse            |
| Spawn 100       | View / Back         | `=` or keypad `+`|
| Toggle overlay  | L3 (left stick)     | F3               |

## Git

- Commit `.import` and `.uid` files. Do not commit `.godot/`.
