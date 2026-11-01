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


## The player, dressed in what it wears (HeroLook; null: the default staff
## and robe). Gear is dark metal and cloth trimmed in its rarity color.
## Parts painted with alpha below 1 glow (hero.gdshader): the weapon's gem
## always, and a refined weapon's blade more with every +.
static func hero(height: float, main: Color, second: Color, accent: Color,
		material: Material = null, look: HeroLook = null) -> ArrayMesh:
	if look == null:
		look = HeroLook.default_look(accent)
		look.armor_color = main
	var b := ModelBuilder.new()
	var s := height / 1.8
	var hip := 0.82 * s
	var shoulder := 1.36 * s
	var skin := Color(0.72, 0.58, 0.5)
	_hero_legs(b, s, hip, look)
	_hero_body(b, s, shoulder, look, main, second)
	_hero_arms(b, s, shoulder, look, main, skin)
	_hero_head(b, s, look, second, skin)
	_hero_weapon(b, s, shoulder, look, accent)
	_hero_off_hand(b, s, shoulder, look)
	return b.build(material)


## Dark base for a piece of gear in a rarity color, and its trim.
static func _gear_base(rarity_color: Color) -> Color:
	return rarity_color.darkened(0.72).lerp(Color(0.12, 0.11, 0.12), 0.35)


static func _metal(rarity_color: Color) -> Color:
	return STEEL.darkened(0.45).lerp(rarity_color, 0.18)


## A color that glows: amount 0 (none) to 1 (full).
static func _glowing(c: Color, amount: float) -> Color:
	return Color(c.r, c.g, c.b, 1.0 - clampf(amount, 0.0, 1.0))


static func _hero_legs(b: ModelBuilder, s: float, hip: float, look: HeroLook) -> void:
	if look.pants:
		var base := _gear_base(look.pants_color)
		b.pair("cylinder", Vector3(0.11 * s, hip * 0.5, 0.0), Vector3(0.085 * s, 0.1 * s, hip),
				base, L.LEFT_LEG, L.RIGHT_LEG, hip)
		b.pair("cylinder", Vector3(0.11 * s, hip * 0.48, 0.0), Vector3(0.095 * s, 0.095 * s,
				0.05 * s), look.pants_color.darkened(0.2), L.LEFT_LEG, L.RIGHT_LEG, hip)
	else:
		b.pair("cylinder", Vector3(0.11 * s, hip * 0.5, 0.0), Vector3(0.07 * s, 0.08 * s, hip),
				SKIN_DARK, L.LEFT_LEG, L.RIGHT_LEG, hip)
	if look.boots:
		var base := _gear_base(look.boots_color)
		b.pair("box", Vector3(0.11 * s, 0.07 * s, -0.04 * s), Vector3(0.16, 0.14, 0.3) * s, base,
				L.LEFT_LEG, L.RIGHT_LEG, hip)
		b.pair("cylinder", Vector3(0.11 * s, 0.2 * s, 0.0), Vector3(0.1 * s, 0.09 * s, 0.16 * s),
				base, L.LEFT_LEG, L.RIGHT_LEG, hip)
		b.pair("cylinder", Vector3(0.11 * s, 0.29 * s, 0.0), Vector3(0.105 * s, 0.105 * s,
				0.04 * s), look.boots_color.darkened(0.15), L.LEFT_LEG, L.RIGHT_LEG, hip)
	else:
		b.pair("box", Vector3(0.11 * s, 0.06 * s, -0.04 * s), Vector3(0.14, 0.12, 0.26) * s,
				Color(0.14, 0.11, 0.09), L.LEFT_LEG, L.RIGHT_LEG, hip)


static func _hero_body(b: ModelBuilder, s: float, shoulder: float, look: HeroLook, main: Color,
		second: Color) -> void:
	match look.armor:
		ItemKindDef.Icon.PLATE:
			var metal := _metal(look.armor_color)
			var trim := look.armor_color.darkened(0.1)
			b.box(Vector3(0.0, 1.14 * s, 0.0), Vector3(0.5, 0.5, 0.32) * s, metal)
			b.box(Vector3(0.0, 1.16 * s, -0.165 * s), Vector3(0.12, 0.36, 0.02) * s, trim)
			b.box(Vector3(0.0, 0.9 * s, 0.0), Vector3(0.44, 0.1, 0.28) * s, trim.darkened(0.3))
			# Tassets over the hips.
			b.pair("box", Vector3(0.14 * s, 0.74 * s, -0.02 * s), Vector3(0.18, 0.24, 0.3) * s,
					metal.darkened(0.15), L.BODY, L.BODY, 0.0, Vector3(0, 0, 8))
			# Big pauldrons with a spike.
			b.pair("sphere", Vector3(0.3 * s, shoulder + 0.02 * s, 0.0), Vector3(0.18, 0.12, 0.18) * s,
					metal)
			b.pair("cylinder", Vector3(0.34 * s, shoulder + 0.14 * s, 0.0), Vector3(0.04 * s,
					0.0, 0.16 * s), trim)
		ItemKindDef.Icon.ROBE:
			var cloth := _gear_base(look.armor_color)
			var trim := look.armor_color.darkened(0.15)
			b.cylinder(Vector3(0.0, 0.7 * s, 0.0), 0.36 * s, 0.22 * s, 0.64 * s, cloth)
			b.cylinder(Vector3(0.0, 1.14 * s, 0.0), 0.22 * s, 0.26 * s, 0.46 * s, cloth)
			b.cylinder(Vector3(0.0, 0.4 * s, 0.0), 0.365 * s, 0.36 * s, 0.05 * s, trim)
			b.cylinder(Vector3(0.0, 0.96 * s, 0.0), 0.24 * s, 0.24 * s, 0.08 * s, trim)
			b.box(Vector3(0.0, 1.0 * s, -0.24 * s), Vector3(0.08, 0.34, 0.04) * s, trim)
			b.pair("sphere", Vector3(0.28 * s, shoulder, 0.0), Vector3(0.14, 0.09, 0.14) * s, trim)
		_:
			# No armor: a plain dark tunic.
			var tunic := main.darkened(0.55)
			b.cylinder(Vector3(0.0, 0.78 * s, 0.0), 0.27 * s, 0.22 * s, 0.4 * s, tunic)
			b.cylinder(Vector3(0.0, 1.14 * s, 0.0), 0.21 * s, 0.24 * s, 0.46 * s, tunic)
			b.cylinder(Vector3(0.0, 0.96 * s, 0.0), 0.23 * s, 0.23 * s, 0.06 * s,
					second.darkened(0.5))


static func _hero_arms(b: ModelBuilder, s: float, shoulder: float, look: HeroLook, main: Color,
		skin: Color) -> void:
	var sleeve := main.darkened(0.55)
	if look.armor == ItemKindDef.Icon.PLATE:
		sleeve = _metal(look.armor_color).darkened(0.1)
	elif look.armor == ItemKindDef.Icon.ROBE:
		sleeve = _gear_base(look.armor_color)
	b.pair("cylinder", Vector3(0.31 * s, shoulder - 0.24 * s, 0.0),
			Vector3(0.06 * s, 0.07 * s, 0.46 * s), sleeve, L.LEFT_ARM, L.RIGHT_ARM, shoulder)
	if look.gloves:
		var base := _gear_base(look.gloves_color)
		b.pair("cylinder", Vector3(0.31 * s, shoulder - 0.4 * s, 0.0), Vector3(0.075 * s,
				0.08 * s, 0.16 * s), base, L.LEFT_ARM, L.RIGHT_ARM, shoulder)
		b.pair("cylinder", Vector3(0.31 * s, shoulder - 0.33 * s, 0.0), Vector3(0.085 * s,
				0.085 * s, 0.03 * s), look.gloves_color.darkened(0.15), L.LEFT_ARM, L.RIGHT_ARM,
				shoulder)
		b.pair("sphere", Vector3(0.31 * s, shoulder - 0.5 * s, 0.0), Vector3(0.075, 0.07, 0.075)
				* s, base, L.LEFT_ARM, L.RIGHT_ARM, shoulder)
	else:
		b.pair("sphere", Vector3(0.31 * s, shoulder - 0.5 * s, 0.0), Vector3(0.06, 0.06, 0.06)
				* s, skin, L.LEFT_ARM, L.RIGHT_ARM, shoulder)


static func _hero_head(b: ModelBuilder, s: float, look: HeroLook, second: Color,
		skin: Color) -> void:
	b.sphere(Vector3(0.0, 1.53 * s, 0.0), Vector3(0.12, 0.13, 0.12) * s, skin)
	if look.helm:
		var metal := _metal(look.helm_color)
		var trim := look.helm_color.darkened(0.1)
		b.sphere(Vector3(0.0, 1.58 * s, 0.0), Vector3(0.15, 0.15, 0.15) * s, metal)
		b.box(Vector3(0.0, 1.5 * s, -0.12 * s), Vector3(0.2, 0.08, 0.06) * s, metal.darkened(0.2))
		# Eye slit and a crest.
		b.box(Vector3(0.0, 1.56 * s, -0.145 * s), Vector3(0.16, 0.02, 0.02) * s,
				_glowing(trim.lightened(0.3), 0.6))
		b.box(Vector3(0.0, 1.75 * s, 0.02 * s), Vector3(0.03, 0.1, 0.26) * s, trim)
		b.pair("cylinder", Vector3(0.13 * s, 1.68 * s, 0.0), Vector3(0.03 * s, 0.0, 0.16 * s),
				trim, L.BODY, L.BODY, 0.0, Vector3(0, 0, -35))
	else:
		# A wide-brimmed hat.
		var hat := second.darkened(0.45)
		b.cylinder(Vector3(0.0, 1.62 * s, 0.0), 0.3 * s, 0.26 * s, 0.03 * s, hat)
		b.cylinder(Vector3(0.0, 1.73 * s, 0.0), 0.15 * s, 0.03 * s, 0.22 * s, hat)


## The weapon in the right hand, swinging with the arm.
static func _hero_weapon(b: ModelBuilder, s: float, shoulder: float, look: HeroLook,
		accent: Color) -> void:
	var hand := Vector3(0.31 * s, shoulder - 0.5 * s, -0.06 * s)
	var color := look.weapon_color
	var refine := look.weapon_glow / 10.0
	var gem := _glowing(color.lightened(0.25), 1.0)
	var arm := L.RIGHT_ARM
	match look.weapon:
		ItemKindDef.Icon.STAFF:
			b.cylinder(hand + Vector3(0.0, 0.1 * s, 0.0), 0.025 * s, 0.025 * s, 1.5 * s,
					WOOD.darkened(0.35), arm, shoulder)
			b.cylinder(hand + Vector3(0.0, 0.8 * s, 0.0), 0.06 * s, 0.03 * s, 0.14 * s,
					_metal(color), arm, shoulder)
			b.sphere(hand + Vector3(0.0, 0.92 * s, 0.0), Vector3(0.09, 0.09, 0.09) * s, gem, arm,
					shoulder)
		ItemKindDef.Icon.WAND:
			b.cylinder(hand + Vector3(0.0, 0.2 * s, 0.0), 0.02 * s, 0.03 * s, 0.55 * s,
					Color(0.12, 0.1, 0.12), arm, shoulder)
			b.sphere(hand + Vector3(0.0, 0.5 * s, 0.0), Vector3(0.05, 0.07, 0.05) * s, gem, arm,
					shoulder)
		ItemKindDef.Icon.SWORD, ItemKindDef.Icon.GREATSWORD:
			var big := look.weapon == ItemKindDef.Icon.GREATSWORD
			var length := (1.15 if big else 0.75) * s
			var width := (0.1 if big else 0.06) * s
			b.cylinder(hand + Vector3(0.0, 0.02 * s, 0.0), 0.025 * s, 0.025 * s, 0.2 * s,
					Color(0.16, 0.1, 0.07), arm, shoulder)
			b.box(hand + Vector3(0.0, 0.13 * s, 0.0), Vector3(0.05, 0.04, (0.32 if big else 0.22))
					* s, color.darkened(0.2), arm, shoulder)
			b.box(hand + Vector3(0.0, 0.15 * s + length * 0.5, 0.0), Vector3(0.02 * s, length,
					width), _glowing(STEEL.lerp(color, 0.25), refine), arm, shoulder)
			b.sphere(hand + Vector3(0.0, 0.13 * s, 0.0), Vector3(0.03, 0.03, 0.03) * s, gem, arm,
					shoulder)
		_:
			# Bare hand: a faint orb of magic.
			b.sphere(hand + Vector3(0.0, 0.08 * s, 0.0), Vector3(0.05, 0.05, 0.05) * s,
					_glowing(accent, 0.8), arm, shoulder)


## A shield on the left forearm, or a tome in the left hand.
static func _hero_off_hand(b: ModelBuilder, s: float, shoulder: float, look: HeroLook) -> void:
	var hand := Vector3(-0.31 * s, shoulder - 0.5 * s, -0.06 * s)
	var color := look.off_hand_color
	match look.off_hand:
		ItemKindDef.Icon.SHIELD:
			var at := Vector3(-0.4 * s, shoulder - 0.36 * s, -0.04 * s)
			b.box(at, Vector3(0.05, 0.5, 0.4) * s, _metal(color), L.LEFT_ARM, shoulder)
			b.box(at + Vector3(-0.03 * s, 0.0, 0.0), Vector3(0.02, 0.42, 0.06) * s,
					color.darkened(0.15), L.LEFT_ARM, shoulder)
			b.sphere(at + Vector3(-0.04 * s, 0.04 * s, 0.0), Vector3(0.03, 0.06, 0.06) * s,
					_glowing(color, 0.5), L.LEFT_ARM, shoulder)
		ItemKindDef.Icon.TOME:
			b.box(hand + Vector3(0.0, 0.02 * s, -0.04 * s), Vector3(0.06, 0.22, 0.17) * s,
					_gear_base(color), L.LEFT_ARM, shoulder)
			b.box(hand + Vector3(-0.035 * s, 0.02 * s, -0.04 * s), Vector3(0.01, 0.1, 0.08) * s,
					_glowing(color, 0.9), L.LEFT_ARM, shoulder)


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
