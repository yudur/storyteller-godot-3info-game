extends Node

# Only the ending makes sound: playing the board and flipping pages stay silent.
# Runs as a scene so the SoundPlayer autoload exists

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

	var game: GameScreen = load("res://src/screens/game_screen/game_screen.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	var f := game.frames

	# Board evaluation is deferred to the end of the frame, hence the awaits
	f[0].drop_area.data_dropped.emit(office, Vector2.ZERO)
	f[0].add_character(ada, LEFT)
	f[0].add_character(charles, RIGHT)
	await get_tree().process_frame
	t.eq(played, [] as Array[String], "drop and story moment are silent")

	f[1].set_scene(kitchen)
	f[1].add_character(ada, LEFT)
	f[1].add_character(charles, RIGHT)
	await get_tree().process_frame
	t.check(f[1].doubt_icon.visible, "doubt still shows")
	t.eq(played, [] as Array[String], "doubt is silent")

	f[1].set_scene(office)
	await get_tree().process_frame
	f[2].set_scene(kitchen)
	f[2].add_character(charles, LEFT)
	f[2].add_character(teapot, RIGHT)
	await get_tree().process_frame
	t.eq(played, [] as Array[String], "M2 and M3 are silent")

	game.queue_free()

	var manager: ScreenManager = load("res://src/screen_manager/screen_manager.tscn").instantiate()
	add_child(manager)
	await get_tree().process_frame
	await get_tree().process_frame
	manager.navigate_to(manager._screens.size() - 1)
	await get_tree().create_timer(manager.flip_duration + 0.3).timeout
	manager.navigate_to(manager._current_index - 1)
	await get_tree().create_timer(manager.flip_duration + 0.3).timeout
	t.eq(played, [] as Array[String], "page flips are silent")

	manager.queue_free()
	await get_tree().process_frame
	t.finish(get_tree())
