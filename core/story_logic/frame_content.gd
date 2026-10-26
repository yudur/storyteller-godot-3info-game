class_name FrameContent
extends RefCounted

# What the player placed in one comic frame
var scene: SceneData
var left: CharacterData
var right: CharacterData

func _init(scene_data: SceneData = null, left_character: CharacterData = null, right_character: CharacterData = null) -> void:
	scene = scene_data
	left = left_character
	right = right_character

func is_empty() -> bool:
	return scene == null and left == null and right == null

func character_count() -> int:
	return int(left != null) + int(right != null)

func has_character(id: String) -> bool:
	return (left != null and left.id == id) or (right != null and right.id == id)
