class_name ComicFrame
extends Control


# References for internal visual nodes
@onready var background: TextureRect = $Background
@onready var slotLeft: Control = $slotLeft
@onready var slotRight: Control = $slotRight

# Variables storing the current state of the data for this frame
var current_scene: SceneData = null
var character_left: CharacterData = null
var character_right: CharacterData = null

func _ready() -> void:
	clear_frame()
	
func clear_frame() -> void:
	current_scene = null
	character_left = null
	character_right = null
	background.texture = null
	
func set_scene(scene: SceneData) -> void:
	current_scene = scene
	if current_scene and current_scene.background:
		background.texture = current_scene.background
	else:
		background.texture = null
		
	SignalBus.frame_changed.emit()
	
func add_character(character: CharacterData, side: String) -> void:
	if side == "left":
		character_left = character
	elif side == "right":
		character_right = character
		
	# Updates the characters' appearance depending on the scene context
	update_frame_logic()
	
	SignalBus.frame_changed.emit()

func update_frame_logic() -> void:
	if not current_scene:
		return
	
	# TODO: simple context check
	if character_left and character_right:
		if character_left.id == "king" and character_right.id == "monster":
			print("o rei esta assustado aaaaaaaa")

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	# The frame accepts the data if it is a character or a scene.
	return data is CharacterData or data is SceneData
	
func _drop_data(at_position: Vector2, data: Variant) -> void:
	if data is SceneData:
		set_scene(data)
	elif data is CharacterData:
		# TODO: Plays in the left slot by default to test.
		add_character(data, "left")
