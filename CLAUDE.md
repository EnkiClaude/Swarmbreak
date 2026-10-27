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
- **Touch is a third path for phone testing.** `TouchControls` turns touches
  into the same input actions, so gameplay never reads touch directly. Mouse
  emulation from touch is off (it would turn every tap into a left click).
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
  abilities/        Nova, bolt and lure tuning.
  zones/            Camp generation per zone level, camp bosses.
  rpg/              XP curve, skill tree, jobs, loot tables, affixes, refining.
  effects/          One EffectType per pooled visual effect.
scenes/main.tscn    Arena scene.
scripts/
  config/           Resource classes that define the shape of data/ files.
  core/main.gd      Wiring and per-frame tick order.
  arena/            Floor and border.
  camera/           Angled orthographic follow camera.
  player/           Player, health/mana (PlayerVitals), dodge, twin-stick input.
  zone/             ZoneDirector: camps, waking, lure, zone clear.
  boss/             BossSystem: camp bosses, telegraphed ground slam.
  hud/              Health/mana/XP bars, minimap, pickup messages, hurt flash.
  rpg/              Stats, XP, levels, jobs, items, rolls, inventory, Refinery.
  loot/             Ground loot: drops, magnet, pickup.
  ui/               Character screen: CHARACTER tab (path, skills, totals) and
                    INVENTORY tab (equipped, backpack grid, compare, refine).
  save/             Save file: codec (Dictionary <-> progress), store, autosave.
  swarm/            Swarm state, flow field, spatial hash, steering, rendering.
  combat/           Damage queries, abilities, cooldowns, pooled bolts.
  effects/          Pooled visual effects.
  render/           InstanceBatch: MultiMesh helper for pooled things.
  feedback/         Hit feel: hit-stop, break popup, flying corpses.
  audio/            Pooled sound voices and generated placeholder sounds.
  touch/            On-screen twin sticks and buttons for touchscreens.
  debug/            Debug overlay.
shaders/            Shaders.
tests/              Headless unit tests, scenarios and benchmark.
tools/check.sh      Runs every headless check (what CI runs).
tools/fetch_web_templates.py  Installs only the web export templates (CI).
```

## Zones and camps

A zone is a 128 m arena of enemy camps generated by `ZoneDirector` from
`data/zones/zone.tres` (seeded, so a level always looks the same). Camp
members spawn asleep (`SwarmState.awake == 0`) and cost almost nothing until
they wake: when the player comes within aggro range, when any member is hit
(`SwarmState.camp_alarm`), or when the lure reaches them. Clearing every camp
moves to the next level (more, bigger camps); dying restarts the current one.

## Progression and loot

Kills give XP (`EnemyType.xp`); each level adds health and mana and a skill
point. Points go into passive skills (`data/rpg/skills.tres`) on the
character screen, which pauses the game. Clearing a camp drops items where
its last member died: a slot (weapon, charm, armor), a rarity, and that many
affixes rolled from `data/rpg/loot.tres`, growing with the zone level.
`PlayerStats` totals level, skills and equipment; gameplay reads stats only
through it (`value()`, `multiplier()`), and must call `recompute()` after
changing any of them. Every stat is a `PlayerStat.Id` with a cap.

Jobs (`data/rpg/jobs.tres`): at `unlock_level` the player picks a path on
the character screen (permanent); at `rank2_level` it promotes. A rank's
`JobPerks` change abilities (Stormcaller nova aftershocks, Warlord lure marks
and armor, Arcanist piercing bolts) and add stats. Read perks only through
`PlayerStats.perks`.

Refining (`Refinery`): stones (from camps, bosses and salvaging) buy an
attempt to raise an item one level, +0 to +10, each level adding
`upgrade_bonus_per_level` to all its stats. Odds fall per level; a failure
drops it one level, never below +0 and never destroying it, and adds pity
to the next try. Keep it that way: no item loss.

Item data is a small object created per drop. That's allowed because drops
happen per camp, not per frame; ground loot itself is a fixed pool.

## Saving

`SaveManager` autosaves the character (level, XP, skills, job, items,
stones) and the zone reached to `user://` (the browser's storage on web).
Anything worth keeping calls `mark_dirty()`, and the write happens
`autosave_delay` later. The menu, tab switches and closing save immediately.
`SaveCodec` must stay tolerant: when adding saved fields, read them with a
default so older saves still load, and bump `VERSION` only for breaking
changes. Scenarios point `data/save.tres` at a scratch file.

## Camp bosses

Big camps can get a boss (`data/zones/boss.tres`, type `type_index` in the
swarm's enemy types) at their center. A boss is an ordinary swarm enemy in a
boss slot: `SwarmState.boss_index[slot]` tracks its current index through
compaction, so never cache a boss's enemy index across frames. `BossSystem`
runs the slam: stun, telegraph ring for `slam_windup`, then damage inside
`slam_radius`. Killing one drops rare loot and stones.

## Frame order

`main.gd` ticks everything in this order:

1. `Player.tick()`: movement, aim and dodge.
2. `SwarmManager.simulate()`:
   - `FlowField.update()` rebuilds the direction-to-player per 2 m cell, only
     when the player enters a new cell. Open ground points straight at the
     player; blocked cells switch to a chamfer distance transform.
   - `SpatialHash.build()` counting-sorts enemies into a fixed table of
     hashed buckets (1.2 m cells), so cost doesn't grow with map size. Queries
     must stamp buckets with `next_visit()` so two cells sharing a bucket
     aren't read twice. No allocation.
   - `SwarmSteering.step()`: flow-field seek (straight chase near the player),
     separation from up to `max_separation_neighbours` neighbours (sleeping
     enemies skip all of this), then integration, player push-out, arena
     clamp, and contact damage from up to `max_attackers` touching enemies.
3. Damage: `PlayerCombat.tick()` (nova) and `ProjectileSystem.tick()` (bolts)
   call `SwarmManager.damage_circle()` / `first_hit()`. Killed enemies stay in
   place at health <= 0.
4. `SwarmManager.resolve_deaths()` compacts dead enemies out and spawns their
   death effects; `ZoneDirector.record_deaths()` and `tick()` count camp
   deaths and wake camps; `BossSystem.tick()` runs slams; the player takes
   contact damage.
5. `SwarmManager.draw()`, `EffectSystem.tick()`, `CorpseSystem.tick()`,
   `BreakPopup.tick()`, `CameraRig.tick()` (follow and shake).

`CombatFeedback` listens to `SwarmManager.enemies_killed`, `PlayerCombat`'s
cast signals and `ProjectileSystem.bolt_burst`, and answers with hit-stop,
shake, the break popup, sound and vibration scaled by kills per blow. While
`consume_hitstop()` is true, `main.gd` skips the simulation and only ticks the
popup and camera.

Damage must happen between `simulate()` and `resolve_deaths()`: only then do
enemy indices match the spatial hash. Indices are not stable across frames, so
anything that tracks a specific enemy must handle that.

If profiling on Deck shows the GDScript hot loop is the bottleneck, port
`SwarmSteering.step` and `SpatialHash.build` to a GDExtension. Keep their
packed-array interfaces so nothing else has to change.

## Game feel

Every attack must read as powerful: a blow that kills more must freeze, shake,
sound and pop up harder. When adding an attack, emit a signal and let
`CombatFeedback` react; don't scatter shake or sound calls through gameplay.
Feel tuning lives in `data/feedback.tres`, `data/audio.tres` and the camera's
shake values. Sounds are placeholders generated by `SfxBank`.

The game is a Diablo-style action RPG, not a survivors game: attacks are
triggered by the player (no auto-fire), enemies live in placed camps, the
player has health, mana and a dodge, and the lure gathers packs for the
nova. Kills give XP and levels, jobs change how abilities work, camps and
their bosses drop loot, and refining is a risky upgrade that never destroys.

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
| Fire bolts      | RT (hold)           | Left mouse (hold) |
| Nova            | RB                  | Q / right mouse   |
| Lure            | LB                  | E                 |
| Dodge           | A                   | Space / Shift     |
| Character       | Start               | Tab / C           |
| Inventory       | Y                   | I                 |
| Switch menu tab | LB / RB             | Q / E             |
| Spawn 100       | View / Back         | `=` or keypad `+` |
| Toggle overlay  | L3 (left stick)     | F3                |

On touchscreens: the left half of the screen is a floating move stick; FIRE
(bottom right) is held to fire and dragged to aim; NOVA, LURE and DODGE sit
around it; HUD, CHAR, +100 and BAG at the top.

## Git

- Commit `.import` and `.uid` files. Do not commit `.godot/`.
