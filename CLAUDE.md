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
  Each type's model is one mesh (`CharacterModels`); limbs walk in the vertex
  shader (`shaders/rig.gdshaderinc`, rig in UV), driven by per-instance custom
  data (walk amount, hit flash), so animation costs no extra CPU per enemy.
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
- **Controller-first third-person input.** Left stick moves (camera-relative),
  right stick turns the camera (the `aim_*` actions), and attacks go where the
  camera looks, with a little aim assist on bolts. Mouse and keyboard are the
  second path: WASD moves, clicking the game captures the mouse and moving it
  turns the camera. Every action needs a controller binding first. Read input
  through actions in `project.godot`, never raw keycodes or joypad buttons.

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
  world/            The open world: regions, dungeons, camp streaming.
  zones/            Camp bosses.
    themes/         One ZoneTheme per look: floor, walls, props, fog, light.
  rpg/              XP curve, skill tree, jobs, loot tables, affixes, refining.
  effects/          One EffectType per pooled visual effect.
scenes/main.tscn    Arena scene.
scripts/
  config/           Resource classes that define the shape of data/ files.
  core/main.gd      Wiring and per-frame tick order.
  arena/            Dungeon halls from a ZoneTheme (floor, walls, ceiling,
                    pillars, lanterns) and the shared prop builders.
  camera/           Third-person follow camera (turns with the right stick).
  player/           Player, health/mana (PlayerVitals), dodge, twin-stick input.
  world/            WorldMap (layout), WorldDirector (spaces, regions, gates),
                    CampDirector (streaming, waking, respawns, spawners),
                    open-world scenery, gates, atmosphere blending.
  boss/             BossSystem: camp bosses, telegraphed ground slam.
  hud/              Character panel, round minimap, skill column, pickup
                    messages, hurt flash.
  rpg/              Stats, XP, levels, jobs, items, rolls, inventory, Refinery.
  loot/             Ground loot: drops, magnet, pickup.
  ui/               Character screen: CHARACTER tab (path, skills, totals) and
                    INVENTORY tab (equipped, backpack grid, compare, refine).
  save/             Save file: codec (Dictionary <-> progress), store, autosave.
  swarm/            Swarm state, flow field, spatial hash, steering, rendering.
  combat/           Damage queries, abilities, cooldowns, pooled bolts.
  effects/          Pooled visual effects (rings, bursts, light pillars,
                    lightning) and pooled floating damage numbers.
  render/           InstanceBatch (MultiMesh helper for pooled things),
                    ModelBuilder and CharacterModels (the hero and monsters,
                    built from parts and rigged to walk).
  feedback/         Hit feel: hit-stop, break popup, flying corpses.
  audio/            Pooled sound voices and generated placeholder sounds.
  touch/            On-screen twin sticks and buttons for touchscreens.
  debug/            Debug overlay.
shaders/            Shaders.
tests/              Headless unit tests, scenarios and benchmark.
tools/check.sh      Runs every headless check (what CI runs).
tools/fetch_web_templates.py  Installs only the web export templates (CI).
```

## The world

The world (`data/world/world.tres`, `WorldConfig`) is an open map of square
regions (`RegionDef`: theme, level, camps) around a town, with dungeons
(`DungeonDef`) behind gates. Only one space is active at a time: the open
world, or one dungeon hall; each is centered on the origin and has its own
bounds, which `WorldDirector.enter()` hands to the swarm, player, camera and
bolts. Walking between regions is seamless: the region is announced and
`WorldAtmosphere` eases the sky, fog and light over, while the ground shader
blends floor colors across borders. Walking into a gate fades out, empties
the swarm and switches space. Dying sends the player back to town.

`WorldMap` generates every camp site once, seeded (`CampSites`, packed
arrays, which also keep each site's state while the player is elsewhere).
`CampDirector` streams them: sleeping sites within `spawn_radius` spawn into
the swarm asleep (`SwarmState.awake == 0`, costing almost nothing), sleeping
sites past `despawn_radius` leave silently (`SwarmManager.remove_camp`, no
XP or loot; a boss slot freed that way is flagged in
`SwarmState.boss_despawned`). Camps wake when the player comes within aggro
range, when any member is hit (`SwarmState.camp_alarm`), or when the lure
reaches them, and come back `camp_respawn_time` after clearing. Spawner sites
(dungeons only for now) never clear: near the player they add one awake
monster every `spawn_interval` (0 in dungeons: one per frame), for builds
that farm standing still. Dungeon camps, bosses included, also come back at
once (`DungeonDef.camp_respawn_time` 0), asleep, right where they were.
The swarm's camp id is the site index in the active space.

Dungeons (`DungeonLayout`) are a hallway running north from the entrance
with rooms on both sides behind doorways and a boss room at the far end.
Each side room holds `camps_per_room` camps (some rooms a spawner) and is
one step deeper than the room before it (left, then right, pair by pair):
`depth_level_step` levels harder, more Geon, and every `deep_rarity_depth`
rooms a better minimum rarity. The boss room at the end is one big room:
the boss, `boss_room_camps` camps around it and `boss_room_spawners`
spawners. Rooms are separate fights: every camp has a home room
(`DungeonLayout.homes_for()`, `SwarmSteering.set_homes()`) and its monsters
are stopped at that room's edge. There are ten dungeons (levels 10 to 80),
each a higher tier, each boss dropping pieces of its own set. Dungeon
monsters are a little faster the higher their level
(`SwarmState.speed_scale`, `WorldConfig.dungeon_speed_per_level`).
On entry `SwarmManager.set_layout()` rasterizes the plan onto the flow
field: monsters route through doors (`FlowField` room mode, as cheap as
open ground) and steering stops them at wall cells; the player
(`Player.wall_check`) and bolts are stopped too. `DungeonHall` builds walls
on exactly those cells. For testing, the town square also has a gate to
each dungeon; leaving returns the player to the gate they used.

Each region and dungeon names its monsters (`enemy_type`, `heavy_type`:
indices into `SwarmConfig.enemy_types`: goblin, ogre, warlord boss,
skeleton, treant, wisp).

Levels: monster health, contact damage and XP grow with the level where the
player is (`WorldDirector.level()`); items roll at the camp's level, and
dungeons add drops, a minimum rarity and more Geon. Props never collide,
so they stand clear of camps, gates and the town square. The art is original
and generated in code. In the web build, `index.html?region=N` (row by row
from the north-west) or `?dungeon=N` (from 1) starts there.

## Progression and loot

Kills give XP (`EnemyType.xp`); each level adds health and mana, a skill
point and `points_per_level` attribute points. Skill points go into passive
skills (`data/rpg/skills.tres`); attribute points go into five attributes
(`data/rpg/attributes.tres`: Strength, Health, Intelligence, Wisdom,
Agility), each feeding stats per point. Both are spent on the character
screen, which pauses the game. Saves from before attributes get their
level's points to spend.

The currency is Geon (`LootConfig.currency_name`; kept as `Inventory.stones`
in code and saves). Clearing a camp drops loot where its last member died
(`LootSystem.drop_rewards`): each drop is an item at `item_drop_chance`
(1 in 10), else a talisman at `talisman_drop_chance`, otherwise a pile of
Geon that grows with the camp's level and is picked up on touch. Bosses also drop a big pile; dungeons add drops and
bigger piles. An item is a base kind
(`ItemKindDef` in `data/rpg/loot.tres`: wand, blade, staff, greatblade,
tome, shield, robe, plate, pendant, belt, ring) that sets the slot, whether
it takes both hands, its icon and an implicit stat; then a rarity (common,
magic, rare, epic, legendary: `rarity_affixes` affixes from the slot's
pool, values times `rarity_power`), growing with the camp's level.
Set items (rarity 6, "Set", never rolled at random) come only from dungeon
bosses (`data/rpg/sets.tres`, `SetList`/`SetDef`, `DungeonDef.set_index`):
fixed pieces, and bonuses for wearing 2, 3 or 5 of a set, which
`Inventory.total()` adds. Talismans are a kind (`LootConfig.talismans`,
`TalismanDef`: Fury, Tempest, Bulwark, Shadow... one per build) at a tier
(a rarity, `talisman_tier_power`), with fixed values, so equal ones stack:
`Inventory.talismans` counts them by id (`TalismanRules.id_of()`), outside
the backpack. Applying one to worn gear (`TalismanRules.apply()`) fills
one of the gear's sockets (by rarity) at a falling chance and adds its
stats for good. A failure only destroys the talisman, never the gear.
`Inventory` wears items in twelve positions (`Inventory.Equip`: main hand,
amulet, armor, off hand, belt, two rings, helm, gloves, pants, boots, pet);
the first five equal their `AffixDef.Slot`, later slots are slot + 1.
Picking the same item twice quickly (double-click, double-tap, A twice)
wears it or takes it off. A two-handed weapon and an off-hand item exclude each
other, so equipping one moves the other to the backpack. Salvage All works
per rarity or on everything, never on worn items. Item icons are drawn in
code (`ItemIcon`); hovering or focusing an item shows `ItemTooltip`.
`PlayerStats` totals level, skills and equipment; gameplay reads stats only
through it (`value()`, `multiplier()`), and must call `recompute()` after
changing any of them. Every stat is a `PlayerStat.Id` with a cap.

Active skills (`data/rpg/actives.tres`, `ActiveSkillList`/`ActiveSkillDef`,
run by `ActiveSkills`): Chain Lightning, Inferno, Meteor and Blade Whirl on
the skill buttons (`skill_1`..`skill_4`: A, B, D-pad left/right; keys 1-4).
Each unlocks at a level and is learned and raised through grades with skill
points on the character screen (`PlayerProgress.active_grades`); grades add
damage, radius and counts (chain strikes, meteors) or duration. Burning
ground, whirls and meteors are zones in fixed arrays, damaging through
`damage_circle()` between `simulate()` and `resolve_deaths()`. `class_tag`
is reserved for a class system to come.

Jobs (`data/rpg/jobs.tres`): at `unlock_level` the player picks a path on
the character screen (permanent); at `rank2_level` it promotes. A rank's
`JobPerks` change abilities (Stormcaller nova aftershocks, Warlord lure marks
and armor, Arcanist piercing bolts) and add stats. Read perks only through
`PlayerStats.perks`.

Evasion (`PlayerStat.Id.EVASION`, mostly from Agility, capped at 85%) is
rolled in `PlayerVitals.take_damage()` for every hit (each frame of contact,
each boss slam); an evaded hit does nothing and pops up EVADE.

Pets (`data/rpg/pets.tres`, `PetConfig`/`PetDef`, logic in `PetRules`): an
egg is an `ItemData` in the PET slot with `pet_type`, `pet_level` and
`pet_xp`; its stats are rewritten for its level (base plus per level), so
`Inventory.total()` counts them like any item. It earns a bonus share of the
player's kill XP that grows per stage, hatches at level 10 and evolves
every 10 levels (bigger model, new name). `PetSystem` follows the player,
feeds the pet XP and, once hatched, sets `LootSystem.collect_radius` so
loot around the player is collected. Eggs come from the first quest
(`data/rpg/quests.tres`, `QuestLog`: clear camps, then pick an egg on the
PET tab) or, for testing, from the Egg Keeper in the town square, whose
menu opens when the player walks up.

Refining (`Refinery`): Geon (from drops and salvaging) buys an
attempt to raise an item one level, +0 to +10, each level adding
`upgrade_bonus_per_level` to all its stats. Odds fall per level; a failure
drops it one level, never below +0 and never destroying it, and adds pity
to the next try. Keep it that way: no item loss. A Blessed Stone
(`Inventory.blessed_stones`, a rare drop from any monster at
`blessed_drop_chance` per kill) instead makes an attempt certain to succeed.

Item data is a small object created per drop. That's allowed because drops
happen per camp, not per frame; ground loot itself is a fixed pool.

## Saving

`SaveManager` autosaves the character (level, XP, skills, job, items,
Geon) to `user://` (the browser's storage on web); the game always
resumes in town.
Anything worth keeping calls `mark_dirty()`, and the write happens
`autosave_delay` later. The menu, tab switches and closing save immediately.
`SaveCodec` must stay tolerant: when adding saved fields, read them with a
default so older saves still load, and bump `VERSION` only for breaking
changes. Scenarios point `data/save.tres` at a scratch file.

## Camp bosses

The biggest camps of a region (`RegionDef.boss_camps`) and each dungeon's far
end hold a boss (`data/zones/boss.tres`, type `type_index` in the swarm's
enemy types) at their center. A boss is an ordinary swarm enemy in a boss
slot: `SwarmState.boss_index[slot]` tracks its current index through
compaction, so never cache a boss's enemy index across frames. Slots are
reused once a boss dies or streams out. `BossSystem` runs the slam: stun,
telegraph ring for `slam_windup`, then damage inside `slam_radius`. Killing
one drops rare loot and a pile of Geon.

The summonable boss (`data/zones/summon.tres`, `SummonConfig`, run by
`SummonSystem`): any monster may drop a Sigil Shard
(`Inventory.summon_shards`); with `shards_needed` the INVENTORY tab's
SUMMON button calls the Dread Lord and an awake escort ahead of the player
(not in town, one at a time), at the higher of the place's and the
player's level, far tougher than a camp boss. Its kill pays out epic-or-
better drops, a big pile of Geon and a chance at a legendary.

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
3. Damage: `PlayerCombat.tick()` (nova), `ActiveSkills.tick()` and
   `ProjectileSystem.tick()` (bolts)
   call `SwarmManager.damage_circle()` / `first_hit()`. Killed enemies stay in
   place at health <= 0.
4. `SwarmManager.resolve_deaths()` compacts dead enemies out and spawns their
   death effects; `CampDirector.record_deaths()` and `tick()` count camp
   deaths, wake camps, refill spawners and stream sites in and out (the only
   other place enemy indices change, so it runs here); `BossSystem.tick()`
   runs slams; the player takes contact damage; `WorldDirector.tick()`
   tracks the region and gates.
5. `SwarmManager.draw()`, `EffectSystem.tick()`, `DamageNumbers.tick()`,
   `CorpseSystem.tick()`, `BreakPopup.tick()`, `CameraRig.tick()` (turn,
   follow, pull in near walls, shake).

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

## Look

The art direction is dark and grim, not toy-like. Every lit surface gets
procedural detail from `shaders/grime.gdshaderinc` (grain, blotches, grime
toward the ground): characters in `enemy.gdshader` and `hero.gdshader`,
props, walls and pillars in `prop.gdshader` (`ArenaProps.lit_material()`),
floors in `zone_floor.gdshader` and `world_floor.gdshader` (cracks, stains).
Parts painted with vertex alpha below 1 glow (monster eyes and gems, the
hero's weapon). Keep palettes dark and desaturated, fog thin and dark.

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
| Turn camera     | Right stick         | Mouse (click to capture, Esc frees) |
| Fire bolts      | X or RT (hold)      | Left mouse (hold) |
| Nova            | RB                  | Q / right mouse   |
| Lure            | LB                  | E                 |
| Dodge           | LT                  | Space / Shift     |
| Active skills 1-4 | A, B, D-pad left / right | 1, 2, 3, 4   |
| Character       | Start               | Tab / C           |
| Inventory       | Y                   | I                 |
| Switch menu tab | LB / RB             | Q / E             |
| Menu: select / press | A              | Enter / click     |
| Menu: back / close   | B              | Esc               |
| Menu: move focus     | D-pad / left stick | Arrows        |
| Spawn 100       | View / Back         | `=` or keypad `+` |
| Zoom camera     | D-pad up/down       | Mouse wheel       |
| Zoom steps      | R3 (right stick)    | Z                 |
| Toggle overlay  | L3 (left stick)     | F3                |

On touchscreens: the left half of the screen is a floating move stick; FIRE
(bottom right) is held to fire and dragged sideways to turn the camera; NOVA,
LURE and DODGE sit around it, with SK1-SK4 for the active skills; ZOOM,
HUD, CHAR, +100 and BAG at the top.

## Git

- Commit `.import` and `.uid` files. Do not commit `.godot/`.
