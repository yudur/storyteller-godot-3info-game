class_name ScreenManager
extends Control

const SOUND_BOOK_OPEN := preload("res://assets/sounds/soumages-book-opening-345808.mp3")
const SOUND_BOOK_CLOSE := preload("res://assets/sounds/oxidvideos-book-closing-466850.mp3")

@export var flip_duration := 0.7

@onready var screen_container: SubViewportContainer = $ScreenViewportContainer
@onready var screen_viewport: SubViewport = $ScreenViewportContainer/ScreenViewport
@onready var next_screen_container: SubViewportContainer = $NextScreenViewportContainer
@onready var next_screen_viewport: SubViewport = $NextScreenViewportContainer/NextScreenViewport
@onready var page_mesh: PageFlipMesh = $PageFlipMesh
@onready var next_page_mesh: PageFlipMesh = $NextPageFlipMesh
@onready var physical_page: PageFlipMesh = $pageMesh
@onready var flip_back_button: Button = $FlipBackButton
@onready var flip_next_button: Button = $FlipNextButton
@onready var game_screen: GameScreen = $NextScreenViewportContainer/NextScreenViewport/GameScreen

var _is_flipping := false
var _flip_direction := 1.0
var _physical_center := Vector2.ZERO
var _physical_scale := Vector2.ONE
var _physical_size := Vector2.ZERO
var _current_is_start := true

func _ready() -> void:
	flip_back_button.pressed.connect(flip_page_back)
	flip_next_button.pressed.connect(flip_page_next)
	game_screen.back_to_menu_requested.connect(flip_page_back)
	await get_tree().process_frame

	var book_size := screen_container.size
	_physical_center = physical_page.position
	_physical_scale = physical_page.scale
	_physical_size = physical_page.texture.get_size()

	page_mesh.setup(book_size, screen_viewport.get_texture())
	next_page_mesh.setup(book_size, next_screen_viewport.get_texture())
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
	next_page_mesh.visible = false

	var start_screen := screen_viewport.get_node_or_null("StartScreen")
	if start_screen and start_screen.has_signal("start_requested"):
		start_screen.start_requested.connect(_on_start_requested)

func flip_page_next() -> void:
	if _current_is_start:
		_play_flip(1.0)

func flip_page_back() -> void:
	if not _current_is_start:
		_play_scene_flip(-1.0)

func _play_flip(direction: float) -> void:
	_play_scene_flip(direction)

func _on_start_requested() -> void:
	_play_scene_flip(1.0)

func _play_scene_flip(direction: float) -> void:
	if _is_flipping:
		return

	_is_flipping = true
	_flip_direction = direction
	SoundPlayer.play(SOUND_BOOK_OPEN if direction > 0.0 else SOUND_BOOK_CLOSE)
	if direction > 0.0 and game_screen.story:
		game_screen.load_story(game_screen.story)
	screen_container.visible = false
	next_screen_container.visible = false
	next_screen_container.modulate.a = 0.0
	screen_container.modulate.a = 0.0
	page_mesh.visible = true
	next_page_mesh.visible = true
	physical_page.visible = true
	physical_page.z_index = 16
	page_mesh.begin_flip(direction)
	next_page_mesh.begin_flip(direction)
	physical_page.begin_flip(direction)
	_set_content_layers(direction)
	if direction > 0.0:
		next_page_mesh.set_progress(1.0, -_flip_direction)
	else:
		page_mesh.set_progress(1.0, -_flip_direction)

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
	if _flip_direction > 0.0:
		page_mesh.set_progress(progress, _flip_direction)
		next_page_mesh.set_progress(1.0 - progress, -_flip_direction)
	else:
		next_page_mesh.set_progress(progress, _flip_direction)
		page_mesh.set_progress(1.0 - progress, -_flip_direction)

	physical_page.set_progress(progress, _flip_direction)

	if _flip_direction > 0.0:
		_set_content_layers(_flip_direction if progress < 0.5 else -_flip_direction)
		next_screen_container.visible = progress >= 0.5
		next_screen_container.modulate.a = smoothstep(0.5, 0.85, progress)
	else:
		_set_content_layers(_flip_direction if progress < 0.5 else -_flip_direction)

func _finish_flip() -> void:
	page_mesh.finish_flip()
	next_page_mesh.finish_flip()
	page_mesh.set_progress(0.0, -_flip_direction)
	next_page_mesh.set_progress(0.0, -_flip_direction)
	physical_page.finish_flip()
	page_mesh.visible = false
	next_page_mesh.visible = false
	screen_container.modulate.a = 1.0
	next_screen_container.modulate.a = 1.0
	physical_page.visible = false
	_current_is_start = not _current_is_start
	screen_container.visible = _current_is_start
	next_screen_container.visible = not _current_is_start
	_is_flipping = false

func _set_content_layers(outgoing_direction: float) -> void:
	if outgoing_direction > 0.0:
		page_mesh.z_index = 17
		next_page_mesh.z_index = 14
	else:
		next_page_mesh.z_index = 17
		page_mesh.z_index = 14
