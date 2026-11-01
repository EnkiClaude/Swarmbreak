class_name CharacterPage
extends RefCounted
## The CHARACTER tab: job path and skills on the left; attributes (spend
## points with + and +5), stat totals and New Game on the right.

const PLUS_WIDTH := 64.0

var _menu: CharacterMenu
var _progress: PlayerProgress
var _tree: SkillTree
var _stats: PlayerStats
var _jobs: JobTree


func _init(menu: CharacterMenu, progress: PlayerProgress, tree: SkillTree, stats: PlayerStats,
		jobs: JobTree) -> void:
	_menu = menu
	_progress = progress
	_tree = tree
	_stats = stats
	_jobs = jobs


## Builds into parent and returns the control that should take focus.
func build(parent: Container, confirm_new_game: bool) -> Control:
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 28)
	parent.add_child(columns)
	var left := MenuWidgets.column(columns)
	var right := MenuWidgets.column(columns)
	var focus := _build_job(left)
	var plus := _build_skills(left)
	var raise := _build_attributes(right)
	_build_totals(right)
	_build_new_game(right, confirm_new_game)
	if focus != null:
		return focus
	return raise if raise != null else plus


func _build_job(parent: VBoxContainer) -> Control:
	if _jobs == null:
		return null
	parent.add_child(MenuWidgets.title("PATH"))
	if _progress.job >= 0:
		var def := _jobs.jobs[_progress.job]
		var promoted := _progress.job_rank >= 2
		parent.add_child(MenuWidgets.label(_progress.job_title(_jobs), MenuWidgets.SMALL_FONT + 2,
				def.color))
		parent.add_child(MenuWidgets.label(def.rank2_description if promoted else def.description))
		if not promoted:
			parent.add_child(MenuWidgets.label("Promotes to %s at level %d" % [def.rank2_name,
					_jobs.rank2_level], MenuWidgets.SMALL_FONT, MenuWidgets.DIM_COLOR))
		return null
	if not _progress.can_choose_job(_jobs):
		parent.add_child(MenuWidgets.label("Choose a path at level %d" % _jobs.unlock_level,
				MenuWidgets.SMALL_FONT, MenuWidgets.DIM_COLOR))
		return null
	parent.add_child(MenuWidgets.label("Choose your path (permanent):", MenuWidgets.SMALL_FONT,
			Color(1.0, 0.85, 0.35)))
	var first: Control = null
	for index in _jobs.jobs.size():
		var def := _jobs.jobs[index]
		var b := MenuWidgets.button(def.display_name.to_upper())
		b.add_theme_color_override("font_color", def.color)
		b.pressed.connect(_menu.choose_job.bind(index))
		parent.add_child(b)
		parent.add_child(MenuWidgets.label(def.description))
		if first == null:
			first = b
	return first


func _build_skills(parent: VBoxContainer) -> Control:
	parent.add_child(MenuWidgets.title("SKILLS   (%d point%s)" % [_progress.skill_points,
			"" if _progress.skill_points == 1 else "s"]))
	var first: Control = null
	for skill in _tree.skills.size():
		var def := _tree.skills[skill]
		var row := HBoxContainer.new()
		parent.add_child(row)
		var text := "%s   %d/%d\n%s per rank" % [def.display_name, _progress.ranks[skill],
				def.max_rank, PlayerStat.describe(def.stat, def.per_rank)]
		var l := MenuWidgets.label(text)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var plus := MenuWidgets.button("+")
		plus.custom_minimum_size.x = PLUS_WIDTH
		plus.disabled = not _progress.can_rank_up(skill)
		_style_plus(plus)
		plus.pressed.connect(_menu.rank_up.bind(skill))
		row.add_child(plus)
		if first == null and not plus.disabled:
			first = plus
	return first


func _build_attributes(parent: VBoxContainer) -> Control:
	var table := _progress.attribute_table
	if table == null:
		return null
	var points := _progress.attribute_points
	parent.add_child(MenuWidgets.title("ATTRIBUTES   (%d point%s)" % [points,
			"" if points == 1 else "s"]))
	var first: Control = null
	for a in table.attributes.size():
		var def := table.attributes[a]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		parent.add_child(row)
		var effects: PackedStringArray = []
		for k in def.stats.size():
			effects.append(PlayerStat.describe(def.stats[k], def.per_point[k]))
		var text := "%s  %s   %d\n%s per point" % [def.short_name, def.display_name,
				_progress.attributes[a], ", ".join(effects)]
		var l := MenuWidgets.label(text, MenuWidgets.SMALL_FONT, def.color)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.tooltip_text = def.description
		row.add_child(l)
		for amount: int in [1, 5]:
			var b := MenuWidgets.button("+" if amount == 1 else "+5")
			b.custom_minimum_size.x = PLUS_WIDTH
			b.disabled = points <= 0
			_style_plus(b)
			b.pressed.connect(_menu.raise_attribute.bind(a, amount))
			row.add_child(b)
			if first == null and not b.disabled:
				first = b
	return first


func _build_totals(parent: VBoxContainer) -> void:
	parent.add_child(MenuWidgets.title("TOTALS"))
	var lines: PackedStringArray = []
	for stat in PlayerStat.COUNT:
		var v := _stats.value(stat)
		if absf(v) > 0.0001:
			lines.append(PlayerStat.describe(stat, v))
	parent.add_child(MenuWidgets.label("\n".join(lines) if not lines.is_empty() else "Nothing yet"))


func _build_new_game(parent: VBoxContainer, confirm: bool) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 24.0
	parent.add_child(spacer)
	var b := MenuWidgets.button("TAP AGAIN TO ERASE YOUR SAVE" if confirm else "NEW GAME")
	b.add_theme_color_override("font_color", MenuWidgets.BAD_COLOR if confirm
			else MenuWidgets.DIM_COLOR)
	b.pressed.connect(_menu.press_new_game)
	parent.add_child(b)


## "+" buttons get a solid look: dim when no point can go there, gold when one can.
func _style_plus(b: Button) -> void:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(6)
	style.bg_color = Color(0.2, 0.22, 0.26) if b.disabled else Color(0.85, 0.65, 0.2)
	b.add_theme_stylebox_override("normal", style)
	b.add_theme_stylebox_override("disabled", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = hover.bg_color.lightened(0.2)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.35))
	b.add_theme_color_override("font_color", Color(0.1, 0.08, 0.02))
