class_name MomentLogic
extends StoryLogic

# The grammar both phases share: a frame is neutral when it is incomplete or
# follows an incomplete one, coherent when it matches a moment given the moment
# before it, and doubtful otherwise. A phase supplies only its own table of
# moments and the rules that match them.

func evaluate(board: Array[FrameContent]) -> Array[FrameResult]:
	var results: Array[FrameResult] = []
	var previous: FrameResult = null

	for i in board.size():
		var result := _evaluate_frame(board[i], i, previous)
		results.append(result)
		previous = result

	return results

func is_solved(board: Array[FrameContent]) -> bool:
	var solution := _solution()
	if board.size() != solution.size():
		return false

	var moments := evaluate(board).map(func(result: FrameResult) -> String: return result.moment)
	return moments == solution

# GDScript resolves a const in the scope of the line that names it, so a const
# here would never see the one a subclass declares. Phases expose theirs through
# these three instead
func _solution() -> Array:
	return []

func _moments() -> Dictionary:
	return {}

func _match_moment(_content: FrameContent, _index: int, _previous_moment: String) -> String:
	return ""

func _evaluate_frame(content: FrameContent, index: int, previous: FrameResult) -> FrameResult:
	var is_incomplete := content.scene == null or content.character_count() < 2
	var previous_is_neutral := index > 0 and previous.state == FrameResult.State.NEUTRAL
	if is_incomplete or previous_is_neutral:
		return FrameResult.new()

	var previous_moment := previous.moment if previous else ""
	var moment := _match_moment(content, index, previous_moment)
	if moment.is_empty():
		return _doubt(content)
	return _coherent(content, moment)

func _coherent(content: FrameContent, moment: String) -> FrameResult:
	var result := FrameResult.new()
	var moment_data: Dictionary = _moments()[moment]
	var poses: Dictionary = moment_data["poses"]
	result.state = FrameResult.State.COHERENT
	result.moment = moment
	result.scene_variant = moment_data["variant"]
	result.left_pose = poses.get(content.left.id, "default")
	result.right_pose = poses.get(content.right.id, "default")
	return result

# Phases that have a character with a face for it override this
func _doubt(_content: FrameContent) -> FrameResult:
	var result := FrameResult.new()
	result.state = FrameResult.State.DOUBT
	return result

func _has_pair(content: FrameContent, first_id: String, second_id: String) -> bool:
	return content.has_character(first_id) and content.has_character(second_id)
