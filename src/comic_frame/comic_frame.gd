class_name ComicFrame
extends Control


# References for internal visual nodes
@onready var background: TextureRect = $Background
@onready var slotLeft: Control = $slotLeft
@onready var slotRight: Control = $slotRight
@onready var sprite_left: TextureRect = $slotLeft/CaracterTexture
@onready var sprite_right: TextureRect = $slotRight/CaracterTexture

# Variables storing the current state of the data for this frame
var current_scene: SceneData = null
var character_left: CharacterData = null
var character_right: CharacterData = null

var tween_left:Tween
var tween_right:Tween

func _ready() -> void:
	clear_frame()
	
func clear_frame() -> void:
	current_scene = null
	character_left = null
	character_right = null
	background.texture = null
	sprite_left.texture = null
	sprite_right = null
	
func animate_scene() -> void:
	background.modulate.a = 0.0
	
	var tween = create_tween()
	
	tween.tween_property(background, 
	"modulate:a",
	 1.0,
	 0.5
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
func set_scene(scene: SceneData) -> void:
	current_scene = scene
	if current_scene and current_scene.background:
		background.texture = current_scene.background
		animate_scene()
	else:
		background.texture = null
		
	SignalBus.frame_changed.emit()
	
	

func animate_character(sprite: TextureRect, side : String) -> void:
	if side == "left":
		if tween_left and tween_left.is_running():
			tween_left.kill()
	else:
		if tween_right and tween_right.is_running():
			tween_right.kill()
	
	var tween = create_tween()
	sprite.modulate.a = 0.0
	tween.tween_property(sprite, "modulate:a", 1.0, 0.4)
	
func add_character(character: CharacterData, side: String) -> void:
	if side == "left":
		character_left = character
		sprite_left.texture = character.sprite_normal
		animate_character(sprite_left, "left")
	elif side == "right":
		character_right = character
		sprite_right.texture = character.sprite_normal
		animate_character(sprite_right,"right")
	else:
		return
		
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
