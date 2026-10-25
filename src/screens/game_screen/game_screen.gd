class_name GameScreen
extends Control

signal back_to_menu_requested

const SOUND_DROP := preload("res://assets/sounds/freesound_community-cartoon_boing-92413.mp3")
const SOUND_CAMERA := preload("res://assets/sounds/alex_jauk-camera-sound-236021.mp3")
const SOUND_BELL := preload("res://assets/sounds/soundreality-bell-sound-effect-613873.mp3")

@export var story: StoryData
@export var frame_scene: PackedScene
@export var draggable_scene: PackedScene
# Seconds between frame highlights in the ending recap
@export var recap_interval := 0.6
# Seconds the laughing frame stays on screen before the completion panel
@export var ending_hold := 1.5

@onready var title_label: Label = $Content/Title
@onready var card_grid: HFlowContainer = $Content/CardScroll/CardGrid
@onready var shelf: HFlowContainer = $Content/Shelf
@onready var completion_panel: PanelContainer = $CompletionPanel
@onready var completion_label: Label = $CompletionPanel/Layout/Message
@onready var back_button: Button = $CompletionPanel/Layout/BackButton

var logic: StoryLogic
var frames: Array[ComicFrame] = []
var _last_results: Array[FrameResult] = []
var _ending_played := false
var _evaluation_queued := false
var _ending_tween: Tween

func _ready() -> void:
	back_button.pressed.connect(back_to_menu_requested.emit)
	if story:
		load_story(story)

func load_story(story_data: StoryData) -> void:
	story = story_data
	title_label.text = story.title
	cancel_ending()
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
		frame.contents_changed.connect(_queue_evaluation)
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

func cancel_ending() -> void:
	if _ending_tween:
		_ending_tween.kill()
		_ending_tween = null
	_ending_played = false
	completion_panel.hide()

# A drag between frames changes two frames (drop on the target, then drag end on
# the source) in the same frame; evaluating once afterwards avoids judging a board
# where the dragged item is briefly in both places
func _queue_evaluation() -> void:
	if _evaluation_queued:
		return
	_evaluation_queued = true
	_evaluate_board.call_deferred()

func _evaluate_board() -> void:
	_evaluation_queued = false
	if not logic or _ending_played:
		return

	var board := collect_board()
	var results := logic.evaluate(board)
	for index in frames.size():
		frames[index].apply_result(results[index])
		if _last_results.is_empty() or not results[index].same_outcome(_last_results[index]):
			SoundPlayer.play_all(results[index].sounds)
	_last_results = results

	if logic.is_solved(board):
		_play_ending(logic.ending(board))

func _play_ending(ending: EndingData) -> void:
	_ending_played = true
	_set_board_interactive(false)

	_ending_tween = create_tween()
	for frame in frames:
		_ending_tween.tween_callback(frame.highlight)
		_ending_tween.tween_callback(SoundPlayer.play.bind(SOUND_CAMERA))
		_ending_tween.tween_interval(recap_interval)

	var ending_frame := frames[ending.frame_index]
	_ending_tween.tween_callback(ending_frame.apply_ending.bind(ending))
	_ending_tween.tween_callback(SoundPlayer.play_all.bind(ending.sounds))
	_ending_tween.tween_interval(ending_hold)
	_ending_tween.tween_callback(completion_panel.show)
	_ending_tween.tween_callback(SoundPlayer.play.bind(SOUND_BELL))

func _set_board_interactive(enabled: bool) -> void:
	for frame in frames:
		frame.set_interactive(enabled)
	for item in shelf.get_children():
		item.set_interactive(enabled)
