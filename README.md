# Swarmbreak

A Godot 4 action RPG about luring enemies into enormous packs and breaking them
with area-of-effect attacks. Built for Steam Deck: 1280x800, locked 60 fps with
600+ enemies.

## Running

Open `project.godot` in Godot 4.3 or newer and press F5.

**In a browser:** every push to `main` publishes a web build to
https://enkiclaude.github.io/Swarmbreak/. Click the game once so it gets
keyboard focus; a controller works too. On a phone, turn it sideways: the
left thumb moves, hold FIRE to shoot (drag it sideways to turn the camera),
and NOVA, LURE and
DODGE sit around it. Browsers use Godot's Compatibility
renderer, so the web build looks a little different from the Steam Deck build,
and its frame rate says little about the Deck.

## Milestones

- **M0:** flat arena, angled orthographic camera, twin-stick player, and a
  1,000-enemy swarm (packed arrays, flow field, spatial-hash separation,
  MultiMesh rendering) with a debug overlay.
- **M10:** evasion and Geon. Agility (and some armor, belts and rings) now
  gives evasion, a chance to ignore each hit outright, up to 85%. The
  currency is Geon: camps, bosses and spawners drop piles of it, and items
  drop at a twentieth of the old rate.
- **M9:** characters and monsters. The hero is a robed battle-mage with a
  wide hat and an orb-topped staff, raised when casting; six monster models
  (goblin, ogre, warlord boss, skeleton, treant, wisp) walk, face where
  they're going and flash when hit. Regions field their own monsters:
  goblins and ogres near town, wisps and treants in the forests and fens,
  skeletons in the temple, wastes, ridge and crypt. All models are built in
  code from simple shapes.
- **M8:** gear and stats. The camera zooms out with the mouse wheel
  (D-pad, R3 or the touch ZOOM button). Seven equipment slots: main and off
  hand (two-handed staves and greatblades, or a wand or blade with a tome or
  shield), armor, amulet, belt and two rings, with eleven item kinds, drawn
  icons and hover tooltips that compare against what you're wearing.
  Salvage All now covers rares and everything at once. Five attributes
  (Strength, Health, Intelligence, Wisdom, Agility) take 5 points per level.
  Dungeon camps, bosses and spawners come back instantly.
- **M7:** the open world. A 3x3 map of regions around the town of Jade
  Village, getting harder away from it, with seamless walking between them
  (each region's name, ground and light blend in). Camps stream in as you
  approach and come back a minute after you clear them. Two dungeons behind
  gates (Crimson Sanctum, Moonstone Crypt) hold tougher monsters, better
  drops, a boss, and spawners that refill at once for farming. Dying sends
  you back to town. On the web build, `?region=0` to `?region=8` or
  `?dungeon=1` / `?dungeon=2` jump straight there.
- **M6:** the eastern-fantasy look. A third-person camera behind the
  player that the right stick (or the captured mouse) turns; five zone
  themes in turn (Jade Village, Vermilion Hall, Moonstone Crypt, Sunscorched
  Temple, Ashen Wastes) with their own floors, walls, pillars, lanterns,
  houses, trees, fog and light; lightning on the nova, fire bursts, pillars
  of light and floating damage numbers; a framed character panel, a round
  minimap that turns with the camera, and a skill column with cooldowns.
  All art is original and generated in code.
- **M5:** saving. Autosaves your character, gear and zone; reload to carry
  on; New Game on the character screen starts over.
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
| Turn camera     | Right stick     | Mouse (click to capture, Esc frees) |
| Zoom camera     | D-pad, R3       | Mouse wheel, Z      |
| Fire bolts      | RT (hold)       | Left mouse (hold)   |
| Nova            | RB              | Q / right mouse     |
| Lure            | LB              | E                   |
| Dodge           | A               | Space / Shift       |
| Character       | Start           | Tab / C             |
| Inventory       | Y               | I                   |
| Spawn 100 more  | View / Back     | `=` or keypad `+`   |
| Toggle overlay  | L3              | F3                  |

## Checks

`GODOT=/path/to/godot tools/check.sh` runs the headless tests, scenarios and
benchmark. CI runs it on every push.

Tuning lives in `data/`. See `CLAUDE.md` for project rules and architecture.
