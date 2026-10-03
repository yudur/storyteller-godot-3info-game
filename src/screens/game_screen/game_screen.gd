class_name GameScreen
extends Control

@export var story: StoryData
@export var frame_scene: PackedScene
@export var draggable_scene: PackedScene

@onready var title_label: Label = $Content/Title
@onready var card_grid: HFlowContainer = $Content/CardScroll/CardGrid
@onready var shelf: HFlowContainer = $Content/Shelf

func _ready() -> void:
	if story:
		load_story(story)

func load_story(story_data: StoryData) -> void:
	story = story_data
	title_label.text = story.title
	clear_generated_content()
	create_frames()
	create_draggable_items()

func clear_generated_content() -> void:
	for child in card_grid.get_children():
		child.queue_free()

	for child in shelf.get_children():
		child.queue_free()

func create_frames() -> void:
	if not frame_scene:
		return

	for scene_data in story.frames:
		var frame := frame_scene.instantiate()
		card_grid.add_child(frame)
		frame.set_scene(scene_data)

func create_draggable_items() -> void:
	if not draggable_scene:
		return

	for item_data in story.draggable_items:
		var item := draggable_scene.instantiate()
		item.data = item_data
		shelf.add_child(item)
