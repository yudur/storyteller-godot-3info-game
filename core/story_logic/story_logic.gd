class_name StoryLogic
extends RefCounted

# Base for per-story rules. Pure: reads the board, never touches nodes

func evaluate(board: Array[FrameContent]) -> Array[FrameResult]:
	var results: Array[FrameResult] = []
	for content in board:
		results.append(FrameResult.new())
	return results

func is_solved(_board: Array[FrameContent]) -> bool:
	return false

func ending(_board: Array[FrameContent]) -> EndingData:
	return null
