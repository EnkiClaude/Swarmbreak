class_name SaveConfig
extends Resource
## Where and how often the game saves.

@export var path: String = "user://swarmbreak_save.json"
## After something worth saving changes, write this many seconds later, so a
## burst of changes becomes one write.
@export var autosave_delay: float = 1.5
## Safety-net save this often while playing, so XP isn't lost.
@export var periodic_save_interval: float = 30.0
