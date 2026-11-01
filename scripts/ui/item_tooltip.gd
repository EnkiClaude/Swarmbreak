class_name ItemTooltip
extends RefCounted
## The floating card shown while an item is hovered or focused in the
## inventory: icon and name in rarity color, kind, hands, slot and level, its
## stats, and (for an item not worn) how it compares with everything wearing
## it would take off. The comparison is shared with the details column.
## Set items list their set's bonuses (lit when worn enough); gear shows its
## talisman sockets; a talisman says what applying it does.

const WIDTH := 330.0
const ICON_SIZE := 52.0


static func build(item: ItemData, inventory: Inventory, loot: LootConfig) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size.x = WIDTH
	var color := loot.rarity_colors[item.rarity]
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.045, 0.04, 0.97)
	style.border_color = color
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override("separation", 10)
	box.add_child(head)
	var icon := ItemIcon.make(ItemIcon.glyph_for(item, loot), color)
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	head.add_child(icon)
	var names := VBoxContainer.new()
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(names)
	names.add_child(_label(item.display_name(), MenuWidgets.SMALL_FONT + 2, color))
	names.add_child(_label(describe_kind(item, loot), MenuWidgets.SMALL_FONT - 3,
			MenuWidgets.DIM_COLOR))
	for line in item.describe_lines():
		box.add_child(_label(line, MenuWidgets.SMALL_FONT - 1, MenuWidgets.TEXT_COLOR))
	add_set_lines(box, item, inventory, MenuWidgets.SMALL_FONT - 2)
	add_socket_line(box, item, loot, MenuWidgets.SMALL_FONT - 2)
	if item.is_talisman:
		box.add_child(_label("Select it, then apply it to worn gear. If it fails, the " +
				"talisman crumbles; the gear is never harmed.", MenuWidgets.SMALL_FONT - 3,
				MenuWidgets.DIM_COLOR))
	elif inventory.is_equipped(item):
		box.add_child(_label("Equipped: %s" % Inventory.EQUIP_NAMES[inventory.position_of(item)],
				MenuWidgets.SMALL_FONT - 2, MenuWidgets.TITLE_COLOR))
	else:
		box.add_child(HSeparator.new())
		add_comparison(box, item, inventory, loot, MenuWidgets.SMALL_FONT - 2)
	box.add_child(_label("Salvage: %d %s" % [Inventory.salvage_value(item, loot.salvage_stones),
			loot.currency_name], MenuWidgets.SMALL_FONT - 3, MenuWidgets.DIM_COLOR))
	_unwrap(box)
	return panel


## Turns wrapping off in the card: a wrapped label is measured before it has
## a width (one word per line), which stretched the card down the screen.
## Its lines are short, so the card just fits its text.
static func _unwrap(node: Node) -> void:
	for child in node.get_children():
		if child is Label:
			(child as Label).autowrap_mode = TextServer.AUTOWRAP_OFF
		_unwrap(child)


## "Rare Staff - two-handed - item lv 4".
static func describe_kind(item: ItemData, loot: LootConfig) -> String:
	var kind := loot.slot_names[item.slot]
	if item.is_talisman:
		return "%s %s   -   item lv %d" % [loot.rarity_names[item.rarity], loot.talisman_name,
				item.item_level]
	if item.kind >= 0 and item.kind < loot.item_kinds.size():
		kind = loot.item_kinds[item.kind].display_name
	var parts := PackedStringArray([loot.rarity_names[item.rarity] + " " + kind])
	if item.two_handed:
		parts.append("two-handed")
	elif item.slot == AffixDef.Slot.WEAPON:
		parts.append("one-handed")
	parts.append("item lv %d" % item.item_level)
	return "   -   ".join(parts)


## A set item's set: its name, pieces worn, and each bonus (lit once worn).
static func add_set_lines(parent: Container, item: ItemData, inventory: Inventory,
		font_size: int) -> void:
	if not item.is_set() or inventory.sets == null or item.set_id >= inventory.sets.sets.size():
		return
	var def := inventory.sets.sets[item.set_id]
	var worn := inventory.set_count(item.set_id)
	var green := Color(0.35, 0.95, 0.4)
	parent.add_child(_label("%s  (%d/%d worn)" % [def.set_name, worn, def.pieces.size()],
			font_size + 1, green))
	for k in def.bonus_stats.size():
		var active := worn >= def.bonus_pieces[k]
		parent.add_child(_label("  (%d) %s" % [def.bonus_pieces[k],
				PlayerStat.describe(def.bonus_stats[k], def.bonus_values[k])], font_size,
				green if active else MenuWidgets.DIM_COLOR))


## "Talisman sockets: 1 / 2 used" for gear that has sockets.
static func add_socket_line(parent: Container, item: ItemData, loot: LootConfig,
		font_size: int) -> void:
	var sockets := TalismanRules.sockets_of(loot, item)
	if sockets > 0:
		parent.add_child(_label("%s sockets: %d / %d used" % [loot.talisman_name,
				item.talisman_sockets_used, sockets], font_size, Color(0.95, 0.8, 0.5)))


## Lines comparing item with what wearing it (at its default position) would
## take off: green for gains, red for losses.
static func add_comparison(parent: Container, item: ItemData, inventory: Inventory,
		loot: LootConfig, font_size: int) -> void:
	var position := inventory.target_for(item)
	var replaced := inventory.displaced_by(item, position)
	if replaced.is_empty():
		parent.add_child(_label("Your %s is empty - all of this is a gain:" %
				Inventory.EQUIP_NAMES[position].to_lower(), font_size, MenuWidgets.DIM_COLOR))
	else:
		var names: PackedStringArray = []
		for other in replaced:
			names.append(other.display_name())
		parent.add_child(_label("Compared with your %s:" % " + ".join(names), font_size,
				MenuWidgets.DIM_COLOR))
	for row in ItemCompare.compare_against(item, replaced):
		var stat: int = row["stat"]
		var text := ""
		var color := MenuWidgets.TEXT_COLOR
		match row["change"]:
			ItemCompare.Change.BETTER:
				text = "%s   (%s)" % [PlayerStat.describe(stat, row["value"]),
						PlayerStat.describe_delta(stat, row["delta"])]
				color = MenuWidgets.GOOD_COLOR
			ItemCompare.Change.WORSE:
				text = "%s   (%s)" % [PlayerStat.describe(stat, row["value"]),
						PlayerStat.describe_delta(stat, row["delta"])]
				color = MenuWidgets.BAD_COLOR
			ItemCompare.Change.SAME:
				text = "%s   (same)" % PlayerStat.describe(stat, row["value"])
			ItemCompare.Change.GAINED:
				text = "%s   (new)" % PlayerStat.describe(stat, row["value"])
				color = MenuWidgets.GOOD_COLOR
			ItemCompare.Change.LOST:
				text = "loses %s" % PlayerStat.describe(stat, -float(row["delta"]))
				color = MenuWidgets.BAD_COLOR
		parent.add_child(_label("  " + text, font_size, color))


static func _label(text: String, font_size: int, color: Color) -> Label:
	var l := MenuWidgets.label(text, font_size, color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
