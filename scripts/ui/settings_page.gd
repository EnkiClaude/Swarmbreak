class_name SettingsPage
extends RefCounted
## The SETTINGS tab: HUD scale (saved with the character) on the left, and
## every control on the right, controller and keyboard side by side.

const SCALE_BUTTON_WIDTH := 90.0
## Action, controller, keyboard / mouse: what the controls page lists.
const CONTROLS: Array = [
	["Move", "Left stick", "WASD / arrows"],
	["Turn camera", "Right stick", "Mouse (click, Esc frees)"],
	["Fire bolts", "X or RT (hold)", "Left mouse (hold)"],
	["Frost Nova", "RB", "Q / right mouse"],
	["Lure", "LB", "E"],
	["Dodge", "LT", "Space / Shift"],
	["Active skill 1", "A", "1"],
	["Active skill 2", "B", "2"],
	["Active skill 3", "D-pad left", "3"],
	["Active skill 4", "D-pad right", "4"],
	["Character screen", "Start", "Tab / C"],
	["Inventory", "Y", "I"],
	["Switch menu tab", "LB / RB", "Q / E"],
	["Menu: select", "A", "Enter / click"],
	["Menu: back / close", "B", "Esc"],
	["Menu: move", "D-pad / left stick", "Arrows"],
	["Wear / take off", "A twice", "Double-click"],
	["Zoom camera", "D-pad up / down", "Mouse wheel"],
	["Zoom steps", "R3", "Z"],
	["Debug overlay", "L3", "F3"],
	["Spawn 100 (test)", "View / Back", "= / keypad +"],
]

var _menu: CharacterMenu
var _settings: GameSettings


func _init(menu: CharacterMenu, settings: GameSettings) -> void:
	_menu = menu
	_settings = settings


## Builds into parent and returns the control that should take focus.
func build(parent: Container) -> Control:
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 32)
	parent.add_child(columns)
	var left := MenuWidgets.column(columns, 300.0)
	var right := MenuWidgets.column(columns)
	var focus := _build_hud(left)
	_build_controls(right)
	return focus


func _build_hud(parent: VBoxContainer) -> Control:
	parent.add_child(MenuWidgets.title("HUD SCALE"))
	parent.add_child(MenuWidgets.label("How big the health and mana bars, minimap and skill " +
			"buttons are drawn.", MenuWidgets.SMALL_FONT - 2, MenuWidgets.DIM_COLOR))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	parent.add_child(grid)
	var current: Control = null
	for value in GameSettings.HUD_SCALES:
		var b := MenuWidgets.button("%d%%" % roundi(value * 100.0))
		b.custom_minimum_size.x = SCALE_BUTTON_WIDTH
		b.toggle_mode = true
		b.button_pressed = is_equal_approx(value, _settings.hud_scale)
		b.pressed.connect(_menu.set_hud_scale.bind(value))
		grid.add_child(b)
		if b.button_pressed:
			current = b
	return current


func _build_controls(parent: VBoxContainer) -> void:
	parent.add_child(MenuWidgets.title("CONTROLS"))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 2)
	parent.add_child(grid)
	for heading in ["ACTION", "CONTROLLER", "KEYBOARD / MOUSE"]:
		grid.add_child(_cell(heading, MenuWidgets.TITLE_COLOR))
	for row: Array in CONTROLS:
		grid.add_child(_cell(row[0], MenuWidgets.TEXT_COLOR))
		grid.add_child(_cell(row[1], Color(1.0, 0.85, 0.5)))
		grid.add_child(_cell(row[2], MenuWidgets.DIM_COLOR))


## One table cell on a single line. Wrapping labels have no minimum width,
## so in a grid they squeeze into a column a word wide.
static func _cell(text: String, color: Color) -> Label:
	var l := MenuWidgets.label(text, MenuWidgets.SMALL_FONT - 2, color)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	return l
