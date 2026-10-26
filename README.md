# Swarmbreak

A Godot 4 action RPG about luring enemies into enormous packs and breaking them
with area-of-effect attacks. Built for Steam Deck: 1280x800, locked 60 fps with
600+ enemies.

## Running

Open `project.godot` in Godot 4.3 or newer and press F5.

## Milestone M0

A flat arena with an angled orthographic camera, a twin-stick player capsule,
and a 1,000-enemy swarm (packed arrays, flow field, spatial-hash separation,
MultiMesh rendering). A debug overlay shows fps, frame time, swarm tick time and
enemy count.

| Action          | Controller  | Keyboard / mouse  |
|-----------------|-------------|-------------------|
| Move            | Left stick  | WASD / arrows     |
| Aim             | Right stick | Mouse             |
| Spawn 100 more  | View / Back | `=` or keypad `+` |
| Toggle overlay  |             | F3                |

Tuning lives in `data/`. See `CLAUDE.md` for project rules and architecture.
