class_name CharacterModels
extends RefCounted
## The game's characters, built from simple parts with ModelBuilder: the hero,
## one model per EnemyType.Model, pets at each stage and the Egg Keeper. Each stands on y = 0 facing -Z, sized
## to the given height, and is colored from three colors (main, second,
## accent) so data can recolor it. Legs and arms are rigged to walk.

const L := ModelBuilder.Limb
const SKIN_DARK := Color(0.16, 0.12, 0.1)
const BONE := Color(0.86, 0.84, 0.76)
const STEEL := Color(0.62, 0.64, 0.68)
const WOOD := Color(0.38, 0.25, 0.15)


## The model for an enemy type, scaled to its body height.
static func enemy(t: EnemyType, material: Material = null) -> ArrayMesh:
	var b := ModelBuilder.new()
	var main := t.color
	var second := t.secondary_color
	var accent := t.accent_color
	var h := t.body_height
	match t.model:
		EnemyType.Model.GOBLIN:
			_goblin(b, h, main, second, accent)
		EnemyType.Model.OGRE:
			_ogre(b, h, main, second, accent)
		EnemyType.Model.WARLORD:
			_warlord(b, h, main, second, accent)
		EnemyType.Model.SKELETON:
			_skeleton(b, h, main, second, accent)
		EnemyType.Model.TREANT:
			_treant(b, h, main, second, accent)
		EnemyType.Model.WISP:
			_wisp(b, h, main, second, accent)
	return b.build(material)


## The player: a robed battle-mage with shoulder guards, a wide hat and a
## staff topped by a glowing orb in the right hand.
static func hero(height: float, main: Color, second: Color, accent: Color,
		material: Material = null) -> ArrayMesh:
	var b := ModelBuilder.new()
	var s := height / 1.8
	var hip := 0.82 * s
	var shoulder := 1.36 * s
	b.pair("cylinder", Vector3(0.11 * s, hip * 0.5, 0.0), Vector3(0.07 * s, 0.08 * s, hip),
			SKIN_DARK, L.LEFT_LEG, L.RIGHT_LEG, hip)
	b.pair("box", Vector3(0.11 * s, 0.06 * s, -0.04 * s), Vector3(0.14, 0.12, 0.26) * s,
			second.darkened(0.4), L.LEFT_LEG, L.RIGHT_LEG, hip)
	# Robe: a flared skirt and a chest.
	b.cylinder(Vector3(0.0, 0.72 * s, 0.0), 0.34 * s, 0.22 * s, 0.6 * s, main)
	b.cylinder(Vector3(0.0, 1.14 * s, 0.0), 0.22 * s, 0.26 * s, 0.46 * s, main)
	b.cylinder(Vector3(0.0, 0.96 * s, 0.0), 0.24 * s, 0.24 * s, 0.08 * s, second)
	b.box(Vector3(0.0, 1.0 * s, -0.24 * s), Vector3(0.08, 0.34, 0.04) * s, accent)
	b.pair("sphere", Vector3(0.28 * s, shoulder, 0.0), Vector3(0.14, 0.09, 0.14) * s, second)
	b.pair("cylinder", Vector3(0.31 * s, shoulder - 0.24 * s, 0.0),
			Vector3(0.06 * s, 0.07 * s, 0.46 * s), main, L.LEFT_ARM, L.RIGHT_ARM, shoulder)
	b.pair("sphere", Vector3(0.31 * s, shoulder - 0.5 * s, 0.0), Vector3(0.06, 0.06, 0.06) * s,
			Color(0.85, 0.7, 0.58), L.LEFT_ARM, L.RIGHT_ARM, shoulder)
	# Head and a wide-brimmed hat.
	b.sphere(Vector3(0.0, 1.53 * s, 0.0), Vector3(0.12, 0.13, 0.12) * s, Color(0.85, 0.7, 0.58))
	b.cylinder(Vector3(0.0, 1.62 * s, 0.0), 0.3 * s, 0.26 * s, 0.03 * s, second)
	b.cylinder(Vector3(0.0, 1.73 * s, 0.0), 0.15 * s, 0.03 * s, 0.22 * s, second)
	# Staff in the right hand, swinging with the arm.
	var hand := Vector3(0.31 * s, shoulder - 0.5 * s, -0.06 * s)
	b.cylinder(hand + Vector3(0.0, 0.1 * s, 0.0), 0.025 * s, 0.025 * s, 1.5 * s, WOOD,
			L.RIGHT_ARM, shoulder)
	b.sphere(hand + Vector3(0.0, 0.88 * s, 0.0), Vector3(0.09, 0.09, 0.09) * s, accent,
			L.RIGHT_ARM, shoulder)
	return b.build(material)


## A hunched little raider: big head with long ears, glowing eyes, a club.
static func _goblin(b: ModelBuilder, h: float, main: Color, second: Color, accent: Color) -> void:
	var s := h / 1.0
	var hip := 0.32 * s
	var shoulder := 0.62 * s
	b.pair("cylinder", Vector3(0.1 * s, hip * 0.5, 0.0), Vector3(0.06 * s, 0.07 * s, hip),
			main.darkened(0.25), L.LEFT_LEG, L.RIGHT_LEG, hip)
	b.sphere(Vector3(0.0, 0.5 * s, 0.02 * s), Vector3(0.21, 0.24, 0.19) * s, second)
	b.sphere(Vector3(0.0, 0.8 * s, -0.06 * s), Vector3(0.17, 0.16, 0.16) * s, main)
	b.pair("box", Vector3(0.2 * s, 0.84 * s, -0.04 * s), Vector3(0.16, 0.04, 0.06) * s, main,
			L.BODY, L.BODY, 0.0, Vector3(0.0, 0.0, -25.0))
	b.pair("sphere", Vector3(0.06 * s, 0.82 * s, -0.2 * s), Vector3(0.03, 0.03, 0.02) * s, accent)
	b.pair("cylinder", Vector3(0.24 * s, shoulder - 0.15 * s, 0.0),
			Vector3(0.045 * s, 0.05 * s, 0.3 * s), main, L.LEFT_ARM, L.RIGHT_ARM, shoulder)
	b.cylinder(Vector3(0.24 * s, shoulder - 0.32 * s, -0.12 * s), 0.07 * s, 0.035 * s, 0.32 * s,
			WOOD, L.RIGHT_ARM, shoulder, Vector3(-70.0, 0.0, 0.0))


## A hulking brute: barrel body, small head, tusks, long heavy arms.
static func _ogre(b: ModelBuilder, h: float, main: Color, second: Color, accent: Color) -> void:
	var s := h / 1.5
	var hip := 0.42 * s
	var shoulder := 1.08 * s
	b.pair("cylinder", Vector3(0.17 * s, hip * 0.5, 0.0), Vector3(0.11 * s, 0.13 * s, hip),
			main.darkened(0.3), L.LEFT_LEG, L.RIGHT_LEG, hip)
	b.sphere(Vector3(0.0, 0.8 * s, 0.03 * s), Vector3(0.4, 0.38, 0.32) * s, main)
	b.cylinder(Vector3(0.0, 0.56 * s, 0.03 * s), 0.36 * s, 0.36 * s, 0.12 * s, second)
	b.sphere(Vector3(0.0, 1.22 * s, -0.12 * s), Vector3(0.15, 0.14, 0.15) * s, main)
	b.pair("cylinder", Vector3(0.07 * s, 1.16 * s, -0.25 * s), Vector3(0.025 * s, 0.0, 0.1 * s),
			BONE)
	b.pair("sphere", Vector3(0.06 * s, 1.26 * s, -0.25 * s), Vector3(0.025, 0.025, 0.02) * s,
			accent)
	b.pair("cylinder", Vector3(0.46 * s, shoulder - 0.32 * s, 0.0),
			Vector3(0.09 * s, 0.12 * s, 0.64 * s), main, L.LEFT_ARM, L.RIGHT_ARM, shoulder)
	b.pair("sphere", Vector3(0.46 * s, shoulder - 0.7 * s, 0.0), Vector3(0.13, 0.12, 0.13) * s,
			main.darkened(0.2), L.LEFT_ARM, L.RIGHT_ARM, shoulder)


## The camp boss: an armored giant with horned helm, pauldrons, a cape and
## a great blade.
static func _warlord(b: ModelBuilder, h: float, main: Color, second: Color, accent: Color) -> void:
	var s := h / 2.8
	var hip := 1.05 * s
	var shoulder := 2.05 * s
	b.pair("cylinder", Vector3(0.24 * s, hip * 0.5, 0.0), Vector3(0.15 * s, 0.17 * s, hip),
			STEEL.darkened(0.35), L.LEFT_LEG, L.RIGHT_LEG, hip)
	b.cylinder(Vector3(0.0, 1.55 * s, 0.0), 0.36 * s, 0.5 * s, 1.0 * s, main, L.BODY, 0.0,
			Vector3.ZERO, 6)
	b.cylinder(Vector3(0.0, 1.1 * s, 0.0), 0.42 * s, 0.4 * s, 0.16 * s, second)
	b.box(Vector3(0.0, 1.35 * s, 0.32 * s), Vector3(0.8, 1.3, 0.06) * s, second.darkened(0.3),
			L.FLOAT, 0.0, Vector3(-8.0, 0.0, 0.0))
	b.pair("sphere", Vector3(0.52 * s, shoulder, 0.0), Vector3(0.24, 0.16, 0.24) * s, STEEL)
	b.sphere(Vector3(0.0, 2.38 * s, -0.04 * s), Vector3(0.22, 0.25, 0.22) * s, STEEL)
	b.pair("cylinder", Vector3(0.24 * s, 2.6 * s, -0.02 * s), Vector3(0.06 * s, 0.0, 0.4 * s),
			BONE, L.BODY, L.BODY, 0.0, Vector3(0.0, 0.0, -35.0))
	b.box(Vector3(0.0, 2.36 * s, -0.22 * s), Vector3(0.24, 0.05, 0.04) * s, accent)
	b.pair("cylinder", Vector3(0.58 * s, shoulder - 0.42 * s, 0.0),
			Vector3(0.11 * s, 0.13 * s, 0.8 * s), main, L.LEFT_ARM, L.RIGHT_ARM, shoulder)
	b.box(Vector3(0.58 * s, shoulder - 0.95 * s, -0.55 * s), Vector3(0.12, 0.08, 1.4) * s,
			STEEL.lightened(0.2), L.RIGHT_ARM, shoulder)
	b.box(Vector3(0.58 * s, shoulder - 0.95 * s, -0.55 * s), Vector3(0.14, 0.03, 1.3) * s,
			accent, L.RIGHT_ARM, shoulder)


## Rattling bones: a skull with glowing eyes, ribs, thin limbs and a rusty sword.
static func _skeleton(b: ModelBuilder, h: float, main: Color, second: Color,
		accent: Color) -> void:
	var s := h / 1.1
	var hip := 0.46 * s
	var shoulder := 0.84 * s
	b.pair("cylinder", Vector3(0.09 * s, hip * 0.5, 0.0), Vector3(0.03 * s, 0.035 * s, hip),
			main, L.LEFT_LEG, L.RIGHT_LEG, hip)
	b.box(Vector3(0.0, hip + 0.02 * s, 0.0), Vector3(0.26, 0.08, 0.14) * s, main)
	b.cylinder(Vector3(0.0, 0.6 * s, 0.0), 0.03 * s, 0.03 * s, 0.3 * s, main)
	for k in 3:
		b.cylinder(Vector3(0.0, (0.64 + k * 0.07) * s, 0.0), 0.15 * s, 0.15 * s, 0.03 * s, main)
	b.box(Vector3(0.0, 0.82 * s, 0.06 * s), Vector3(0.3, 0.16, 0.04) * s, second)
	b.sphere(Vector3(0.0, 0.98 * s, -0.02 * s), Vector3(0.11, 0.12, 0.12) * s, main)
	b.pair("sphere", Vector3(0.045 * s, 0.99 * s, -0.12 * s), Vector3(0.025, 0.025, 0.01) * s,
			accent)
	b.pair("cylinder", Vector3(0.19 * s, shoulder - 0.17 * s, 0.0),
			Vector3(0.025 * s, 0.025 * s, 0.34 * s), main, L.LEFT_ARM, L.RIGHT_ARM, shoulder)
	b.box(Vector3(0.19 * s, shoulder - 0.34 * s, -0.24 * s), Vector3(0.04, 0.02, 0.5) * s,
			second.lightened(0.3), L.RIGHT_ARM, shoulder)


## A walking tree: bark trunk on root legs, branch arms, a crown of leaves
## (or bare twigs) and two glowing eyes in the bark.
static func _treant(b: ModelBuilder, h: float, main: Color, second: Color, accent: Color) -> void:
	var s := h / 1.8
	var hip := 0.4 * s
	var shoulder := 1.25 * s
	b.pair("cylinder", Vector3(0.16 * s, hip * 0.5, 0.0), Vector3(0.14 * s, 0.09 * s, hip),
			main.darkened(0.25), L.LEFT_LEG, L.RIGHT_LEG, hip)
	b.cylinder(Vector3(0.0, 0.9 * s, 0.0), 0.3 * s, 0.22 * s, 1.0 * s, main, L.BODY, 0.0,
			Vector3.ZERO, 7)
	b.pair("sphere", Vector3(0.08 * s, 1.15 * s, -0.22 * s), Vector3(0.04, 0.03, 0.02) * s,
			accent)
	b.pair("cylinder", Vector3(0.36 * s, shoulder - 0.05 * s, 0.0),
			Vector3(0.07 * s, 0.03 * s, 0.7 * s), main, L.LEFT_ARM, L.RIGHT_ARM, shoulder,
			Vector3(0.0, 0.0, 40.0))
	b.sphere(Vector3(0.0, 1.62 * s, 0.0), Vector3(0.48, 0.32, 0.44) * s, second)
	b.sphere(Vector3(0.22 * s, 1.5 * s, 0.1 * s), Vector3(0.26, 0.2, 0.24) * s, second.darkened(0.1))
	b.sphere(Vector3(-0.24 * s, 1.52 * s, -0.08 * s), Vector3(0.24, 0.2, 0.24) * s,
			second.lightened(0.08))


## A hovering spirit: a glowing core inside a tattered, tapering shroud and
## two wispy arms. Floats instead of walking.
static func _wisp(b: ModelBuilder, h: float, main: Color, second: Color, accent: Color) -> void:
	var s := h / 1.0
	var shoulder := 0.78 * s
	b.cylinder(Vector3(0.0, 0.55 * s, 0.0), 0.04 * s, 0.24 * s, 0.7 * s, main, L.FLOAT, 0.0,
			Vector3.ZERO, 6)
	b.sphere(Vector3(0.0, 0.88 * s, 0.0), Vector3(0.18, 0.2, 0.18) * s, main, L.FLOAT)
	b.sphere(Vector3(0.0, 0.72 * s, -0.12 * s), Vector3(0.1, 0.1, 0.1) * s, accent, L.FLOAT)
	b.pair("sphere", Vector3(0.06 * s, 0.9 * s, -0.16 * s), Vector3(0.03, 0.03, 0.02) * s,
			accent, L.FLOAT, L.FLOAT)
	b.pair("cylinder", Vector3(0.22 * s, shoulder - 0.15 * s, 0.0),
			Vector3(0.05 * s, 0.015 * s, 0.34 * s), second, L.LEFT_ARM, L.RIGHT_ARM, shoulder,
			Vector3(0.0, 0.0, 20.0))


## A pet at a stage: 0 is a speckled egg; then a little four-legged critter
## with wings and a tail that grows, gains a crest and horns as it evolves.
static func pet(stage: int, height: float, main: Color, accent: Color,
		material: Material = null) -> ArrayMesh:
	var b := ModelBuilder.new()
	if stage <= 0:
		b.sphere(Vector3(0.0, height * 0.5, 0.0), Vector3(0.36, 0.5, 0.36) * height,
				Color(0.95, 0.9, 0.8), L.FLOAT)
		for k in 6:
			var a := k * 1.1
			b.sphere(Vector3(cos(a) * 0.3, 0.3 + 0.08 * k, sin(a) * 0.3) * height,
					Vector3(0.07, 0.07, 0.05) * height, main, L.FLOAT)
		return b.build(material)
	var s := height / 0.55
	var hip := 0.16 * s
	b.pair("cylinder", Vector3(0.09 * s, hip * 0.5, 0.08 * s), Vector3(0.035 * s, 0.04 * s, hip),
			main.darkened(0.25), L.LEFT_LEG, L.RIGHT_LEG, hip)
	b.pair("cylinder", Vector3(0.09 * s, hip * 0.5, -0.08 * s), Vector3(0.035 * s, 0.04 * s, hip),
			main.darkened(0.25), L.RIGHT_LEG, L.LEFT_LEG, hip)
	b.sphere(Vector3(0.0, 0.26 * s, 0.0), Vector3(0.15, 0.13, 0.2) * s, main)
	b.sphere(Vector3(0.0, 0.25 * s, -0.04 * s), Vector3(0.1, 0.09, 0.13) * s, accent.lightened(0.3))
	b.sphere(Vector3(0.0, 0.42 * s, -0.17 * s), Vector3(0.11, 0.1, 0.11) * s, main)
	b.pair("sphere", Vector3(0.05 * s, 0.45 * s, -0.27 * s), Vector3(0.025, 0.03, 0.015) * s,
			Color(0.1, 0.08, 0.06))
	b.cylinder(Vector3(0.0, 0.24 * s, 0.26 * s), 0.05 * s, 0.0, 0.26 * s, main, L.FLOAT, 0.0,
			Vector3(-70.0, 0.0, 0.0))
	var wing := 0.14 + 0.05 * stage
	b.pair("box", Vector3(0.16 * s, 0.36 * s, 0.02 * s), Vector3(wing, 0.02, 0.12) * s, accent,
			L.LEFT_ARM, L.RIGHT_ARM, 0.36 * s, Vector3(0.0, 0.0, 25.0))
	if stage >= 2:
		for k in 3:
			b.cylinder(Vector3(0.0, (0.38 - k * 0.04) * s, (-0.1 + k * 0.1) * s), 0.025 * s, 0.0,
					0.08 * s, accent)
	if stage >= 3:
		b.pair("cylinder", Vector3(0.05 * s, 0.53 * s, -0.15 * s), Vector3(0.02 * s, 0.0, 0.12 * s),
				Color(0.95, 0.9, 0.8), L.BODY, L.BODY, 0.0, Vector3(25.0, 0.0, -20.0))
	return b.build(material)


## The Egg Keeper: a stooped old caretaker in a green robe and a wide hat,
## with a basket of eggs on one arm and a crook in the other hand.
static func keeper(height: float, robe: Color, material: Material = null) -> ArrayMesh:
	var b := ModelBuilder.new()
	var s := height / 1.7
	b.cylinder(Vector3(0.0, 0.5 * s, 0.0), 0.32 * s, 0.2 * s, 1.0 * s, robe)
	b.cylinder(Vector3(0.0, 1.12 * s, 0.03 * s), 0.2 * s, 0.24 * s, 0.32 * s, robe.lightened(0.1))
	b.sphere(Vector3(0.0, 1.38 * s, -0.06 * s), Vector3(0.11, 0.12, 0.11) * s,
			Color(0.82, 0.68, 0.55))
	b.cylinder(Vector3(0.0, 1.47 * s, -0.05 * s), 0.34 * s, 0.3 * s, 0.03 * s, Color(0.75, 0.6, 0.3))
	b.cylinder(Vector3(0.0, 1.56 * s, -0.05 * s), 0.13 * s, 0.03 * s, 0.18 * s, Color(0.75, 0.6, 0.3))
	b.pair("cylinder", Vector3(0.26 * s, 0.98 * s, -0.05 * s), Vector3(0.05 * s, 0.06 * s, 0.4 * s),
			robe, L.BODY, L.BODY, 0.0, Vector3(30.0, 0.0, 0.0))
	b.cylinder(Vector3(-0.3 * s, 0.75 * s, -0.22 * s), 0.16 * s, 0.13 * s, 0.14 * s, WOOD)
	for k in 3:
		b.sphere(Vector3((-0.36 + k * 0.06) * s, 0.86 * s, -0.22 * s), Vector3(0.05, 0.065, 0.05) * s,
				Color(0.95, 0.9, 0.8))
	b.cylinder(Vector3(0.32 * s, 0.85 * s, -0.25 * s), 0.02 * s, 0.02 * s, 1.7 * s, WOOD)
	b.cylinder(Vector3(0.32 * s, 1.72 * s, -0.33 * s), 0.02 * s, 0.02 * s, 0.2 * s, WOOD,
			L.BODY, 0.0, Vector3(70.0, 0.0, 0.0))
	return b.build(material)
