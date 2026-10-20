class_name FrameAnimator
extends Node

@export var scene_fade_duration := 0.5
@export var character_fade_duration := 0.4

var _scene_tween: Tween
var _left_character_tween: Tween
var _right_character_tween: Tween

func reset() -> void:
	_kill_tween(_scene_tween)
	_kill_tween(_left_character_tween)
	_kill_tween(_right_character_tween)
	_scene_tween = null
	_left_character_tween = null
	_right_character_tween = null

func fade_in_scene(background: TextureRect) -> void:
	_kill_tween(_scene_tween)
	background.modulate.a = 0.0
	_scene_tween = create_tween()
	_scene_tween.tween_property(
		background,
		"modulate:a",
		1.0,
		scene_fade_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func fade_in_character(sprite: TextureRect, side: String) -> void:
	var tween := _get_character_tween(side)
	_kill_tween(tween)

	sprite.modulate.a = 0.0
	tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 1.0, character_fade_duration)
	_set_character_tween(side, tween)

func _get_character_tween(side: String) -> Tween:
	if side == "left":
		return _left_character_tween
	return _right_character_tween

func _set_character_tween(side: String, tween: Tween) -> void:
	if side == "left":
		_left_character_tween = tween
	else:
		_right_character_tween = tween

func _kill_tween(tween: Tween) -> void:
	if tween and tween.is_running():
		tween.kill()
