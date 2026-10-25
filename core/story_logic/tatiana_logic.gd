class_name TatianaLogic
extends MomentLogic

const SOLUTION := ["M1", "M2", "M3"]

# Moment -> scene variant and pose per piece id. This phase tells its story
# through poses alone, so every variant is "default"
const MOMENTS := {
	"M1": {"variant": "default", "poses": {"patient": "default", "tatiana": "exams"}},
	"M2": {"variant": "default", "poses": {"tatiana": "microscope", "slide": "default"}},
	"M3": {"variant": "default", "poses": {"patient": "hopeful", "tatiana": "syringe"}},
}


func _solution() -> Array:
	return SOLUTION

func _moments() -> Dictionary:
	return MOMENTS

func ending(board: Array[FrameContent]) -> EndingData:
	if not is_solved(board):
		return null

	var last := board[SOLUTION.size() - 1]
	var data := EndingData.new()
	data.frame_index = SOLUTION.size() - 1
	data.scene_variant = "default"
	# The two poses differ, and apply_ending gives left_pose to whoever stands
	# on the left, so the side each piece landed on decides which gets which
	data.left_pose = "cured" if last.left.id == "patient" else "happy"
	data.right_pose = "cured" if last.right.id == "patient" else "happy"
	data.sounds.assign([])
	return data

func _match_moment(content: FrameContent, index: int, previous_moment: String) -> String:
	var scene_id := content.scene.id

	if scene_id == "hospital" and _has_pair(content, "patient", "tatiana"):
		if index == 0:
			return "M1"
		if previous_moment == "M2":
			return "M3"
	elif scene_id == "lab" and _has_pair(content, "tatiana", "slide"):
		if previous_moment == "M1":
			return "M2"

	return ""

func _doubt(content: FrameContent) -> FrameResult:
	var result := FrameResult.new()
	result.state = FrameResult.State.DOUBT
	result.left_pose = "doubt" if content.left.id == "tatiana" else "default"
	result.right_pose = "doubt" if content.right.id == "tatiana" else "default"
	return result
