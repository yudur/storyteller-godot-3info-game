class_name ScreenManager
extends Control

@export var flip_duration := 0.7

@onready var screen_container: SubViewportContainer = $ScreenViewportContainer
@onready var screen_viewport: SubViewport = $ScreenViewportContainer/ScreenViewport
@onready var page_mesh: PageFlipMesh = $PageFlipMesh
@onready var physical_page: PageFlipMesh = $pageMesh
@onready var flip_back_button: Button = $FlipBackButton
@onready var flip_next_button: Button = $FlipNextButton

var _is_flipping := false
var _flip_direction := 1.0
var _physical_center := Vector2.ZERO
var _physical_scale := Vector2.ONE
var _physical_size := Vector2.ZERO

func _ready() -> void:
	flip_back_button.pressed.connect(flip_page_back)
	flip_next_button.pressed.connect(flip_page_next)
	await get_tree().process_frame

	var book_size := screen_container.size
	_physical_center = physical_page.position
	_physical_scale = physical_page.scale
	_physical_size = physical_page.texture.get_size()

	page_mesh.setup(book_size, screen_viewport.get_texture())
	physical_page.setup(
		Vector2(_physical_size.x * 2.0, _physical_size.y),
		physical_page.texture,
		_physical_size.x
	)
	physical_page.scale = _physical_scale
	_set_physical_page_position(book_size)
	page_mesh.scale = Vector2.ONE
	page_mesh.visible = false
	physical_page.visible = false

func flip_page_next() -> void:
	_play_flip(1.0)

func flip_page_back() -> void:
	_play_flip(-1.0)

func _play_flip(direction: float) -> void:
	if _is_flipping:
		return

	_is_flipping = true
	_flip_direction = direction
	screen_container.visible = false
	page_mesh.visible = true
	physical_page.visible = true
	page_mesh.z_index = 15
	physical_page.z_index = 16
	page_mesh.begin_flip(direction)
	physical_page.begin_flip(direction)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(_apply_flip_progress, 0.0, 1.0, flip_duration)
	tween.finished.connect(_finish_flip)

func _set_physical_page_position(book_size: Vector2) -> void:
	var spine_position := page_mesh.position + Vector2(book_size.x * 0.5, 0.0)
	physical_page.position = Vector2(
		spine_position.x - _physical_size.x * _physical_scale.x,
		_physical_center.y - _physical_size.y * 0.5 * _physical_scale.y
	)

func _apply_flip_progress(progress: float) -> void:
	page_mesh.set_progress(progress, _flip_direction)
	physical_page.set_progress(progress, _flip_direction)

	if progress >= 0.5:
		page_mesh.z_index = 17
		physical_page.z_index = 16
	else:
		page_mesh.z_index = 15
		physical_page.z_index = 16

func _finish_flip() -> void:
	page_mesh.finish_flip()
	physical_page.finish_flip()
	page_mesh.visible = false
	physical_page.visible = false
	screen_container.visible = true
	_is_flipping = false
