# Swarmbreak

A Godot 4 action RPG about luring enemies into enormous packs and breaking them
with area-of-effect attacks. Built for Steam Deck: 1280x800, locked 60 fps with
600+ enemies.

## Running

Open `project.godot` in Godot 4.3 or newer and press F5.

## Milestones

- **M0:** flat arena, angled orthographic camera, twin-stick player, and a
  1,000-enemy swarm (packed arrays, flow field, spatial-hash separation,
  MultiMesh rendering) with a debug overlay.
- **M1:** the core loop. A nova pulse around the player and aimed bolts that
  burst in a small area, enemy health with a hit flash, and pooled death and
  impact effects. The overlay tracks kills and the best single "break".

| Action          | Controller      | Keyboard / mouse    |
|-----------------|-----------------|---------------------|
| Move            | Left stick      | WASD / arrows       |
| Aim             | Right stick     | Mouse               |
| Fire bolts      | RT, or hold aim | Left mouse          |
| Nova            | RB              | Space / right mouse |
| Spawn 100 more  | View / Back     | `=` or keypad `+`   |
| Toggle overlay  | L3              | F3                  |

## Checks

`GODOT=/path/to/godot tools/check.sh` runs the headless tests, scenarios and
benchmark. CI runs it on every push.

Tuning lives in `data/`. See `CLAUDE.md` for project rules and architecture.
