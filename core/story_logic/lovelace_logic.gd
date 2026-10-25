class_name LovelaceLogic
extends MomentLogic

const SOLUTION := ["M1", "M2", "M3", "M4"]

# Moment -> scene variant and pose per character id
const MOMENTS := {
	"M1": {"variant": "default", "poses": {"ada": "pen", "charles": "clipboard"}},
	"M2": {"variant": "open_door", "poses": {"ada": "pen_articles", "charles": "default"}},
	"M3": {"variant": "default", "poses": {"charles": "cup", "teapot": "default"}},
	"M4": {"variant": "papers", "poses": {"ada": "pile", "charles": "scared_cup"}},
}


func _solution() -> Array:
	return SOLUTION

func _moments() -> Dictionary:
	return MOMENTS

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

func _match_moment(content: FrameContent, index: int, previous_moment: String) -> String:
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

func _doubt(content: FrameContent) -> FrameResult:
	var result := FrameResult.new()
	result.state = FrameResult.State.DOUBT
	result.left_pose = "doubt" if content.left.id == "ada" else "default"
	result.right_pose = "doubt" if content.right.id == "ada" else "default"
	return result
