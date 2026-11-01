class_name HeroLook
extends RefCounted
## What the hero visibly wears, read from the equipped items: which weapon
## and off-hand shape (by item icon), robe or plate, and whether a helm,
## gloves, pants and boots are on, each colored by its rarity. A refined
## weapon glows brighter per +. signature() changes only when the look
## does, so the model is rebuilt only then.

const NONE := -1

var weapon := NONE
var weapon_color := Color.WHITE
## Refine level of the weapon (0..10): how hard it glows.
var weapon_glow := 0
var off_hand := NONE
var off_hand_color := Color.WHITE
var armor := NONE
var armor_color := Color.WHITE
var helm := false
var helm_color := Color.WHITE
var gloves := false
var gloves_color := Color.WHITE
var pants := false
var pants_color := Color.WHITE
var boots := false
var boots_color := Color.WHITE


## The look of the default hero with nothing worn: a staff and a robe, the
## way the hero looks before any loot (and in tests).
static func default_look(accent: Color) -> HeroLook:
	var look := HeroLook.new()
	look.weapon = ItemKindDef.Icon.STAFF
	look.weapon_color = accent
	look.armor = ItemKindDef.Icon.ROBE
	look.armor_color = Color(0.18, 0.38, 0.62)
	return look


static func from_inventory(inventory: Inventory, loot: LootConfig) -> HeroLook:
	var look := HeroLook.new()
	var item := inventory.equipped[Inventory.Equip.MAIN_HAND]
	if item != null:
		look.weapon = ItemIcon.glyph_for(item, loot)
		look.weapon_color = _color(item, loot)
		look.weapon_glow = item.upgrade_level
	item = inventory.equipped[Inventory.Equip.OFF_HAND]
	if item != null:
		look.off_hand = ItemIcon.glyph_for(item, loot)
		look.off_hand_color = _color(item, loot)
	item = inventory.equipped[Inventory.Equip.ARMOR]
	if item != null:
		look.armor = ItemIcon.glyph_for(item, loot)
		look.armor_color = _color(item, loot)
	item = inventory.equipped[Inventory.Equip.HELM]
	look.helm = item != null
	if item != null:
		look.helm_color = _color(item, loot)
	item = inventory.equipped[Inventory.Equip.GLOVES]
	look.gloves = item != null
	if item != null:
		look.gloves_color = _color(item, loot)
	item = inventory.equipped[Inventory.Equip.PANTS]
	look.pants = item != null
	if item != null:
		look.pants_color = _color(item, loot)
	item = inventory.equipped[Inventory.Equip.BOOTS]
	look.boots = item != null
	if item != null:
		look.boots_color = _color(item, loot)
	return look


static func _color(item: ItemData, loot: LootConfig) -> Color:
	return loot.rarity_colors[clampi(item.rarity, 0, loot.rarity_colors.size() - 1)]


## Changes whenever anything visible changes.
func signature() -> String:
	return "%d %s %d|%d %s|%d %s|%s %s|%s %s|%s %s|%s %s" % [weapon, weapon_color.to_html(),
			weapon_glow, off_hand, off_hand_color.to_html(), armor, armor_color.to_html(), helm,
			helm_color.to_html(), gloves, gloves_color.to_html(), pants, pants_color.to_html(),
			boots, boots_color.to_html()]
