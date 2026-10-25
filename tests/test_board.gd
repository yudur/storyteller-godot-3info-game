extends Node

# Integration: GameScreen + ComicFrame wired to the story logic.
# Runs as a scene (test_board.tscn) so project autoloads like SignalBus exist

var t := TestUtils.new()

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
	var game: GameScreen = load("res://src/screens/game_screen/game_screen.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame

	t.eq(game.title_label.text, "As notas de Lovelace", "story title")
	t.eq(game.frames.size(), 4, "four frames")
	t.eq(game.shelf.get_child_count(), 5, "five shelf items")
	t.check(game.logic is LovelaceLogic, "logic instantiated from story")

	var frames := game.frames
	fill(frames[0], office, ada, charles)
	t.eq(frames[0].background.texture, office.variants["default"], "Q1 background")
	t.eq(frames[0].sprite_left.texture, ada.poses["pen"], "Q1 Ada with pen")
	t.eq(frames[0].sprite_right.texture, charles.poses["clipboard"], "Q1 Charles with clipboard")

	fill(frames[1], office, charles, ada)
	t.eq(frames[1].background.texture, office.variants["open_door"], "Q2 open door")
	t.eq(frames[1].sprite_right.texture, ada.poses["pen_articles"], "Q2 Ada on the right")

	fill(frames[2], kitchen, charles, teapot)
	t.eq(frames[2].sprite_left.texture, charles.poses["cup"], "Q3 Charles with cup")

	fill(frames[3], office, ada, charles)
	t.eq(frames[3].background.texture, office.variants["papers"], "Q4 papers")
	t.eq(frames[3].sprite_right.texture, charles.poses["scared_cup"], "Q4 Charles scared")
	t.check(game.logic.is_solved(game.collect_board()), "board solved")

	# Removing Charles from Q1 neutralizes everything after it
	frames[0].sprite_right.drag_finished.emit(charles, true)
	t.eq(frames[0].sprite_left.texture, ada.poses["default"], "Q1 Ada back to default")
	t.eq(frames[3].background.texture, office.variants["default"], "Q4 background back to default")
	t.eq(frames[3].sprite_left.texture, ada.poses["default"], "Q4 Ada back to default")
	t.check(not frames[3].doubt_icon.visible, "Q4 no doubt when neutral")

	# Doubt: Ada and Charles in the kitchen
	frames[0].set_scene(kitchen)
	frames[0].add_character(charles, RIGHT)
	t.check(frames[0].doubt_icon.visible, "Q1 doubt icon")
	t.eq(frames[0].sprite_left.texture, ada.poses["doubt"], "Q1 Ada doubtful")

	# Dropping a scene over a frame with characters re-evaluates it
	frames[0].set_scene(office)
	t.check(not frames[0].doubt_icon.visible, "Q1 coherent again after scene swap")
	t.eq(frames[0].sprite_left.texture, ada.poses["pen"], "Q1 Ada with pen after scene swap")

	game.queue_free()
	await get_tree().process_frame
	t.finish(get_tree())

func fill(frame: ComicFrame, scene: SceneData, left: CharacterData, right: CharacterData) -> void:
	frame.set_scene(scene)
	frame.add_character(left, LEFT)
	frame.add_character(right, RIGHT)
