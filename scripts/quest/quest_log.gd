class_name QuestLog
extends RefCounted
## Progress on every quest in a QuestList: active, done (reward waiting) or
## claimed. Quests run one after another; the first unclaimed one is current.

signal completed(quest: int)
signal changed

enum State { ACTIVE, DONE, CLAIMED }

var list: QuestList
var progress := PackedInt32Array()
var states := PackedInt32Array()


func _init(p_list: QuestList) -> void:
	list = p_list
	progress.resize(list.quests.size())
	states.resize(list.quests.size())
	reset()


func reset() -> void:
	progress.fill(0)
	states.fill(State.ACTIVE)
	changed.emit()


## The first quest not yet claimed, or -1 when all are done.
func current() -> int:
	for q in states.size():
		if states[q] != State.CLAIMED:
			return q
	return -1


## A camp was cleared: counts toward the current quest if it wants that.
func on_camp_cleared() -> void:
	var q := current()
	if q < 0 or states[q] != State.ACTIVE or list.quests[q].goal != QuestDef.Goal.CLEAR_CAMPS:
		return
	progress[q] += 1
	if progress[q] >= list.quests[q].target:
		progress[q] = list.quests[q].target
		states[q] = State.DONE
		completed.emit(q)
	changed.emit()


## True when quest q is done and its reward not yet taken.
func reward_waiting(q: int) -> bool:
	return q >= 0 and q < states.size() and states[q] == State.DONE


func claim(q: int) -> bool:
	if not reward_waiting(q):
		return false
	states[q] = State.CLAIMED
	changed.emit()
	return true


## The quest's line for the HUD: "Title  3/5", or what to do now.
func summary(q: int) -> String:
	if q < 0:
		return ""
	var def := list.quests[q]
	if states[q] == State.DONE:
		return "%s - done! Open PET to claim your reward" % def.title
	return "%s   %d/%d camps" % [def.title, progress[q], def.target]
