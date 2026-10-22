extends RefCounted
class_name SaveRegistry


var _participants: Array[SaveParticipantComponent] = []
var _runtime_roots: Array[RuntimeSaveRootComponent] = []


#region Public API
func register_participant(participant: SaveParticipantComponent) -> void:
	if participant == null:
		return

	if _participants.has(participant):
		return

	_participants.append(participant)


func unregister_participant(participant: SaveParticipantComponent) -> void:
	if participant == null:
		return

	_participants.erase(participant)


func get_participants() -> Array[SaveParticipantComponent]:
	return _participants.duplicate()


func register_runtime_root(runtime_root: RuntimeSaveRootComponent) -> void:
	if runtime_root == null:
		return

	if _runtime_roots.has(runtime_root):
		return

	_runtime_roots.append(runtime_root)


func unregister_runtime_root(runtime_root: RuntimeSaveRootComponent) -> void:
	if runtime_root == null:
		return

	_runtime_roots.erase(runtime_root)


func get_runtime_roots() -> Array[RuntimeSaveRootComponent]:
	return _runtime_roots.duplicate()
#endregion
