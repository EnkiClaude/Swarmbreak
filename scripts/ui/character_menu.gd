class_name CharacterMenu
extends CanvasLayer
## The character screen: level and XP, skill points into passive skills,
## equipped items, the backpack (equip or discard) and stat totals.
## Toggled by the character_menu action (Tab/C/I, Start, touch CHAR); pauses
## the game while open. While open, touches act as mouse clicks so its
## buttons work on phones. It is small and the game is paused, so it simply
## rebuilds itself after every change.

signal opened
signal closed

const FONT_SIZE := 22
const SMALL_FONT := 17
const BUTTON_HEIGHT := 46.0
const PANEL_MARGIN := 40.0

var _progress: PlayerProgress
var _tree: SkillTree
var _inventory: Inventory
var _stats: PlayerStats
var _loot: LootConfig
var _panel: PanelContainer
var _content: VBoxContainer
var _selected := -1
var _focus_target: Control


func setup(progress: PlayerProgress, tree: SkillTree, inventory: Inventory, stats: PlayerStats,
		loot: LootConfig) -> void:
	_progress = progress
	_tree = tree
	_inventory = inventory
	_stats = stats
	_loot = loot
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 120
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.offset_left = PANEL_MARGIN
	_panel.offset_top = PANEL_MARGIN * 0.6
	_panel.offset_right = -PANEL_MARGIN
	_panel.offset_bottom = -PANEL_MARGIN * 0.6
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.09, 0.94)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(18)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 12)
	scroll.add_child(_content)
	visible = false


func is_open() -> bool:
	return visible


func open() -> void:
	if visible:
		return
	visible = true
	_selected = -1
	get_tree().paused = true
	Input.emulate_mouse_from_touch = true
	_rebuild()
	opened.emit()


func close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = false
	Input.emulate_mouse_from_touch = false
	closed.emit()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("character_menu") or (visible and event.is_action_pressed("ui_cancel")):
		toggle()
		get_viewport().set_input_as_handled()


func rank_up(skill: int) -> void:
	if _progress.rank_up(skill):
		_stats.recompute()
	_rebuild()


func equip(backpack_index: int) -> void:
	_inventory.equip(backpack_index)
	_selected = -1
	_rebuild()


func discard(backpack_index: int) -> void:
	_inventory.discard(backpack_index)
	_selected = -1
	_rebuild()


func _rebuild() -> void:
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_focus_target = null
	_build_header()
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 28)
	_content.add_child(columns)
	var left := _column(columns)
	var right := _column(columns)
	_build_skills(left)
	_build_totals(left)
	_build_equipment(right)
	_build_backpack(right)
	if _focus_target != null:
		_focus_target.grab_focus.call_deferred()


func _build_header() -> void:
	var row := HBoxContainer.new()
	_content.add_child(row)
	var xp := "MAX" if _progress.is_max_level() else "%d / %d" % [
			floori(_progress.xp), ceili(_progress.xp_to_next())]
	var title := _label("LEVEL %d     XP %s     Skill points: %d" % [
			_progress.level, xp, _progress.skill_points], FONT_SIZE + 4)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	var close_button := _button("CLOSE")
	close_button.pressed.connect(close)
	row.add_child(close_button)
	_focus_target = close_button


func _build_skills(parent: VBoxContainer) -> void:
	parent.add_child(_label("SKILLS", FONT_SIZE, Color(0.7, 0.8, 1.0)))
	for skill in _tree.skills.size():
		var def := _tree.skills[skill]
		var row := HBoxContainer.new()
		parent.add_child(row)
		var text := "%s   %d/%d\n%s per rank" % [def.display_name, _progress.ranks[skill],
				def.max_rank, PlayerStat.describe(def.stat, def.per_rank)]
		var label := _label(text, SMALL_FONT)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var plus := _button("+")
		plus.custom_minimum_size.x = BUTTON_HEIGHT * 1.4
		plus.disabled = not _progress.can_rank_up(skill)
		plus.pressed.connect(rank_up.bind(skill))
		row.add_child(plus)
		if not plus.disabled and _focus_target is Button and (_focus_target as Button).text == "CLOSE":
			_focus_target = plus


func _build_totals(parent: VBoxContainer) -> void:
	parent.add_child(_label("TOTALS", FONT_SIZE, Color(0.7, 0.8, 1.0)))
	var lines: PackedStringArray = []
	for stat in PlayerStat.COUNT:
		var v := _stats.value(stat)
		if absf(v) > 0.0001:
			lines.append(PlayerStat.describe(stat, v))
	parent.add_child(_label("\n".join(lines) if not lines.is_empty() else "Nothing yet",
			SMALL_FONT))


func _build_equipment(parent: VBoxContainer) -> void:
	parent.add_child(_label("EQUIPPED", FONT_SIZE, Color(0.7, 0.8, 1.0)))
	for slot in _inventory.equipped.size():
		var item := _inventory.equipped[slot]
		if item == null:
			parent.add_child(_label("%s: empty" % _loot.slot_names[slot], SMALL_FONT,
					Color(1, 1, 1, 0.5)))
			continue
		parent.add_child(_label(_item_title(item), SMALL_FONT + 1, _loot.rarity_colors[item.rarity]))
		parent.add_child(_label("   " + "\n   ".join(item.describe_lines()), SMALL_FONT))


func _build_backpack(parent: VBoxContainer) -> void:
	parent.add_child(_label("BACKPACK  %d/%d" % [_inventory.backpack.size(),
			_inventory.backpack_size], FONT_SIZE, Color(0.7, 0.8, 1.0)))
	if _inventory.backpack.is_empty():
		parent.add_child(_label("Empty. Clear camps to find loot.", SMALL_FONT, Color(1, 1, 1, 0.5)))
		return
	var grid := GridContainer.new()
	grid.columns = 2
	parent.add_child(grid)
	for index in _inventory.backpack.size():
		var item := _inventory.backpack[index]
		var button := _button(_item_title(item))
		button.add_theme_color_override("font_color", _loot.rarity_colors[item.rarity])
		button.toggle_mode = true
		button.button_pressed = index == _selected
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_select.bind(index))
		grid.add_child(button)
	if _selected >= 0 and _selected < _inventory.backpack.size():
		_build_selected(parent, _inventory.backpack[_selected])


func _build_selected(parent: VBoxContainer, item: ItemData) -> void:
	parent.add_child(_label(_item_title(item), SMALL_FONT + 1, _loot.rarity_colors[item.rarity]))
	parent.add_child(_label("   " + "\n   ".join(item.describe_lines()), SMALL_FONT))
	var current := _inventory.equipped[item.slot]
	if current != null:
		parent.add_child(_label("Replaces %s:\n   %s" % [current.item_name,
				"\n   ".join(current.describe_lines())], SMALL_FONT, Color(1, 1, 1, 0.6)))
	var row := HBoxContainer.new()
	parent.add_child(row)
	var equip_button := _button("EQUIP")
	equip_button.pressed.connect(equip.bind(_selected))
	row.add_child(equip_button)
	var discard_button := _button("DISCARD")
	discard_button.pressed.connect(discard.bind(_selected))
	row.add_child(discard_button)
	_focus_target = equip_button


func _select(index: int) -> void:
	_selected = -1 if _selected == index else index
	_rebuild()


func _item_title(item: ItemData) -> String:
	return "%s (%s %s)" % [item.item_name, _loot.rarity_names[item.rarity],
			_loot.slot_names[item.slot]]


func _column(parent: HBoxContainer) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	parent.add_child(column)
	return column


func _label(text: String, font_size: int, color: Color = Color(1, 1, 1, 0.92)) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
	button.add_theme_font_size_override("font_size", SMALL_FONT + 1)
	return button
