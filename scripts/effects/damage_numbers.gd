class_name DamageNumbers
extends Node3D
## Floating damage numbers: a fixed pool of Label3D nodes made at setup and
## reused, never created or freed during combat. Listens to
## SwarmManager.enemies_hit and shows up to per_blow numbers per blow, which
## float up, pop in and fade out. swarm may be null (tests).

var config: DamageNumbersConfig
var _labels: Array[Label3D] = []
var _ages := PackedFloat32Array()
var _scales := PackedFloat32Array()
var _rng := RandomNumberGenerator.new()
## Next label to reuse when every label is busy: the oldest one.
var _next := 0
var _clock := 0.0
var _evade_ready_at := 0.0


func setup(p_config: DamageNumbersConfig, swarm: SwarmManager) -> void:
	config = p_config
	for k in config.capacity:
		var label := Label3D.new()
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.shaded = false
		label.double_sided = true
		label.font_size = config.font_size
		label.outline_size = config.outline_size
		label.outline_modulate = config.outline_color
		label.pixel_size = config.pixel_size
		label.visible = false
		add_child(label)
		_labels.append(label)
	_ages.resize(config.capacity)
	_ages.fill(config.lifetime)
	_scales.resize(config.capacity)
	_scales.fill(1.0)
	if swarm != null:
		swarm.enemies_hit.connect(_on_enemies_hit)


func _on_enemies_hit(positions: PackedVector2Array, amounts: PackedFloat32Array, count: int) -> void:
	for k in mini(count, config.per_blow):
		show_number(positions[k], amounts[k])


## Shows one number above ground position at.
func show_number(at: Vector2, amount: float) -> void:
	var big := amount >= config.big_damage
	show_text(at, str(roundi(amount)), config.big_color if big else config.color,
			config.big_scale if big else 1.0)


## Shows the evade word over the player, at most once per evade_interval.
func show_evade(at: Vector2) -> void:
	if _evade_ready_at > _clock:
		return
	_evade_ready_at = _clock + config.evade_interval
	show_text(at, config.evade_text, config.evade_color, 1.1, 0.0)


## A word or number floating up from ground position at. A scatter of 0
## (words over the player) also starts it a little higher.
func show_text(at: Vector2, text: String, color: Color, size_scale: float,
		scatter: float = -1.0) -> void:
	var spread := config.scatter if scatter < 0.0 else scatter
	var lift := 0.6 if scatter >= 0.0 else 0.0
	var slot := _free_slot()
	var label := _labels[slot]
	label.text = text
	label.modulate = color
	label.position = Vector3(at.x + _rng.randf_range(-spread, spread), config.start_height + lift,
			at.y + _rng.randf_range(-spread, spread))
	label.visible = true
	_ages[slot] = 0.0
	_scales[slot] = size_scale


func tick(delta: float) -> void:
	_clock += delta
	var lifetime := config.lifetime
	for k in _labels.size():
		var age := _ages[k]
		if age >= lifetime:
			continue
		age += delta
		_ages[k] = age
		var label := _labels[k]
		if age >= lifetime:
			label.visible = false
			continue
		var t := age / lifetime
		label.position.y += config.rise_speed * delta
		# Pop in large, settle, then fade out over the last half.
		label.scale = Vector3.ONE * _scales[k] * (1.0 + 0.6 * maxf(0.0, 1.0 - t * 6.0))
		label.modulate.a = clampf(2.0 - t * 2.0, 0.0, 1.0)
		label.outline_modulate.a = label.modulate.a


func active_count() -> int:
	var total := 0
	for age in _ages:
		if age < config.lifetime:
			total += 1
	return total


func _free_slot() -> int:
	for k in _labels.size():
		if _ages[k] >= config.lifetime:
			return k
	var slot := _next
	_next = (_next + 1) % _labels.size()
	return slot
