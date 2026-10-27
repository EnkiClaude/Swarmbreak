# Swarmbreak

A Godot 4 action RPG about luring enemies into enormous packs and breaking them
with area-of-effect attacks. Built for Steam Deck: 1280x800, locked 60 fps with
600+ enemies.

## Running

Open `project.godot` in Godot 4.3 or newer and press F5.

**In a browser:** every push to `main` publishes a web build to
https://enkiclaude.github.io/Swarmbreak/. Click the game once so it gets
keyboard focus; a controller works too. On a phone, turn it sideways: the
left thumb moves, hold FIRE to shoot (drag it to aim), and NOVA, LURE and
DODGE sit around it. Browsers use Godot's Compatibility
renderer, so the web build looks a little different from the Steam Deck build,
and its frame rate says little about the Deck.

## Milestones

- **M0:** flat arena, angled orthographic camera, twin-stick player, and a
  1,000-enemy swarm (packed arrays, flow field, spatial-hash separation,
  MultiMesh rendering) with a debug overlay.
- **M4:** jobs, bosses and refining. Choose a path at level 10 (Stormcaller,
  Warlord or Arcanist) that changes how an ability works, promoted at 25;
  camp bosses with a telegraphed ground slam and rare drops; refine items
  +0 to +10 with stones, where failure drops a level but never breaks it.
- **M3:** loot and progression. XP and levels with skill points for nine
  passive skills; camps drop weapons, charms and armor in three rarities;
  a pausing character screen for skills, equipment and the backpack.
- **M2:** RPG structure. A 128 m zone of sleeping enemy camps (grunts and
  brutes) that wake when you approach or hit them; a lure war cry that wakes
  camps in range and hurries them to you; health, mana and a dodge; zone
  clear and death/restart; HUD bars and a minimap.
- **M1:** the core loop. A nova pulse around the player and aimed bolts that
  burst in a small area, enemy health with a hit flash, and pooled death and
  impact effects. The overlay tracks kills and the best single "break".

| Action          | Controller      | Keyboard / mouse    |
|-----------------|-----------------|---------------------|
| Move            | Left stick      | WASD / arrows       |
| Aim             | Right stick     | Mouse               |
| Fire bolts      | RT (hold)       | Left mouse (hold)   |
| Nova            | RB              | Q / right mouse     |
| Lure            | LB              | E                   |
| Dodge           | A               | Space / Shift       |
| Character       | Start           | Tab / C / I         |
| Spawn 100 more  | View / Back     | `=` or keypad `+`   |
| Toggle overlay  | L3              | F3                  |

## Checks

`GODOT=/path/to/godot tools/check.sh` runs the headless tests, scenarios and
benchmark. CI runs it on every push.

Tuning lives in `data/`. See `CLAUDE.md` for project rules and architecture.
