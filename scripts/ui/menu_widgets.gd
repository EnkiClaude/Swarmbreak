class_name MenuWidgets
extends RefCounted
## Shared building blocks for the character screen: labels, buttons, section
## titles and the rarity-bordered item style.

const FONT_SIZE := 22
const SMALL_FONT := 17
const BUTTON_HEIGHT := 46.0
const TITLE_COLOR := Color(0.7, 0.8, 1.0)
const TEXT_COLOR := Color(1, 1, 1, 0.92)
const DIM_COLOR := Color(1, 1, 1, 0.5)
const GOOD_COLOR := Color(0.55, 1.0, 0.5)
const BAD_COLOR := Color(1.0, 0.5, 0.42)
const CARD_COLOR := Color(0.12, 0.13, 0.16)


static func label(text: String, font_size: int = SMALL_FONT, color: Color = TEXT_COLOR) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func title(text: String) -> Label:
	return label(text, FONT_SIZE, TITLE_COLOR)


static func button(text: String, font_size: int = SMALL_FONT + 1) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
	b.add_theme_font_size_override("font_size", font_size)
	return b


static func column(parent: Container, min_width: float = 0.0) -> VBoxContainer:
	var c := VBoxContainer.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.custom_minimum_size.x = min_width
	c.add_theme_constant_override("separation", 8)
	parent.add_child(c)
	return c


## Dark card with a border in the item's rarity color; thicker and brighter
## when selected.
static func style_item(button: Button, rarity_color: Color, selected: bool) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = CARD_COLOR.lightened(0.12) if selected else CARD_COLOR
	normal.border_color = rarity_color if not selected else rarity_color.lightened(0.35)
	normal.set_border_width_all(4 if selected else 2)
	normal.set_corner_radius_all(6)
	normal.set_content_margin_all(6)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = normal.bg_color.lightened(0.08)
	for state in ["normal", "pressed"]:
		button.add_theme_stylebox_override(state, normal)
	for state in ["hover", "focus"]:
		button.add_theme_stylebox_override(state, hover)
	button.add_theme_color_override("font_color", rarity_color)
	button.add_theme_color_override("font_hover_color", rarity_color.lightened(0.2))
	button.add_theme_color_override("font_focus_color", rarity_color.lightened(0.2))
	button.add_theme_color_override("font_pressed_color", rarity_color)


## A faint card for an empty slot or backpack space.
static func empty_card(text: String, size: Vector2) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = size
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.03)
	style.border_color = Color(1, 1, 1, 0.12)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	card.add_theme_stylebox_override("panel", style)
	var l := label(text, SMALL_FONT - 2, Color(1, 1, 1, 0.25))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card.add_child(l)
	return card
