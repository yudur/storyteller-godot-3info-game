extends Node

# Ending sequence, completion panel and return to menu. Runs as a scene for autoloads

var t := TestUtils.new()
var played: Array[String] = []

var office: SceneData = load("res://data/scenes/office.tres")
var kitchen: SceneData = load("res://data/scenes/kitchen.tres")
var ada: CharacterData = load("res://data/characters/ada.tres")
var charles: CharacterData = load("res://data/characters/charles.tres")
var teapot: CharacterData = load("res://data/characters/teapot.tres")

const LEFT := ComicFrame.CharacterSide.LEFT
const RIGHT := ComicFrame.CharacterSide.RIGHT
const CAMERA := "alex_jauk-camera-sound-236021.mp3"
const BELL := "soundreality-bell-sound-effect-613873.mp3"

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	SoundPlayer.played.connect(func(stream: AudioStream) -> void: played.append(stream.resource_path.get_file()))
	await test_ending_sequence()
	await test_reload_cancels_ending()
	await test_screen_manager_navigation()
	t.finish(get_tree())

func new_game() -> GameScreen:
	var game: GameScreen = load("res://src/screens/game_screen/game_screen.tscn").instantiate()
	game.recap_interval = 0.05
	game.ending_hold = 0.05
	add_child(game)
	return game

func solve(game: GameScreen) -> void:
	fill(game.frames[0], office, ada, charles)
	fill(game.frames[1], office, ada, charles)
	fill(game.frames[2], kitchen, charles, teapot)
	fill(game.frames[3], office, ada, charles)

func fill(frame: ComicFrame, scene: SceneData, left: CharacterData, right: CharacterData) -> void:
	frame.set_scene(scene)
	frame.add_character(left, LEFT)
	frame.add_character(right, RIGHT)

func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func test_ending_sequence() -> void:
	var game := new_game()
	await get_tree().process_frame
	t.check(not game.completion_panel.visible, "panel hidden at start")

	solve(game)
	played.clear()
	for frame in game.frames:
		t.check(not frame.drop_area.enabled, "frames locked during ending")
	for item in game.shelf.get_children():
		t.eq(item.mouse_filter, Control.MOUSE_FILTER_IGNORE, "shelf locked during ending")

	await wait(1.0)
	t.eq(played.count(CAMERA), 4, "one camera click per frame")
	t.check(played.has("freesound_community-woman_laughs-37559.mp3"), "Ada laughs")
	t.check(played.has("floraphonic-man-laughs-2-190296.mp3"), "Charles laughs")
	t.eq(played.back() if not played.is_empty() else "", BELL, "bell plays last")
	t.eq(game.frames[3].sprite_left.texture, ada.poses["laughing"], "Q4 Ada laughing")
	t.eq(game.frames[3].sprite_right.texture, charles.poses["laughing"], "Q4 Charles laughing")
	t.eq(game.frames[3].background.texture, office.variants["papers"], "Q4 papers in ending")
	t.check(game.completion_panel.visible, "panel shown")
	t.eq(game.completion_label.text, "Fase concluída", "panel text")
	t.eq(game.back_button.text, "Voltar ao menu", "button text")

	var requested := [false]
	game.back_to_menu_requested.connect(func() -> void: requested[0] = true)
	game.back_button.pressed.emit()
	t.check(requested[0], "button requests menu")

	game.load_story(game.story)
	await get_tree().process_frame
	t.check(not game.completion_panel.visible, "panel hidden after reload")
	t.check(game.frames[0].get_content().is_empty(), "board clean after reload")
	t.check(game.frames[0].drop_area.enabled, "frames interactive after reload")
	for item in game.shelf.get_children():
		t.eq(item.mouse_filter, Control.MOUSE_FILTER_STOP, "shelf interactive after reload")

	solve(game)
	await wait(1.0)
	t.check(game.completion_panel.visible, "ending plays again after reload")
	game.queue_free()
	await get_tree().process_frame

func test_reload_cancels_ending() -> void:
	var game := new_game()
	await get_tree().process_frame
	solve(game)
	game.load_story(game.story)
	played.clear()
	await wait(1.0)
	t.check(not game.completion_panel.visible, "cancelled ending shows no panel")
	t.eq(played.count(BELL), 0, "cancelled ending plays no bell")
	t.check(game.frames[3].sprite_left.texture == null, "cancelled ending leaves new board empty")
	game.queue_free()
	await get_tree().process_frame

func test_screen_manager_navigation() -> void:
	var manager: ScreenManager = load("res://src/screen_manager/screen_manager.tscn").instantiate()
	add_child(manager)
	await get_tree().process_frame
	await get_tree().process_frame
	var game: GameScreen = manager.get_node("NextScreenViewportContainer/NextScreenViewport/GameScreen")

	fill(game.frames[0], office, ada, charles)
	manager.flip_page_next()
	await wait(manager.flip_duration + 0.3)
	t.check(game.frames[0].get_content().is_empty(), "entering the game resets the board")

	game.back_to_menu_requested.emit()
	await wait(manager.flip_duration + 0.3)
	t.check(manager._current_is_start, "back to menu flips to the start page")
	manager.queue_free()
	await get_tree().process_frame
