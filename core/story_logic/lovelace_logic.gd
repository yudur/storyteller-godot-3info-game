class_name LovelaceLogic
extends StoryLogic

const SOLUTION := ["M1", "M2", "M3", "M4"]

# Moment -> scene variant and pose per character id
const MOMENTS := {
	"M1": {"variant": "default", "poses": {"ada": "pen", "charles": "clipboard"}},
	"M2": {"variant": "open_door", "poses": {"ada": "pen_articles", "charles": "default"}},
	"M3": {"variant": "default", "poses": {"charles": "cup", "teapot": "default"}},
	"M4": {"variant": "papers", "poses": {"ada": "pile", "charles": "scared_cup"}},
}


func evaluate(board: Array[FrameContent]) -> Array[FrameResult]:
	var results: Array[FrameResult] = []
	var previous: FrameResult = null

	for i in board.size():
		var result := _evaluate_frame(board[i], i, previous)
		results.append(result)
		previous = result

	return results

func is_solved(board: Array[FrameContent]) -> bool:
	if board.size() != SOLUTION.size():
		return false

	var moments := evaluate(board).map(func(result: FrameResult) -> String: return result.moment)
	return moments == SOLUTION

func ending(board: Array[FrameContent]) -> EndingData:
	if not is_solved(board):
		return null

	var data := EndingData.new()
	data.frame_index = SOLUTION.size() - 1
	data.scene_variant = "papers"
	data.left_pose = "laughing"
	data.right_pose = "laughing"
	data.sounds.assign([])
	return data

func _evaluate_frame(content: FrameContent, index: int, previous: FrameResult) -> FrameResult:
	var is_incomplete := content.scene == null or content.character_count() < 2
	var previous_is_neutral := index > 0 and previous.state == FrameResult.State.NEUTRAL
	if is_incomplete or previous_is_neutral:
		return FrameResult.new()

	var moment := _match_moment(content, index, previous)
	if moment.is_empty():
		return _doubt(content)
	return _coherent(content, moment)

func _match_moment(content: FrameContent, index: int, previous: FrameResult) -> String:
	var previous_moment := previous.moment if previous else ""
	var scene_id := content.scene.id

	if scene_id == "office" and _has_pair(content, "ada", "charles"):
		if index == 0:
			return "M1"
		if previous_moment == "M1":
			return "M2"
		if previous_moment == "M3":
			return "M4"
	elif scene_id == "kitchen" and _has_pair(content, "charles", "teapot"):
		if previous_moment == "M2":
			return "M3"

	return ""

func _has_pair(content: FrameContent, first_id: String, second_id: String) -> bool:
	return content.has_character(first_id) and content.has_character(second_id)

func _coherent(content: FrameContent, moment: String) -> FrameResult:
	var result := FrameResult.new()
	var poses: Dictionary = MOMENTS[moment]["poses"]
	result.state = FrameResult.State.COHERENT
	result.moment = moment
	result.scene_variant = MOMENTS[moment]["variant"]
	result.left_pose = poses.get(content.left.id, "default")
	result.right_pose = poses.get(content.right.id, "default")
	return result

func _doubt(content: FrameContent) -> FrameResult:
	var result := FrameResult.new()
	result.state = FrameResult.State.DOUBT
	result.left_pose = "doubt" if content.left.id == "ada" else "default"
	result.right_pose = "doubt" if content.right.id == "ada" else "default"
	return result
