class_name SkillDef
extends Resource
## One passive skill. Each rank adds per_rank to its stat.

@export var display_name: String = "Skill"
@export var stat: PlayerStat.Id = PlayerStat.Id.MAX_HEALTH
@export var per_rank: float = 1.0
@export var max_rank: int = 5
