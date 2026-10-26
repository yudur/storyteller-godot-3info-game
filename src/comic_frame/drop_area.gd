class_name FrameDropArea
extends Control

signal data_dropped(data: Variant, position: Vector2)

var enabled := true

# Connecting here rather than in _ready because the screen this lives in is
# reparented between viewports on every page flip: that fires _exit_tree, which
# drops the connection, but it does not run _ready again
func _enter_tree() -> void:
	if not SignalBus.drag_is_active.is_connected(_on_drag_is_active):
		SignalBus.drag_is_active.connect(_on_drag_is_active)
	_on_drag_is_active(false)

func _exit_tree() -> void:
	if SignalBus.drag_is_active.is_connected(_on_drag_is_active):
		SignalBus.drag_is_active.disconnect(_on_drag_is_active)

func _on_drag_is_active(is_active: bool) -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if is_active else Control.MOUSE_FILTER_IGNORE

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return enabled and (data is CharacterData or data is SceneData)

func _drop_data(at_position: Vector2, data: Variant) -> void:
	data_dropped.emit(data, at_position)
	SignalBus.drag_is_active.emit(false)
