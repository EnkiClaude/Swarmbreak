class_name CharacterMenu
extends CanvasLayer
## The character screen: level and XP, the job path, skill points into
## passive skills, equipped items and the backpack (equip, salvage, refine)
## and stat totals.
## Toggled by the character_menu action (Tab/C/I, Start, touch CHAR); pauses
## the game while open. While open, touches act as mouse clicks so its
## buttons work on phones. It is small and the game is paused, so it simply
## rebuilds itself after every change.

signal opened
signal closed
signal job_chosen(job: int)
signal refined(result: Refinery.Result, item: ItemData)

const FONT_SIZE := 22
const SMALL_FONT := 17
const BUTTON_HEIGHT := 46.0
const PANEL_MARGIN := 40.0

var _progress: PlayerProgress
var _tree: SkillTree
var _inventory: Inventory
var _stats: PlayerStats
var _loot: LootConfig
var _jobs: JobTree
var _refinery: Refinery
var _panel: PanelContainer
var _content: VBoxContainer
## Selected backpack item, or -1.
var _selected := -1
## Selected equipped slot, or -1.
var _selected_slot := -1
## Result of the last refine, shown under the item.
var _refine_text := ""
var _refine_color := Color.WHITE
var _focus_target: Control


func setup(progress: PlayerProgress, tree: SkillTree, inventory: Inventory, stats: PlayerStats,
		loot: LootConfig, jobs: JobTree = null, refinery: Refinery = null) -> void:
	_progress = progress
	_jobs = jobs
	_refinery = refinery
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
	_selected_slot = -1
	_refine_text = ""
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


func salvage(backpack_index: int) -> void:
	var gained := _inventory.salvage(backpack_index, _loot.salvage_stones)
	_selected = -1
	_refine_text = "Salvaged for %d stones" % gained
	_refine_color = Color(0.8, 0.85, 1.0)
	_rebuild()


func choose_job(index: int) -> void:
	if _jobs != null and _progress.choose_job(_jobs, index):
		_stats.recompute()
		job_chosen.emit(index)
	_rebuild()


## Tries to refine an item (one click of UPGRADE).
func refine(item: ItemData) -> Refinery.Result:
	var before := item.upgrade_level
	var result := _refinery.attempt(item, _inventory)
	match result:
		Refinery.Result.SUCCESS:
			_refine_text = "SUCCESS! +%d -> +%d" % [before, item.upgrade_level]
			_refine_color = Color(0.6, 1.0, 0.5)
		Refinery.Result.DOWNGRADED:
			_refine_text = "Failed - dropped to +%d. Try again!" % item.upgrade_level
			_refine_color = Color(1.0, 0.5, 0.4)
		Refinery.Result.FAILED:
			_refine_text = "Failed - still +0. Try again!"
			_refine_color = Color(1.0, 0.5, 0.4)
		Refinery.Result.NOT_ENOUGH_STONES:
			_refine_text = "Not enough stones"
			_refine_color = Color(1.0, 0.7, 0.3)
		Refinery.Result.MAXED:
			_refine_text = "Already at the maximum"
			_refine_color = Color(1.0, 0.85, 0.3)
	refined.emit(result, item)
	_rebuild()
	return result


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
	_build_job(left)
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
	var job := ""
	if _jobs != null and _progress.job >= 0:
		job = "%s     " % _progress.job_title(_jobs)
	var title := _label("%sLEVEL %d     XP %s     Skill points: %d     Stones: %d" % [
			job, _progress.level, xp, _progress.skill_points, _inventory.stones], FONT_SIZE + 2)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	var close_button := _button("CLOSE")
	close_button.pressed.connect(close)
	row.add_child(close_button)
	_focus_target = close_button


func _build_job(parent: VBoxContainer) -> void:
	if _jobs == null:
		return
	parent.add_child(_label("PATH", FONT_SIZE, Color(0.7, 0.8, 1.0)))
	if _progress.job >= 0:
		var def := _jobs.jobs[_progress.job]
		var promoted := _progress.job_rank >= 2
		parent.add_child(_label(_progress.job_title(_jobs), SMALL_FONT + 2, def.color))
		parent.add_child(_label(def.rank2_description if promoted else def.description, SMALL_FONT))
		if not promoted:
			parent.add_child(_label("Promotes to %s at level %d" % [def.rank2_name,
					_jobs.rank2_level], SMALL_FONT, Color(1, 1, 1, 0.55)))
		return
	if not _progress.can_choose_job(_jobs):
		parent.add_child(_label("Choose a path at level %d" % _jobs.unlock_level, SMALL_FONT,
				Color(1, 1, 1, 0.55)))
		return
	parent.add_child(_label("Choose your path (permanent):", SMALL_FONT, Color(1.0, 0.85, 0.35)))
	for index in _jobs.jobs.size():
		var def := _jobs.jobs[index]
		var button := _button(def.display_name.to_upper())
		button.add_theme_color_override("font_color", def.color)
		button.pressed.connect(choose_job.bind(index))
		parent.add_child(button)
		parent.add_child(_label(def.description, SMALL_FONT))
		if index == 0:
			_focus_target = button


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
		_style_plus(plus)
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
		var button := _button(_item_title(item))
		button.add_theme_color_override("font_color", _loot.rarity_colors[item.rarity])
		button.toggle_mode = true
		button.button_pressed = slot == _selected_slot
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_select_equipped.bind(slot))
		parent.add_child(button)
		parent.add_child(_label("   " + "\n   ".join(item.describe_lines()), SMALL_FONT))
		if slot == _selected_slot:
			_build_refine(parent, item)


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
	var salvage_button := _button("SALVAGE (+%d stones)" % (
			_loot.salvage_stones[mini(item.rarity, _loot.salvage_stones.size() - 1)]
			+ item.upgrade_level))
	salvage_button.pressed.connect(salvage.bind(_selected))
	row.add_child(salvage_button)
	_focus_target = equip_button
	_build_refine(parent, item)


func _build_refine(parent: VBoxContainer, item: ItemData) -> void:
	if _refinery == null:
		return
	if _refinery.is_maxed(item):
		parent.add_child(_label("Fully refined (+%d)" % item.upgrade_level, SMALL_FONT,
				Color(1.0, 0.85, 0.3)))
	else:
		var cost := _refinery.cost_for(item)
		var chance := roundi(_refinery.chance_for(item) * 100.0)
		var button := _button("UPGRADE +%d -> +%d   %d%%   cost %d stones" % [
				item.upgrade_level, item.upgrade_level + 1, chance, cost])
		button.disabled = _inventory.stones < cost
		button.pressed.connect(refine.bind(item))
		parent.add_child(button)
		var note := "Fails drop it one level; it never breaks."
		if item.fail_streak > 0:
			note += " Luck builds: +%d%% from %d failures." % [
					roundi(item.fail_streak * _loot.upgrade_pity_per_fail * 100.0), item.fail_streak]
		parent.add_child(_label(note, SMALL_FONT - 1, Color(1, 1, 1, 0.55)))
		if not button.disabled:
			_focus_target = button
	if _refine_text != "":
		parent.add_child(_label(_refine_text, SMALL_FONT + 1, _refine_color))


## "+" buttons get a solid look: dim when no point can go there, gold when one can.
func _style_plus(button: Button) -> void:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(6)
	style.bg_color = Color(0.2, 0.22, 0.26) if button.disabled else Color(0.85, 0.65, 0.2)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("disabled", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = hover.bg_color.lightened(0.2)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.35))
	button.add_theme_color_override("font_color", Color(0.1, 0.08, 0.02))


func _select(index: int) -> void:
	_selected = -1 if _selected == index else index
	_selected_slot = -1
	_refine_text = ""
	_rebuild()


func _select_equipped(slot: int) -> void:
	_selected_slot = -1 if _selected_slot == slot else slot
	_selected = -1
	_refine_text = ""
	_rebuild()


func _item_title(item: ItemData) -> String:
	return "%s (%s %s)" % [item.display_name(), _loot.rarity_names[item.rarity],
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
