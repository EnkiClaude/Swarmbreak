class_name ActiveSkillDef
extends Resource
## One active skill on a skill button: what it does (kind), when it unlocks
## and how it grows with grades. Grade 1 is learned with a skill point at
## unlock_level; each further grade costs a point and needs grade_level_step
## more levels. Grades raise damage and radius and, every grades_per_count
## grades, the count (chain jumps, meteors, ...). class_tag is for a class
## system to come: which class may learn it ("any" for now).

enum Kind {
	CHAIN,    ## Lightning striking the enemies in a circle ahead.
	INFERNO,  ## Burning ground ahead that hurts what stands in it.
	METEOR,   ## Meteors falling ahead after a short warning.
	WHIRL,    ## A whirl of blades around the player for a while.
}

@export var display_name: String = "Skill"
@export_multiline var description: String = ""
@export var class_tag: String = "any"
@export var kind: Kind = Kind.CHAIN
@export var unlock_level: int = 5
@export var max_grade: int = 5
@export var grade_level_step: int = 5
@export var mana_cost: float = 20.0
@export var cooldown: float = 4.0
@export var damage: float = 30.0
## Each grade above 1 adds this fraction of damage, and of radius.
@export var damage_per_grade: float = 0.35
@export var radius: float = 4.0
@export var radius_per_grade: float = 0.08
## How far ahead of the player it lands (0: on the player).
@export var reach: float = 8.0
## Chain strikes, meteors, ...: count, plus one every grades_per_count grades.
@export var count: int = 1
@export var grades_per_count: int = 2
## Burning ground and whirls last this long, hurting every tick_interval.
@export var duration: float = 0.0
@export var tick_interval: float = 0.5
## Meteors land this long after the cast.
@export var delay: float = 0.0
@export var knockback: float = 4.0
## The stat that scales its damage (BOLT_DAMAGE or NOVA_DAMAGE).
@export var scaling_stat: PlayerStat.Id = PlayerStat.Id.NOVA_DAMAGE
@export var effect: EffectType
@export var hit_effect: EffectType
@export var color: Color = Color(1, 0.6, 0.2)
