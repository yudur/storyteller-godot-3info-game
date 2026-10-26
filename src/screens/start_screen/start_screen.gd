class_name StartScreen
extends Control

signal start_requested

func _on_start_pressed() -> void:
	start_requested.emit()


func _on_quit_pressed() -> void:
	get_tree().quit()
