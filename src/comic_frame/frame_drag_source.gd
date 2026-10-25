class_name FrameDragSource
extends TextureRect

signal drag_finished(data: Variant, successful: bool)

var data: Variant
var _drag_is_active := false

func set_drag_data(value: Variant) -> void:
	data = value

func _get_drag_data(_at_position: Vector2) -> Variant:
	if data == null or texture == null:
		return null

	_drag_is_active = true
	SignalBus.drag_is_active.emit(true)
	set_drag_preview(_create_drag_preview())
	return data

func _notification(what: int) -> void:
	if what != NOTIFICATION_DRAG_END:
		return

	if not _drag_is_active:
		return

	var successful := get_viewport().gui_is_drag_successful()
	_drag_is_active = false
	drag_finished.emit(data, successful)
	SignalBus.drag_is_active.emit(false)

func _create_drag_preview() -> TextureRect:
	var preview := TextureRect.new()
	preview.texture = texture
	preview.expand_mode = expand_mode
	preview.stretch_mode = stretch_mode
	preview.flip_h = flip_h
	preview.size = size
	preview.modulate = Color(1.0, 1.0, 1.0, 0.7)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return preview
