class_name ActiveSkills
extends RefCounted
## The active skills on the skill buttons (skill_1 .. skill_4, in
## ActiveSkillList order): cooldowns, mana, and what each kind does once
## learned (PlayerProgress.active_grades). Burning ground, whirls and falling
## meteors are "zones" in fixed arrays, ticked here; all damage goes
## through SwarmManager.damage_circle(), so tick() must run between
## simulate() and resolve_deaths(). Emits cast and impact for
## CombatFeedback.

signal cast(skill: int, center: Vector2)
## A blow landed (a meteor, a tick of fire): feedback scales with it.
signal impact(skill: int, center: Vector2, big: bool)
## A skill was pressed but isn't learned yet.
signal locked(skill: int)

const ACTIONS: PackedStringArray = ["skill_1", "skill_2", "skill_3", "skill_4"]
const MAX_ZONES := 12

var cooldowns: Array[Cooldown] = []
var list: ActiveSkillList

var _player: Player
var _swarm: SwarmManager
var _effects: EffectSystem
var _progress: PlayerProgress
var _stats: PlayerStats
var _effect_ids := PackedInt32Array()
var _hit_ids := PackedInt32Array()
var _rng := RandomNumberGenerator.new()
# Zones: which skill, center, radius, damage per hit, when the next hit is
# due, when it ends, and whether it follows the player.
var _zone_skill := PackedInt32Array()
var _zone_center := PackedVector2Array()
var _zone_radius := PackedFloat32Array()
var _zone_damage := PackedFloat32Array()
var _zone_next := PackedFloat32Array()
var _zone_end := PackedFloat32Array()
var _zone_follow := PackedByteArray()
var _zone_count := 0


func _init(p_list: ActiveSkillList, player: Player, swarm: SwarmManager, effects: EffectSystem,
		progress: PlayerProgress, stats: PlayerStats) -> void:
	list = p_list
	_player = player
	_swarm = swarm
	_effects = effects
	_progress = progress
	_stats = stats
	for def in list.skills:
		cooldowns.append(Cooldown.new(def.cooldown))
		_effect_ids.append(effects.register(def.effect) if def.effect != null else -1)
		_hit_ids.append(effects.register(def.hit_effect) if def.hit_effect != null else -1)
	_zone_skill.resize(MAX_ZONES)
	_zone_center.resize(MAX_ZONES)
	_zone_radius.resize(MAX_ZONES)
	_zone_damage.resize(MAX_ZONES)
	_zone_next.resize(MAX_ZONES)
	_zone_end.resize(MAX_ZONES)
	_zone_follow.resize(MAX_ZONES)


## Call between SwarmManager.simulate() and resolve_deaths().
func tick(delta: float) -> void:
	for k in cooldowns.size():
		cooldowns[k].tick(delta)
	for k in mini(list.skills.size(), ACTIONS.size()):
		if Input.is_action_just_pressed(ACTIONS[k]):
			try_cast(k)
	_run_zones()


func grade(skill: int) -> int:
	return _progress.active_grade(skill)


func damage_for(skill: int) -> float:
	var def := list.skills[skill]
	var g := maxi(grade(skill), 1)
	var mult := _stats.multiplier(def.scaling_stat) if _stats != null else 1.0
	return def.damage * (1.0 + def.damage_per_grade * (g - 1)) * mult


func radius_for(skill: int) -> float:
	var def := list.skills[skill]
	return def.radius * (1.0 + def.radius_per_grade * (maxi(grade(skill), 1) - 1))


func count_for(skill: int) -> int:
	var def := list.skills[skill]
	return def.count + floori(float(maxi(grade(skill), 1) - 1) / maxi(def.grades_per_count, 1))


func duration_for(skill: int) -> float:
	return list.skills[skill].duration * (1.0 + 0.15 * (maxi(grade(skill), 1) - 1))


## True if the skill is learned, off cooldown and affordable.
func is_ready(skill: int) -> bool:
	return grade(skill) > 0 and cooldowns[skill].is_ready() \
			and _player.vitals.mana >= list.skills[skill].mana_cost


## Casts a skill if it's learned, ready and there's mana. Returns true if it did.
func try_cast(skill: int) -> bool:
	if grade(skill) <= 0:
		locked.emit(skill)
		return false
	if not cooldowns[skill].is_ready():
		return false
	var def := list.skills[skill]
	if not _player.vitals.spend_mana(def.mana_cost):
		return false
	cooldowns[skill].trigger()
	_player.face_aim()
	var aim := _player.aim_direction
	var center := _player.ground_position() + Vector2(aim.x, aim.z) * def.reach
	var now := _swarm.now()
	match def.kind:
		ActiveSkillDef.Kind.CHAIN:
			_chain(skill, center)
		ActiveSkillDef.Kind.INFERNO:
			_add_zone(skill, center, radius_for(skill), damage_for(skill), now,
					now + duration_for(skill), false)
		ActiveSkillDef.Kind.METEOR:
			var radius := radius_for(skill)
			for n in count_for(skill):
				var at := center
				if n > 0:
					at += Vector2.from_angle(_rng.randf() * TAU) * radius * (0.6 + 0.6 * _rng.randf())
				var due := now + def.delay + n * 0.18
				# A zone that hits once, when its meteor lands.
				_add_zone(skill, at, radius, damage_for(skill), due, due, false)
				_spawn(_effect_ids[skill], at, radius)
		ActiveSkillDef.Kind.WHIRL:
			_add_zone(skill, _player.ground_position(), radius_for(skill), damage_for(skill),
					now, now + duration_for(skill), true)
	cast.emit(skill, center)
	return true


func _chain(skill: int, center: Vector2) -> void:
	var radius := radius_for(skill)
	var def := list.skills[skill]
	_swarm.damage_circle(center, radius, damage_for(skill), def.knockback)
	_spawn(_effect_ids[skill], center, radius * 0.5)
	var hits := _swarm.hit_positions()
	var strikes := mini(_swarm.hit_sample_count(), count_for(skill))
	for k in strikes:
		_spawn(_hit_ids[skill], hits[k], 1.0)
	impact.emit(skill, center, false)


func _add_zone(skill: int, center: Vector2, radius: float, damage: float, first: float,
		end: float, follow: bool) -> void:
	if _zone_count >= MAX_ZONES:
		return
	var z := _zone_count
	_zone_skill[z] = skill
	_zone_center[z] = center
	_zone_radius[z] = radius
	_zone_damage[z] = damage
	_zone_next[z] = first
	_zone_end[z] = end
	_zone_follow[z] = 1 if follow else 0
	_zone_count += 1


func _run_zones() -> void:
	var now := _swarm.now()
	for z in range(_zone_count - 1, -1, -1):
		var skill := _zone_skill[z]
		var def := list.skills[skill]
		if _zone_follow[z] != 0:
			_zone_center[z] = _player.ground_position()
		if now >= _zone_next[z]:
			var center := _zone_center[z]
			var radius := _zone_radius[z]
			_swarm.damage_circle(center, radius, _zone_damage[z], def.knockback)
			var big := def.kind == ActiveSkillDef.Kind.METEOR
			_spawn(_hit_ids[skill] if big else _effect_ids[skill], center, radius)
			if big:
				var hits := _swarm.hit_positions()
				for k in mini(_swarm.hit_sample_count(), 4):
					_spawn(_hit_ids[skill], hits[k], 0.35)
			impact.emit(skill, center, big)
			_zone_next[z] = now + maxf(def.tick_interval, 0.05)
		if now >= _zone_end[z]:
			_remove_zone(z)


func _remove_zone(z: int) -> void:
	var last := _zone_count - 1
	_zone_skill[z] = _zone_skill[last]
	_zone_center[z] = _zone_center[last]
	_zone_radius[z] = _zone_radius[last]
	_zone_damage[z] = _zone_damage[last]
	_zone_next[z] = _zone_next[last]
	_zone_end[z] = _zone_end[last]
	_zone_follow[z] = _zone_follow[last]
	_zone_count = last


func _spawn(effect: int, at: Vector2, size: float) -> void:
	if effect >= 0:
		_effects.spawn(effect, Vector3(at.x, 0.0, at.y), size)


## Burning ground, whirls and meteors still pending (for tests).
func active_zones() -> int:
	return _zone_count


## Ends every zone (travel, death).
func clear() -> void:
	_zone_count = 0
