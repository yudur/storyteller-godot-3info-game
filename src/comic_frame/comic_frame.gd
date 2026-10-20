class_name ComicFrame
extends Control

enum CharacterSide {
	LEFT,
	RIGHT
}

@onready var background: TextureRect = $Background
@onready var sprite_left: TextureRect = $slotLeft/CharacterTexture
@onready var sprite_right: TextureRect = $slotRight/CharacterTexture
@onready var animator: FrameAnimator = $FrameAnimator
@onready var story_logic: FrameStoryLogic = $FrameStoryLogic
@onready var drop_area: FrameDropArea = $DropArea

var current_scene: SceneData
var character_left: CharacterData
var character_right: CharacterData

func _ready() -> void:
	drop_area.data_dropped.connect(_on_data_dropped)
	clear_frame()

func clear_frame() -> void:
	animator.reset()
	current_scene = null
	character_left = null
	character_right = null
	background.texture = null
	sprite_left.texture = null
	sprite_right.texture = null

func set_scene(scene: SceneData) -> void:
	current_scene = scene
	background.texture = scene.background if scene else null

	if background.texture:
		animator.fade_in_scene(background)
	else:
		background.modulate.a = 1.0

	_emit_frame_changed()

func add_character(character: CharacterData, side: CharacterSide) -> void:
	if not character or not character.sprite_normal:
		return

	var sprite := _get_sprite(side)
	if not sprite:
		return

	if side == CharacterSide.LEFT:
		character_left = character
	else:
		character_right = character

	sprite.texture = character.sprite_normal
	animator.fade_in_character(sprite, _side_name(side))
	story_logic.update_scene_state(current_scene, character_left, character_right)
	_emit_frame_changed()

func _on_data_dropped(data: Variant, at_position: Vector2) -> void:
	if data is SceneData:
		set_scene(data)
	elif data is CharacterData and background.texture:
		add_character(data, _side_from_position(at_position))

func _get_sprite(side: CharacterSide) -> TextureRect:
	if side == CharacterSide.LEFT:
		return sprite_left
	return sprite_right

func _side_from_position(position: Vector2) -> CharacterSide:
	if position.x < size.x * 0.5:
		return CharacterSide.LEFT
	return CharacterSide.RIGHT

func _side_name(side: CharacterSide) -> String:
	if side == CharacterSide.LEFT:
		return "left"
	return "right"

func _emit_frame_changed() -> void:
	SignalBus.frame_changed.emit()
