class_name CharacterData
extends Resource

@export var id: String
@export var display_name: String

# Pose name -> sprite. "default" is required; story logic picks the others by context
@export var poses: Dictionary[String, Texture2D] = {}

func get_pose(key: String) -> Texture2D:
	if poses.has(key):
		return poses[key]
	if poses.has("default"):
		return poses["default"]

	push_warning("CharacterData '%s' has no pose '%s' nor 'default'" % [id, key])
	return null
