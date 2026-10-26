class_name CharacterData
extends Resource

@export var id: String
@export var display_name: String
# Direction the sprite art looks at; frames mirror it so characters face the center
@export var faces_right := false

# Pose name -> sprite. "default" is required; story logic picks the others by context
@export var poses: Dictionary[String, Texture2D] = {}

# Small art for the shelf card. Falls back to the default pose when empty
@export var icon: Texture2D

func get_pose(key: String) -> Texture2D:
	if poses.has(key):
		return poses[key]
	if poses.has("default"):
		return poses["default"]

	push_warning("CharacterData '%s' has no pose '%s' nor 'default'" % [id, key])
	return null

func get_icon() -> Texture2D:
	return icon if icon else get_pose("default")
