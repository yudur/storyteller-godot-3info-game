class_name MenuScreen
extends Control

signal phase_selected(story: StoryData)
signal back_requested

@export var stories: Array[StoryData] = []

@onready var phase_list: VBoxContainer = $RightPanel/PhaseScroll/PhaseCenter/PhaseList

var _completed: Dictionary[String, bool] = {}
var _buttons: Array[Button] = []
var _unchecked_icon: Texture2D = preload("res://assets/themes/chapter_checkbox_unchecked.svg")
var _checked_icon: Texture2D = preload("res://assets/themes/chapter_checkbox_checked.svg")

func _ready() -> void:
	_create_phase_list()

func mark_completed(story: StoryData) -> void:
	_completed[story.id] = true
	_refresh_icons()

# Progress lives for one visitor: the ScreenManager clears it on the way back
# to the start screen so the next person in the queue finds a clean menu
func reset_progress() -> void:
	_completed.clear()
	_refresh_icons()

func _create_phase_list() -> void:
	for child in phase_list.get_children():
		phase_list.remove_child(child)
		child.queue_free()
	_buttons.clear()

	if stories.is_empty():
		push_warning("MenuScreen has no stories to show")
		return

	for index in stories.size():
		var story := stories[index]
		var phase := Button.new()
		phase.text = "Capítulo %d" % [index + 1]
		phase.tooltip_text = story.title
		phase.custom_minimum_size = Vector2(0.0, 58.0)
		phase.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		phase.add_theme_font_size_override("font_size", 42)
		phase.add_theme_constant_override("icon_max_width", 44)
		phase.add_theme_constant_override("h_separation", 14)
		phase.pressed.connect(phase_selected.emit.bind(story))
		phase_list.add_child(phase)
		_buttons.append(phase)

	_refresh_icons()

func _refresh_icons() -> void:
	for index in _buttons.size():
		var is_done: bool = _completed.get(stories[index].id, false)
		_buttons[index].icon = _checked_icon if is_done else _unchecked_icon

func _on_back_pressed() -> void:
	back_requested.emit()
