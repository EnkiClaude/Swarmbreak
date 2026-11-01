class_name QuestDef
extends Resource
## One quest: what to do, how many times, and what it gives.

enum Goal { CLEAR_CAMPS }
enum Reward { EGG_CHOICE }

@export var title: String = "Quest"
@export_multiline var description: String = ""
@export var goal: Goal = Goal.CLEAR_CAMPS
@export var target: int = 5
@export var reward: Reward = Reward.EGG_CHOICE
