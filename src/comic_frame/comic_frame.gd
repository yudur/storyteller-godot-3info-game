class_name ComicFrame
extends Control

signal contents_changed
signal item_dropped

enum CharacterSide {
	LEFT,
	RIGHT
}

@onready var background: TextureRect = $Background
@onready var background_drag: FrameDragSource = $Background
@onready var sprite_left: FrameDragSource = $slotLeft/CharacterTexture
@onready var sprite_right: FrameDragSource = $slotRight/CharacterTexture
@onready var animator: FrameAnimator = $FrameAnimator
@onready var drop_area: FrameDropArea = $DropArea
@onready var doubt_icon: Label = $DoubtIcon

var current_scene: SceneData
var character_left: CharacterData
var character_right: CharacterData

func _ready() -> void:
	drop_area.data_dropped.connect(_on_data_dropped)
	background_drag.drag_finished.connect(_on_background_drag_finished)
	sprite_left.drag_finished.connect(_on_left_character_drag_finished)
	sprite_right.drag_finished.connect(_on_right_character_drag_finished)
	_reset_frame()

func clear_frame() -> void:
	_reset_frame()
	contents_changed.emit()

func set_scene(scene: SceneData) -> void:
	current_scene = scene
	background.texture = scene.get_variant("default") if scene else null
	_update_drag_sources()

	if background.texture:
		animator.fade_in_scene(background)
	else:
		background.modulate.a = 1.0
	contents_changed.emit()

func add_character(character: CharacterData, side: CharacterSide) -> void:
	if not character or not character.get_pose("default"):
		return

	var sprite := _get_sprite(side)
	if not sprite:
		return

	if side == CharacterSide.LEFT:
		character_left = character
	else:
		character_right = character

	sprite.texture = character.get_pose("default")
	sprite.set_drag_data(character)
	animator.fade_in_character(sprite, _side_name(side))
	_update_drag_sources()
	contents_changed.emit()

func get_content() -> FrameContent:
	return FrameContent.new(current_scene, character_left, character_right)

func apply_result(result: FrameResult) -> void:
	if current_scene:
		_swap_background(current_scene.get_variant(result.scene_variant))
	if character_left:
		_swap_character(sprite_left, character_left.get_pose(result.left_pose), "left")
	if character_right:
		_swap_character(sprite_right, character_right.get_pose(result.right_pose), "right")
	doubt_icon.visible = result.show_doubt_icon

func set_interactive(enabled: bool) -> void:
	var filter := Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	background_drag.mouse_filter = filter
	sprite_left.mouse_filter = filter
	sprite_right.mouse_filter = filter
	drop_area.enabled = enabled

func _reset_frame() -> void:
	animator.reset()
	current_scene = null
	character_left = null
	character_right = null
	background.texture = null
	background_drag.set_drag_data(null)
	sprite_left.texture = null
	sprite_left.set_drag_data(null)
	sprite_right.texture = null
	sprite_right.set_drag_data(null)
	doubt_icon.visible = false

func _swap_background(texture: Texture2D) -> void:
	if background.texture == texture:
		return
	background.texture = texture
	animator.fade_in_scene(background)

func _swap_character(sprite: TextureRect, texture: Texture2D, side: String) -> void:
	if sprite.texture == texture:
		return
	sprite.texture = texture
	animator.fade_in_character(sprite, side)

func _on_data_dropped(data: Variant, at_position: Vector2) -> void:
	if data is SceneData:
		set_scene(data)
	elif data is CharacterData and background.texture:
		add_character(data, _side_from_position(at_position))
	else:
		return
	item_dropped.emit()

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

func _update_drag_sources() -> void:
	background_drag.set_drag_data(
		current_scene if character_left == null and character_right == null else null
	)
	sprite_left.set_drag_data(character_left)
	sprite_right.set_drag_data(character_right)

func _on_background_drag_finished(_data: Variant, _successful: bool) -> void:
	if character_left == null and character_right == null:
		clear_frame()

func _on_left_character_drag_finished(_data: Variant, _successful: bool) -> void:
	character_left = null
	sprite_left.texture = null
	_update_drag_sources()
	contents_changed.emit()

func _on_right_character_drag_finished(_data: Variant, _successful: bool) -> void:
	character_right = null
	sprite_right.texture = null
	_update_drag_sources()
	contents_changed.emit()
