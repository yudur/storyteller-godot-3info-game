extends Node

# Real mouse drags: Godot delivers the drop to the target before NOTIFICATION_DRAG_END
# reaches the source, all in the same frame. Runs as a scene for autoloads

var t := TestUtils.new()
var played: Array[String] = []

var office: SceneData = load("res://data/scenes/office.tres")
var kitchen: SceneData = load("res://data/scenes/kitchen.tres")
var ada: CharacterData = load("res://data/characters/ada.tres")
var charles: CharacterData = load("res://data/characters/charles.tres")
var teapot: CharacterData = load("res://data/characters/teapot.tres")

const LEFT := ComicFrame.CharacterSide.LEFT
const RIGHT := ComicFrame.CharacterSide.RIGHT

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	SoundPlayer.played.connect(func(stream: AudioStream) -> void: played.append(stream.resource_path.get_file()))
	await test_move_between_frames_does_not_fake_solution()
	await test_move_between_frames_leaves_no_transient_state()
	await test_drop_back_on_same_slot_keeps_character()
	await test_drop_back_scene_keeps_scene()
	await test_leaving_mid_ending_stops_it()
	t.finish(get_tree())

func new_game() -> GameScreen:
	var game: GameScreen = load("res://src/screens/game_screen/game_screen.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	return game

func fill(frame: ComicFrame, scene: SceneData, left: CharacterData, right: CharacterData) -> void:
	frame.set_scene(scene)
	if left:
		frame.add_character(left, LEFT)
	if right:
		frame.add_character(right, RIGHT)
	await get_tree().process_frame

func right_half(frame: ComicFrame) -> Vector2:
	return Vector2(frame.size.x * 0.75, 10.0)

func left_half(frame: ComicFrame) -> Vector2:
	return Vector2(frame.size.x * 0.25, 10.0)

func drag(from_sprite: FrameDragSource, to_frame: ComicFrame, data: Variant, at: Vector2) -> void:
	to_frame.drop_area.data_dropped.emit(data, at)
	from_sprite.drag_finished.emit(data, true)
	await get_tree().process_frame

func free_game(game: GameScreen) -> void:
	game.queue_free()
	await get_tree().process_frame

func test_move_between_frames_does_not_fake_solution() -> void:
	var game := await new_game()
	var f := game.frames
	await fill(f[0], office, ada, charles)
	await fill(f[1], office, ada, charles)
	await fill(f[2], kitchen, charles, teapot)
	await fill(f[3], office, ada, null)

	await drag(f[2].sprite_left, f[3], charles, right_half(f[3]))
	t.check(f[3].drop_area.enabled, "moving Charles from Q3 to Q4 does not start the ending")
	t.check(not game.logic.is_solved(game.collect_board()), "board really is unsolved")
	await free_game(game)

func test_move_between_frames_leaves_no_transient_state() -> void:
	var game := await new_game()
	var f := game.frames
	await fill(f[0], office, ada, charles)
	await fill(f[1], office, ada, null)
	played.clear()

	await drag(f[0].sprite_right, f[1], charles, right_half(f[1]))
	t.eq(played, [] as Array[String], "no sound while moving between frames")
	t.eq(f[1].background.texture, office.variants["default"], "no transient open door left behind")
	await free_game(game)

func test_drop_back_on_same_slot_keeps_character() -> void:
	var game := await new_game()
	var frame := game.frames[0]
	await fill(frame, office, ada, null)

	await drag(frame.sprite_left, frame, ada, left_half(frame))
	t.eq(frame.character_left, ada, "Ada dropped back on her own slot stays")

	frame.sprite_left.drag_finished.emit(ada, true)
	await get_tree().process_frame
	t.check(frame.character_left == null, "a later drag out still removes Ada")
	await free_game(game)

func test_drop_back_scene_keeps_scene() -> void:
	var game := await new_game()
	var frame := game.frames[0]
	await fill(frame, office, null, null)

	await drag(frame.background_drag, frame, office, left_half(frame))
	t.eq(frame.current_scene, office, "scene dropped back on its own frame stays")
	await free_game(game)

func test_leaving_mid_ending_stops_it() -> void:
	var manager: ScreenManager = load("res://src/screen_manager/screen_manager.tscn").instantiate()
	add_child(manager)
	await get_tree().process_frame
	await get_tree().process_frame
	var game := manager.game_screen

	manager.flip_page_next()
	await get_tree().create_timer(manager.flip_duration + 0.3).timeout
	var f := game.frames
	await fill(f[0], office, ada, charles)
	await fill(f[1], office, ada, charles)
	await fill(f[2], kitchen, charles, teapot)
	await fill(f[3], office, ada, charles)

	manager.flip_page_back()
	played.clear()
	await get_tree().create_timer(5.0).timeout
	t.eq(played.count("soundreality-bell-sound-effect-613873.mp3"), 0, "no bell over the menu")
	t.eq(played.count("alex_jauk-camera-sound-236021.mp3"), 0, "no camera clicks over the menu")
	manager.queue_free()
	await get_tree().process_frame
