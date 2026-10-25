class_name ScreenManager
extends Control

# The order here is the order of the children of the Screens node, which is
# also the order the pages turn in
enum Screen { START, MENU, GAME }

@export var flip_duration := 0.7

@onready var screens_holder: Node = $Screens
@onready var page_mesh: PageFlipMesh = $PageFlipMesh
@onready var next_page_mesh: PageFlipMesh = $NextPageFlipMesh
@onready var physical_page: PageFlipMesh = $pageMesh
@onready var start_screen: StartScreen = $Screens/StartScreen
@onready var menu_screen: MenuScreen = $Screens/MenuScreen
@onready var game_screen: GameScreen = $Screens/GameScreen

# The two viewports are not "the start page" and "the game page": one is the
# page going out and the other the page coming in, and which is which swaps on
# every flip. That is what lets a third screen exist without a third viewport.
var _containers: Array[SubViewportContainer] = []
var _viewports: Array[SubViewport] = []
var _meshes: Array[PageFlipMesh] = []
var _screens: Array[Control] = []
var _front := 0
var _back := 1
var _current_index := Screen.START
var _is_flipping := false
var _flip_direction := 1.0
var _physical_center := Vector2.ZERO
var _physical_scale := Vector2.ONE
var _physical_size := Vector2.ZERO

func _ready() -> void:
	_containers.assign([$ScreenViewportContainer, $NextScreenViewportContainer])
	_viewports.assign([
		$ScreenViewportContainer/ScreenViewport,
		$NextScreenViewportContainer/NextScreenViewport,
	])
	_meshes.assign([page_mesh, next_page_mesh])
	for child in screens_holder.get_children():
		_screens.append(child)
		# A parked screen sits under a plain Node, so it would otherwise draw
		# straight into the window instead of into a viewport
		child.visible = false

	start_screen.start_requested.connect(navigate_to.bind(Screen.MENU))
	menu_screen.phase_selected.connect(_on_phase_selected)
	game_screen.story_completed.connect(menu_screen.mark_completed)
	for screen in _screens:
		if screen.has_signal("back_requested"):
			screen.back_requested.connect(func() -> void: navigate_to(_current_index - 1))

	_mount(_screens[_current_index], _front)
	_viewports[_front].render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewports[_back].render_target_update_mode = SubViewport.UPDATE_DISABLED
	await get_tree().process_frame

	var book_size := _containers[0].size
	_physical_center = physical_page.position
	_physical_scale = physical_page.scale
	_physical_size = physical_page.texture.get_size()

	page_mesh.setup(book_size, _viewports[0].get_texture())
	next_page_mesh.setup(book_size, _viewports[1].get_texture())
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
	_containers[_front].visible = true
	_containers[_back].visible = false

func navigate_to(index: int) -> void:
	if _is_flipping or index == _current_index or index < 0 or index >= _screens.size():
		return

	_is_flipping = true
	# The direction only governs the geometry of the turn now, not who leaves
	_flip_direction = 1.0 if index > _current_index else -1.0

	if _current_index == Screen.GAME:
		game_screen.cancel_ending()
	if index == Screen.GAME and game_screen.story:
		game_screen.load_story(game_screen.story)
	if index == Screen.START:
		menu_screen.reset_progress()

	# Reparenting before the animation leaves the viewport a whole frame to
	# render the new screen, so it never appears for one frame as the old one
	_mount(_screens[index], _back)
	_viewports[_back].render_target_update_mode = SubViewport.UPDATE_ALWAYS

	_containers[_front].visible = false
	_containers[_front].modulate.a = 0.0
	_containers[_back].visible = false
	_containers[_back].modulate.a = 0.0
	page_mesh.visible = true
	next_page_mesh.visible = true
	physical_page.visible = true
	physical_page.z_index = 16
	page_mesh.begin_flip(_flip_direction)
	next_page_mesh.begin_flip(_flip_direction)
	physical_page.begin_flip(_flip_direction)
	_set_content_layers(true)
	_meshes[_back].set_progress(1.0, -_flip_direction)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(_apply_flip_progress, 0.0, 1.0, flip_duration)
	tween.finished.connect(_finish_flip.bind(index))

func _on_phase_selected(story: StoryData) -> void:
	game_screen.story = story
	navigate_to(Screen.GAME)

func _mount(screen: Control, slot: int) -> void:
	for child in _viewports[slot].get_children():
		if child is Control:
			_park(child)

	if screen.get_parent():
		screen.get_parent().remove_child(screen)
	_viewports[slot].add_child(screen)
	screen.visible = true

func _park(screen: Control) -> void:
	screen.visible = false
	if screen.get_parent():
		screen.get_parent().remove_child(screen)
	screens_holder.add_child(screen)

func _set_physical_page_position(book_size: Vector2) -> void:
	var spine_position := page_mesh.position + Vector2(book_size.x * 0.5, 0.0)
	physical_page.position = Vector2(
		spine_position.x - _physical_size.x * _physical_scale.x,
		_physical_center.y - _physical_size.y * 0.5 * _physical_scale.y
	)

func _apply_flip_progress(progress: float) -> void:
	_meshes[_front].set_progress(progress, _flip_direction)
	_meshes[_back].set_progress(1.0 - progress, -_flip_direction)
	physical_page.set_progress(progress, _flip_direction)
	_set_content_layers(progress < 0.5)
	_containers[_back].visible = progress >= 0.5
	_containers[_back].modulate.a = smoothstep(0.5, 0.85, progress)

func _finish_flip(index: int) -> void:
	page_mesh.finish_flip()
	next_page_mesh.finish_flip()
	page_mesh.set_progress(0.0, -_flip_direction)
	next_page_mesh.set_progress(0.0, -_flip_direction)
	physical_page.finish_flip()
	page_mesh.visible = false
	next_page_mesh.visible = false
	physical_page.visible = false
	_containers[0].modulate.a = 1.0
	_containers[1].modulate.a = 1.0

	_park(_screens[_current_index])
	_viewports[_front].render_target_update_mode = SubViewport.UPDATE_DISABLED
	var outgoing := _front
	_front = _back
	_back = outgoing
	_current_index = index
	_containers[_front].visible = true
	_containers[_back].visible = false
	_is_flipping = false

func _set_content_layers(outgoing_on_top: bool) -> void:
	_meshes[_front].z_index = 17 if outgoing_on_top else 14
	_meshes[_back].z_index = 14 if outgoing_on_top else 17
