class_name Cooldown
extends RefCounted
## Counts down to ready. trigger() starts it again.

var duration: float
var remaining := 0.0


func _init(p_duration: float) -> void:
	duration = p_duration


func tick(delta: float) -> void:
	remaining = maxf(remaining - delta, 0.0)


func is_ready() -> bool:
	return remaining <= 0.0


func trigger() -> void:
	remaining = duration


## 0 right after trigger(), 1 when ready.
func progress() -> float:
	if duration <= 0.0:
		return 1.0
	return 1.0 - remaining / duration
