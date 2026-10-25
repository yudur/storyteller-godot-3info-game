class_name GameScreen
extends Control

const SOUND_DROP := preload("res://assets/sounds/freesound_community-cartoon_boing-92413.mp3")

@export var story: StoryData
@export var frame_scene: PackedScene
@export var draggable_scene: PackedScene

@onready var title_label: Label = $Content/Title
@onready var card_grid: HFlowContainer = $Content/CardScroll/CardGrid
@onready var shelf: HFlowContainer = $Content/Shelf

var logic: StoryLogic
var frames: Array[ComicFrame] = []
var _last_results: Array[FrameResult] = []

func _ready() -> void:
	if story:
		load_story(story)

func load_story(story_data: StoryData) -> void:
	story = story_data
	title_label.text = story.title
	logic = story.logic.new() if story.logic else null
	if not logic:
		push_warning("Story '%s' has no logic script; frames will stay neutral" % story.id)

	clear_generated_content()
	create_frames()
	create_draggable_items()

func clear_generated_content() -> void:
	frames.clear()
	_last_results.clear()
	for child in card_grid.get_children():
		card_grid.remove_child(child)
		child.queue_free()

	for child in shelf.get_children():
		shelf.remove_child(child)
		child.queue_free()

func create_frames() -> void:
	if not frame_scene:
		return

	for index in range(story.number_of_frames):
		var frame: ComicFrame = frame_scene.instantiate()
		card_grid.add_child(frame)
		frame.contents_changed.connect(_evaluate_board)
		frame.item_dropped.connect(SoundPlayer.play.bind(SOUND_DROP))
		frames.append(frame)

func create_draggable_items() -> void:
	if not draggable_scene:
		return

	for item_data in story.draggable_items:
		var item := draggable_scene.instantiate()
		item.data = item_data
		shelf.add_child(item)

func collect_board() -> Array[FrameContent]:
	var board: Array[FrameContent] = []
	for frame in frames:
		board.append(frame.get_content())
	return board

func _evaluate_board() -> void:
	if not logic:
		return

	var board := collect_board()
	var results := logic.evaluate(board)
	for index in frames.size():
		frames[index].apply_result(results[index])
		if _last_results.is_empty() or not results[index].same_outcome(_last_results[index]):
			SoundPlayer.play_all(results[index].sounds)
	_last_results = results

	if logic.is_solved(board):
		print("solved")
