class_name ItemIcon
extends Control
## Draws an item's icon (ItemKindDef.Icon) from simple shapes: the item in a
## steel-and-gold palette with its rarity color as the accent (gem, edge,
## glow). Faded draws an empty slot's outline. Fills its rect, keeping square.

const STEEL := Color(0.78, 0.8, 0.85)
const DARK := Color(0.32, 0.26, 0.2)
const GOLD := Color(0.88, 0.7, 0.32)
const LEATHER := Color(0.5, 0.33, 0.2)
const CLOTH := Color(0.42, 0.3, 0.55)
## Icon when an item's kind is unknown, per AffixDef.Slot.
const SLOT_DEFAULTS: PackedInt32Array = [
	ItemKindDef.Icon.WAND, ItemKindDef.Icon.AMULET, ItemKindDef.Icon.ROBE,
	ItemKindDef.Icon.TOME, ItemKindDef.Icon.BELT, ItemKindDef.Icon.RING, ItemKindDef.Icon.HELM,
	ItemKindDef.Icon.GLOVES, ItemKindDef.Icon.PANTS, ItemKindDef.Icon.BOOTS, ItemKindDef.Icon.EGG,
]

var glyph: int = ItemKindDef.Icon.WAND
var accent := Color.WHITE
## An empty slot: a faint outline of what goes there.
var faded := false


## The icon an item shows.
static func glyph_for(item: ItemData, loot: LootConfig) -> int:
	if item.is_talisman:
		return ItemKindDef.Icon.TALISMAN
	if item.kind >= 0 and item.kind < loot.item_kinds.size():
		return loot.item_kinds[item.kind].icon
	return SLOT_DEFAULTS[clampi(item.slot, 0, SLOT_DEFAULTS.size() - 1)]


static func make(p_glyph: int, p_accent: Color, p_faded: bool = false) -> ItemIcon:
	var icon := ItemIcon.new()
	icon.glyph = p_glyph
	icon.accent = p_accent
	icon.faded = p_faded
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _draw() -> void:
	var s := minf(size.x, size.y)
	var o := (size - Vector2(s, s)) * 0.5
	# Unit coordinates (0..1) to pixels.
	var p := func(x: float, y: float) -> Vector2: return o + Vector2(x, y) * s
	var tint := Color(1, 1, 1, 0.22) if faded else Color.WHITE
	match glyph:
		ItemKindDef.Icon.WAND:
			_line(p.call(0.25, 0.8), p.call(0.68, 0.32), DARK * tint, s * 0.08)
			_star(p.call(0.72, 0.28), s * 0.14, accent * tint)
		ItemKindDef.Icon.SWORD:
			_poly([p.call(0.72, 0.18), p.call(0.8, 0.22), p.call(0.42, 0.6), p.call(0.36, 0.54)],
					STEEL * tint)
			_line(p.call(0.3, 0.48), p.call(0.48, 0.66), GOLD * tint, s * 0.06)
			_line(p.call(0.38, 0.6), p.call(0.22, 0.76), LEATHER * tint, s * 0.07)
			draw_circle(p.call(0.2, 0.78), s * 0.045, accent * tint)
		ItemKindDef.Icon.STAFF:
			_line(p.call(0.22, 0.88), p.call(0.66, 0.26), DARK * tint, s * 0.07)
			draw_arc(p.call(0.7, 0.22), s * 0.13, 0.0, TAU, 20, GOLD * tint, s * 0.04, true)
			draw_circle(p.call(0.7, 0.22), s * 0.08, accent * tint)
		ItemKindDef.Icon.GREATSWORD:
			_poly([p.call(0.78, 0.1), p.call(0.88, 0.16), p.call(0.42, 0.66), p.call(0.32, 0.56)],
					STEEL * tint)
			_line(p.call(0.24, 0.5), p.call(0.48, 0.74), GOLD * tint, s * 0.07)
			_line(p.call(0.36, 0.62), p.call(0.16, 0.84), LEATHER * tint, s * 0.08)
			_line(p.call(0.8, 0.16), p.call(0.4, 0.6), accent * tint, s * 0.02)
		ItemKindDef.Icon.TOME:
			draw_rect(Rect2(p.call(0.24, 0.18), Vector2(0.52, 0.64) * s), CLOTH * tint)
			draw_rect(Rect2(p.call(0.24, 0.18), Vector2(0.08, 0.64) * s), DARK * tint)
			draw_rect(Rect2(p.call(0.7, 0.22), Vector2(0.04, 0.56) * s), Color(0.95, 0.9, 0.8) * tint)
			_star(p.call(0.52, 0.5), s * 0.12, accent * tint)
		ItemKindDef.Icon.SHIELD:
			var shield := [p.call(0.22, 0.2), p.call(0.78, 0.2), p.call(0.76, 0.52),
					p.call(0.5, 0.86), p.call(0.24, 0.52)]
			_poly(shield, STEEL * tint)
			_outline(shield, GOLD * tint, s * 0.04)
			draw_circle(p.call(0.5, 0.46), s * 0.09, accent * tint)
		ItemKindDef.Icon.ROBE:
			var robe := [p.call(0.36, 0.16), p.call(0.64, 0.16), p.call(0.84, 0.36),
					p.call(0.72, 0.42), p.call(0.74, 0.86), p.call(0.26, 0.86), p.call(0.28, 0.42),
					p.call(0.16, 0.36)]
			_poly(robe, CLOTH * tint)
			_line(p.call(0.5, 0.2), p.call(0.5, 0.86), accent * tint, s * 0.04)
		ItemKindDef.Icon.PLATE:
			var plate := [p.call(0.3, 0.16), p.call(0.7, 0.16), p.call(0.84, 0.3), p.call(0.74, 0.44),
					p.call(0.7, 0.84), p.call(0.3, 0.84), p.call(0.26, 0.44), p.call(0.16, 0.3)]
			_poly(plate, STEEL * tint)
			_outline(plate, GOLD * tint, s * 0.03)
			_line(p.call(0.32, 0.56), p.call(0.68, 0.56), accent * tint, s * 0.04)
		ItemKindDef.Icon.AMULET:
			draw_arc(p.call(0.5, 0.3), s * 0.24, 0.15 * PI, 0.85 * PI, 20, GOLD * tint, s * 0.04,
					true)
			draw_arc(p.call(0.5, 0.3), s * 0.24, PI, TAU, 20, GOLD * tint, s * 0.04, true)
			_poly([p.call(0.5, 0.52), p.call(0.62, 0.66), p.call(0.5, 0.84), p.call(0.38, 0.66)],
					accent * tint)
		ItemKindDef.Icon.BELT:
			draw_rect(Rect2(p.call(0.12, 0.4), Vector2(0.76, 0.2) * s), LEATHER * tint)
			draw_rect(Rect2(p.call(0.4, 0.34), Vector2(0.2, 0.32) * s), GOLD * tint, false, s * 0.05)
			draw_circle(p.call(0.5, 0.5), s * 0.04, accent * tint)
		ItemKindDef.Icon.HELM:
			var dome := [p.call(0.22, 0.62), p.call(0.26, 0.36), p.call(0.4, 0.22), p.call(0.6, 0.22),
					p.call(0.74, 0.36), p.call(0.78, 0.62)]
			_poly(dome, STEEL * tint)
			draw_rect(Rect2(p.call(0.18, 0.6), Vector2(0.64, 0.1) * s), GOLD * tint)
			_line(p.call(0.5, 0.24), p.call(0.5, 0.6), accent * tint, s * 0.05)
			_poly([p.call(0.3, 0.7), p.call(0.38, 0.7), p.call(0.36, 0.84), p.call(0.3, 0.8)],
					STEEL * tint)
			_poly([p.call(0.62, 0.7), p.call(0.7, 0.7), p.call(0.7, 0.8), p.call(0.64, 0.84)],
					STEEL * tint)
		ItemKindDef.Icon.GLOVES:
			_poly([p.call(0.3, 0.82), p.call(0.3, 0.42), p.call(0.36, 0.22), p.call(0.44, 0.24),
					p.call(0.46, 0.4), p.call(0.52, 0.18), p.call(0.6, 0.2), p.call(0.6, 0.4),
					p.call(0.72, 0.34), p.call(0.76, 0.42), p.call(0.66, 0.6), p.call(0.66, 0.82)],
					LEATHER * tint)
			draw_rect(Rect2(p.call(0.28, 0.72), Vector2(0.4, 0.1) * s), accent * tint)
		ItemKindDef.Icon.PANTS:
			_poly([p.call(0.28, 0.2), p.call(0.72, 0.2), p.call(0.76, 0.84), p.call(0.56, 0.84),
					p.call(0.5, 0.42), p.call(0.44, 0.84), p.call(0.24, 0.84)], CLOTH * tint)
			draw_rect(Rect2(p.call(0.28, 0.2), Vector2(0.44, 0.08) * s), accent * tint)
		ItemKindDef.Icon.BOOTS:
			_poly([p.call(0.3, 0.18), p.call(0.52, 0.18), p.call(0.52, 0.62), p.call(0.8, 0.68),
					p.call(0.82, 0.82), p.call(0.28, 0.82)], LEATHER * tint)
			draw_rect(Rect2(p.call(0.28, 0.18), Vector2(0.26, 0.08) * s), accent * tint)
		ItemKindDef.Icon.EGG:
			draw_set_transform(p.call(0.5, 0.52), 0.0, Vector2(1.0, 1.25))
			draw_circle(Vector2.ZERO, s * 0.26, Color(0.95, 0.9, 0.8) * tint)
			draw_circle(Vector2(-s * 0.08, -s * 0.08), s * 0.06, accent * tint)
			draw_circle(Vector2(s * 0.1, s * 0.06), s * 0.05, accent * tint)
			draw_circle(Vector2(-s * 0.04, s * 0.14), s * 0.04, accent * tint)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		ItemKindDef.Icon.TALISMAN:
			# A six-sided charm on a cord with a rune cut in it.
			_line(p.call(0.5, 0.1), p.call(0.5, 0.24), LEATHER * tint, s * 0.04)
			var charm: Array = []
			for k in 6:
				var a := PI / 6.0 + k * TAU / 6.0
				charm.append(p.call(0.5 + cos(a) * 0.3, 0.55 + sin(a) * 0.3))
			_poly(charm, GOLD * tint)
			_outline(charm, DARK * tint, s * 0.03)
			_line(p.call(0.5, 0.38), p.call(0.5, 0.72), accent * tint, s * 0.06)
			_line(p.call(0.38, 0.48), p.call(0.62, 0.62), accent * tint, s * 0.05)
			_line(p.call(0.62, 0.48), p.call(0.38, 0.62), accent * tint, s * 0.05)
		ItemKindDef.Icon.RING:
			draw_arc(p.call(0.5, 0.58), s * 0.24, 0.0, TAU, 28, GOLD * tint, s * 0.08, true)
			_poly([p.call(0.5, 0.18), p.call(0.62, 0.3), p.call(0.5, 0.42), p.call(0.38, 0.3)],
					accent * tint)


func _line(a: Vector2, b: Vector2, color: Color, width: float) -> void:
	draw_line(a, b, color, width, true)


func _poly(points: Array, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array(points), color)


func _outline(points: Array, color: Color, width: float) -> void:
	var closed := PackedVector2Array(points)
	closed.append(points[0])
	draw_polyline(closed, color, width, true)


## A four-pointed sparkle.
func _star(at: Vector2, r: float, color: Color) -> void:
	_poly([at + Vector2(0, -r), at + Vector2(r * 0.3, -r * 0.3), at + Vector2(r, 0),
			at + Vector2(r * 0.3, r * 0.3), at + Vector2(0, r), at + Vector2(-r * 0.3, r * 0.3),
			at + Vector2(-r, 0), at + Vector2(-r * 0.3, -r * 0.3)], color)
