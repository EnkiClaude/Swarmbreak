class_name ActiveSkillList
extends Resource
## The active skills, in skill-button order (skill_1 .. skill_4).

@export var skills: Array[ActiveSkillDef] = []
## Skill points one grade costs.
@export var grade_cost: int = 1
