class_name FrameResult
extends RefCounted

enum State {
	NEUTRAL,
	COHERENT,
	DOUBT
}

# What one comic frame should show after the story logic evaluated the board
var state: State = State.NEUTRAL
var moment := ""
var scene_variant := "default"
var left_pose := "default"
var right_pose := "default"
var sounds: Array[AudioStream] = []
var show_doubt_icon: bool:
	get:
		return state == State.DOUBT

func same_outcome(other: FrameResult) -> bool:
	return other != null and other.state == state and other.moment == moment
