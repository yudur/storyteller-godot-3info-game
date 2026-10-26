class_name DraggableItem
extends ColorRect

@onready var icon: TextureRect = $Content/Icon
@onready var label: Label = $Content/Label

@export var data: Resource
@export var drag_threshold := 8.0

var _press_position := Vector2.ZERO
var _is_pressed := false
var _drag_started := false
var _drag_is_active := false

func _ready() -> void:
	_update_contents()

func set_interactive(enabled: bool) -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and data:
			_press_position = event.position
			_is_pressed = true
			_drag_started = false
			accept_event()
		else:
			_is_pressed = false
		return

	if event is InputEventMouseMotion and _is_pressed and not _drag_started:
		if event.position.distance_to(_press_position) >= drag_threshold:
			_drag_started = true
			_is_pressed = false
			_set_drag_active(true)
			force_drag(data, _create_drag_preview())
			accept_event()

func _get_drag_data(at_position: Vector2) -> Variant:
	if not data:
		return null

	_set_drag_active(true)
	set_drag_preview(_create_drag_preview())
	return data

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_set_drag_active(false)

func _set_drag_active(is_active: bool) -> void:
	if _drag_is_active == is_active:
		return

	_drag_is_active = is_active
	SignalBus.drag_is_active.emit(is_active)

func _update_contents() -> void:
	if not data:
		label.text = "Sem dados"
		icon.texture = null
		return

	label.text = data.display_name
	icon.texture = data.get_icon()

func _create_drag_preview() -> Control:
	var preview = ColorRect.new()
	preview.size = size
	preview.color = Color(color.r, color.g, color.b, 0.7)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var preview_icon := TextureRect.new()
	preview_icon.texture = icon.texture
	preview_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	preview_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.add_child(preview_icon)

	return preview
