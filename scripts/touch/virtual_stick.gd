class_name VirtualStick
extends RefCounted
## A floating thumbstick: it centers wherever the touch lands, and dragging
## up to radius away gives full deflection. Tracks one touch index at a time.

var radius: float
## Touch index holding the stick, or -1 when released.
var touch_index := -1
var origin := Vector2.ZERO
## Screen-space deflection: x right, y down, length <= 1.
var vector := Vector2.ZERO


func _init(p_radius: float) -> void:
	radius = p_radius


func is_held() -> bool:
	return touch_index >= 0


func press(index: int, at: Vector2) -> void:
	touch_index = index
	origin = at
	vector = Vector2.ZERO


func drag(at: Vector2) -> void:
	vector = ((at - origin) / radius).limit_length(1.0)


func release() -> void:
	touch_index = -1
	vector = Vector2.ZERO
