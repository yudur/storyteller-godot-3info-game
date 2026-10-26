extends Node

# Integration: GameScreen + ComicFrame wired to the story logic.
# Runs as a scene (test_board.tscn) so project autoloads like SignalBus exist

var t := TestUtils.new()

var office: SceneData = load("res://data/scenes/office.tres")
var kitchen: SceneData = load("res://data/scenes/kitchen.tres")
var ada: CharacterData = load("res://data/characters/ada.tres")
var charles: CharacterData = load("res://data/characters/charles.tres")
var teapot: CharacterData = load("res://data/characters/teapot.tres")
var hospital: SceneData = load("res://data/scenes/hospital.tres")
var patient: CharacterData = load("res://data/characters/patient.tres")
var tatiana: CharacterData = load("res://data/characters/tatiana.tres")

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
	await fill(frames[0], office, ada, charles)
	t.eq(frames[0].background.texture, office.variants["default"], "Q1 background")
	t.eq(frames[0].sprite_left.texture, ada.poses["pen"], "Q1 Ada with pen")
	t.eq(frames[0].sprite_right.texture, charles.poses["clipboard"], "Q1 Charles with clipboard")

	await fill(frames[1], office, charles, ada)
	t.eq(frames[1].background.texture, office.variants["open_door"], "Q2 open door")
	t.eq(frames[1].sprite_right.texture, ada.poses["pen_articles"], "Q2 Ada on the right")

	# Characters always face the center: Ada's art faces right, Charles' faces left
	t.eq(frames[0].sprite_left.flip_h, false, "Ada on the left keeps facing right")
	t.eq(frames[1].sprite_right.flip_h, true, "Ada on the right is mirrored to face left")
	t.eq(frames[1].sprite_left.flip_h, true, "Charles on the left is mirrored to face right")
	t.eq(frames[0].sprite_right.flip_h, false, "Charles on the right keeps facing left")

	await fill(frames[2], kitchen, charles, teapot)
	t.eq(frames[2].sprite_left.texture, charles.poses["cup"], "Q3 Charles with cup")

	# Removing Charles from Q1 neutralizes everything after it
	frames[0].sprite_right.drag_finished.emit(charles, true)
	await get_tree().process_frame
	t.eq(frames[0].sprite_left.texture, ada.poses["default"], "Q1 Ada back to default")
	t.eq(frames[1].background.texture, office.variants["default"], "Q2 background back to default")
	t.eq(frames[2].sprite_left.texture, charles.poses["default"], "Q3 Charles back to default")
	t.check(not frames[2].doubt_icon.visible, "Q3 no doubt when neutral")

	# Doubt: Ada and Charles in the kitchen
	frames[0].set_scene(kitchen)
	frames[0].add_character(charles, RIGHT)
	await get_tree().process_frame
	t.check(frames[0].doubt_icon.visible, "Q1 doubt icon")
	t.eq(frames[0].sprite_left.texture, ada.poses["doubt"], "Q1 Ada doubtful")

	# Dropping a scene over a frame with characters re-evaluates it
	frames[0].set_scene(office)
	await get_tree().process_frame
	t.check(not frames[0].doubt_icon.visible, "Q1 coherent again after scene swap")
	t.eq(frames[0].sprite_left.texture, ada.poses["pen"], "Q1 Ada with pen after scene swap")

	# Solved last: solving locks the board for the ending sequence
	await fill(frames[3], office, ada, charles)
	t.eq(frames[3].background.texture, office.variants["papers"], "Q4 papers")
	t.eq(frames[3].sprite_right.texture, charles.poses["scared_cup"], "Q4 Charles scared")
	t.check(game.logic.is_solved(game.collect_board()), "board solved")

	game.queue_free()
	await get_tree().process_frame

	await test_phase_2_characters_face_the_center()
	await test_shelf_card_shows_icon_and_name()
	t.finish(get_tree())

func fill(frame: ComicFrame, scene: SceneData, left: CharacterData, right: CharacterData) -> void:
	frame.set_scene(scene)
	frame.add_character(left, LEFT)
	frame.add_character(right, RIGHT)
	# Board evaluation is deferred to the end of the frame
	await get_tree().process_frame

# O Cadeirante é desenhado de perfil virado para a esquerda, como o Charles.
# Sem isso declarado, ele vira as costas para a Tatiana em dois dos três cards
# da fase 2 — e não há slot em que o valor errado funcione
func test_phase_2_characters_face_the_center() -> void:
	var left_frame := await new_frame()
	left_frame.set_scene(hospital)
	left_frame.add_character(patient, LEFT)
	left_frame.add_character(tatiana, RIGHT)
	await get_tree().process_frame
	t.eq(left_frame.sprite_left.flip_h, true, "the patient on the left is mirrored to face right")
	t.eq(left_frame.sprite_right.flip_h, true, "Tatiana on the right is mirrored to face left")

	var right_frame := await new_frame()
	right_frame.set_scene(hospital)
	right_frame.add_character(tatiana, LEFT)
	right_frame.add_character(patient, RIGHT)
	await get_tree().process_frame
	t.eq(right_frame.sprite_right.flip_h, false, "the patient on the right keeps facing left")
	t.eq(right_frame.sprite_left.flip_h, false, "Tatiana on the left keeps facing right")

	left_frame.queue_free()
	right_frame.queue_free()
	await get_tree().process_frame

func new_frame() -> ComicFrame:
	var frame: ComicFrame = load("res://src/comic_frame/comic_frame.tscn").instantiate()
	add_child(frame)
	await get_tree().process_frame
	return frame

# O card da prateleira mostra a arte da peça com o nome embaixo
func test_shelf_card_shows_icon_and_name() -> void:
	var card: DraggableItem = load("res://src/draggable/draggable.tscn").instantiate()
	card.data = tatiana
	add_child(card)
	await get_tree().process_frame

	t.eq(card.icon.texture, tatiana.get_icon(), "the card shows the piece's icon")
	t.eq(card.label.text, "Tatiana Sampaio", "the card shows the display name")
	t.check(card.label.position.y > card.icon.position.y, "the name sits below the image")
	card.queue_free()
	await get_tree().process_frame
