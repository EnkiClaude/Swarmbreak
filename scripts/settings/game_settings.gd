class_name GameSettings
extends RefCounted
## Player preferences kept with the save: the HUD's scale. changed fires
## when one changes, so the HUD applies it and the save is written.

signal changed

## HUD scales the settings page offers.
const HUD_SCALES: PackedFloat32Array = [0.75, 0.9, 1.0, 1.15, 1.3, 1.5]

var hud_scale := 1.0


func set_hud_scale(value: float) -> void:
	value = clampf(value, HUD_SCALES[0], HUD_SCALES[HUD_SCALES.size() - 1])
	if is_equal_approx(value, hud_scale):
		return
	hud_scale = value
	changed.emit()


func to_dict() -> Dictionary:
	return {"hud_scale": hud_scale}


## Tolerant: missing or bad values keep the defaults.
func from_dict(data: Variant) -> void:
	if not data is Dictionary:
		return
	var scale: Variant = (data as Dictionary).get("hud_scale", hud_scale)
	if scale is float or scale is int:
		hud_scale = clampf(float(scale), HUD_SCALES[0], HUD_SCALES[HUD_SCALES.size() - 1])
