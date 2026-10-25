extends Node

# Which sounds play, and when. Runs as a scene so the SoundPlayer autoload exists

var t := TestUtils.new()
var played: Array[String] = []

var office: SceneData = load("res://data/scenes/office.tres")
var kitchen: SceneData = load("res://data/scenes/kitchen.tres")
var ada: CharacterData = load("res://data/characters/ada.tres")
var charles: CharacterData = load("res://data/characters/charles.tres")

const LEFT := ComicFrame.CharacterSide.LEFT
const RIGHT := ComicFrame.CharacterSide.RIGHT

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	SoundPlayer.played.connect(func(stream: AudioStream) -> void: played.append(stream.resource_path.get_file()))

	var game: GameScreen = load("res://src/screens/game_screen/game_screen.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	var frame := game.frames[0]

	# Board evaluation is deferred to the end of the frame, hence the awaits
	frame.set_scene(office)
	frame.add_character(ada, LEFT)
	await get_tree().process_frame
	t.eq(played, [] as Array[String], "no sound while incomplete")

	frame.add_character(charles, RIGHT)
	await get_tree().process_frame
	t.eq(played, ["floraphonic-rustling-bushes-dried-leaves-6-230205.mp3"] as Array[String], "M1 sound once")

	played.clear()
	frame.set_scene(office)
	await get_tree().process_frame
	t.eq(played, [] as Array[String], "same outcome does not replay")

	frame.sprite_right.drag_finished.emit(charles, true)
	await get_tree().process_frame
	frame.add_character(charles, RIGHT)
	await get_tree().process_frame
	t.eq(played, ["floraphonic-rustling-bushes-dried-leaves-6-230205.mp3"] as Array[String], "M1 replays after leaving and coming back")

	played.clear()
	frame.set_scene(kitchen)
	await get_tree().process_frame
	t.eq(played, ["voiceofruthie-hmmmm-338158.mp3"] as Array[String], "doubt with Ada")

	played.clear()
	frame.drop_area.data_dropped.emit(office, Vector2.ZERO)
	t.check(played.has("freesound_community-cartoon_boing-92413.mp3"), "drop plays boing")

	game.queue_free()

	var manager: ScreenManager = load("res://src/screen_manager/screen_manager.tscn").instantiate()
	add_child(manager)
	await get_tree().process_frame
	await get_tree().process_frame
	played.clear()
	manager.flip_page_next()
	t.eq(played, ["soumages-book-opening-345808.mp3"] as Array[String], "flip forward opens book")
	await get_tree().create_timer(manager.flip_duration + 0.3).timeout
	played.clear()
	manager.flip_page_back()
	t.eq(played, ["oxidvideos-book-closing-466850.mp3"] as Array[String], "flip back closes book")

	manager.queue_free()
	await get_tree().process_frame
	t.finish(get_tree())
