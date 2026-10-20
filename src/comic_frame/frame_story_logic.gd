class_name FrameStoryLogic
extends Node

func update_scene_state(
	scene: SceneData,
	left_character: CharacterData,
	right_character: CharacterData
) -> void:
	if not scene or not left_character or not right_character:
		return

	if left_character.id == "king" and right_character.id == "monster":
		print("o rei esta assustado aaaaaaaa")
