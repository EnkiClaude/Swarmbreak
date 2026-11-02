class_name MenuTheme
extends RefCounted
## The menus' look, as one Theme on the menu panel: dark buttons with a
## thin bronze edge that warms on hover, a bright gold focus ring (where the
## controller is), muted disabled buttons, light text and slim scroll bars.
## Item cards keep their rarity borders (MenuWidgets.style_item).

const TEXT := Color(0.92, 0.88, 0.8)
const EDGE := Color(0.38, 0.3, 0.2)
const EDGE_HOT := Color(0.78, 0.6, 0.32)
const FOCUS := Color(1.0, 0.8, 0.38)
const FACE := Color(0.1, 0.095, 0.09)
const PANEL := Color(0.035, 0.034, 0.042, 1.0)


static func build() -> Theme:
	var theme := Theme.new()
	theme.set_stylebox("normal", "Button", _box(FACE, EDGE, 1))
	theme.set_stylebox("hover", "Button", _box(FACE.lightened(0.07), EDGE_HOT, 1))
	theme.set_stylebox("pressed", "Button", _box(Color(0.24, 0.17, 0.08), FOCUS, 1))
	theme.set_stylebox("disabled", "Button", _box(Color(0.07, 0.07, 0.07, 0.8),
			Color(0.2, 0.2, 0.2), 1))
	theme.set_stylebox("focus", "Button", focus_ring())
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_focus_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", FOCUS)
	theme.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.3))
	theme.set_color("font_color", "Label", TEXT)
	var grabber := _box(EDGE, EDGE, 0)
	grabber.set_corner_radius_all(4)
	for bar in ["VScrollBar", "HScrollBar"]:
		theme.set_stylebox("scroll", bar, _box(Color(0, 0, 0, 0.25), Color(0, 0, 0, 0), 0))
		theme.set_stylebox("grabber", bar, grabber)
		theme.set_stylebox("grabber_highlight", bar, _box(EDGE_HOT, EDGE_HOT, 0))
		theme.set_stylebox("grabber_pressed", bar, _box(FOCUS, FOCUS, 0))
	theme.set_constant("separation", "HSeparator", 10)
	theme.set_stylebox("separator", "HSeparator", _line())
	return theme


## The menu's backdrop: near black with a bronze edge and a soft shadow.
static func panel_style() -> StyleBoxFlat:
	var style := _box(PANEL, EDGE, 2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(18)
	style.shadow_color = Color(0, 0, 0, 0.6)
	style.shadow_size = 14
	return style


## Drawn over a focused control: where the controller is.
static func focus_ring() -> StyleBoxFlat:
	var ring := StyleBoxFlat.new()
	ring.draw_center = false
	ring.border_color = FOCUS
	ring.set_border_width_all(2)
	ring.set_corner_radius_all(7)
	ring.set_expand_margin_all(2)
	return ring


static func _box(bg: Color, edge: Color, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = edge
	box.set_border_width_all(width)
	box.set_corner_radius_all(6)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	return box


static func _line() -> StyleBoxLine:
	var line := StyleBoxLine.new()
	line.color = Color(EDGE, 0.6)
	line.thickness = 1
	return line
