extends SceneTree

var t := TestUtils.new()
var logic: StoryLogic

var hospital: SceneData = load("res://data/scenes/hospital.tres")
var lab: SceneData = load("res://data/scenes/lab.tres")
var patient: CharacterData = load("res://data/characters/patient.tres")
var tatiana: CharacterData = load("res://data/characters/tatiana.tres")
var slide: CharacterData = load("res://data/characters/slide.tres")

func _initialize() -> void:
	logic = TatianaLogic.new()

	test_solution_moments()
	test_moment_poses()
	test_swapped_sides()
	test_doubt_cases()
	test_incomplete_lab_cascades()
	test_same_piece_on_both_sides()
	test_ending()
	test_ending_needs_a_solved_board()

	t.finish(self)

func fc(scene: SceneData, left: CharacterData, right: CharacterData) -> FrameContent:
	return FrameContent.new(scene, left, right)

func board(frames: Array) -> Array[FrameContent]:
	var typed: Array[FrameContent] = []
	typed.assign(frames)
	return typed

func solution() -> Array[FrameContent]:
	return board([
		fc(hospital, patient, tatiana),
		fc(lab, tatiana, slide),
		fc(hospital, patient, tatiana),
	])

func moments_of(results: Array[FrameResult]) -> Array:
	return results.map(func(result: FrameResult) -> String: return result.moment)

func test_solution_moments() -> void:
	var results := logic.evaluate(solution())
	t.eq(moments_of(results), ["M1", "M2", "M3"], "solution moments")
	for result in results:
		t.eq(result.state, FrameResult.State.COHERENT, "every solution frame is coherent")
	t.check(logic.is_solved(solution()), "solution is solved")

func test_moment_poses() -> void:
	var results := logic.evaluate(solution())
	t.eq([results[0].left_pose, results[0].right_pose], ["default", "exams"], "M1 poses")
	t.eq([results[1].left_pose, results[1].right_pose], ["microscope", "default"], "M2 poses")
	t.eq([results[2].left_pose, results[2].right_pose], ["hopeful", "syringe"], "M3 poses")
	for result in results:
		t.eq(result.scene_variant, "default", "phase 2 uses no scene variants")

func test_swapped_sides() -> void:
	var swapped := board([
		fc(hospital, tatiana, patient),
		fc(lab, slide, tatiana),
		fc(hospital, tatiana, patient),
	])
	var results := logic.evaluate(swapped)
	t.eq(moments_of(results), ["M1", "M2", "M3"], "swapped sides give the same moments")
	t.check(logic.is_solved(swapped), "swapped sides still solve the phase")
	t.eq([results[0].left_pose, results[0].right_pose], ["exams", "default"], "M1 poses follow the side")
	t.eq([results[1].left_pose, results[1].right_pose], ["default", "microscope"], "M2 poses follow the side")

func test_doubt_cases() -> void:
	var hospital_in_second := board([
		fc(hospital, patient, tatiana),
		fc(hospital, patient, tatiana),
	])
	var results := logic.evaluate(hospital_in_second)
	t.eq(results[1].state, FrameResult.State.DOUBT, "hospital again right after M1 is doubt")
	t.eq(results[1].right_pose, "default", "Tatiana keeps her normal sprite in doubt")
	t.eq(results[1].left_pose, "default", "the patient keeps his normal sprite in doubt")
	t.check(results[1].show_doubt_icon, "the frame's question mark is what signals doubt")

	var lab_first := logic.evaluate(board([fc(lab, tatiana, slide)]))
	t.eq(lab_first[0].state, FrameResult.State.DOUBT, "the lab cannot open the story")

func test_incomplete_lab_cascades() -> void:
	var results := logic.evaluate(board([
		fc(hospital, patient, tatiana),
		fc(lab, tatiana, null),
		fc(hospital, patient, tatiana),
	]))
	t.eq(results[1].state, FrameResult.State.NEUTRAL, "the lab without the slide is incomplete")
	t.eq(results[2].state, FrameResult.State.NEUTRAL, "a frame after an incomplete one is neutral")

func test_same_piece_on_both_sides() -> void:
	var results := logic.evaluate(board([fc(hospital, tatiana, tatiana)]))
	t.eq(results[0].state, FrameResult.State.DOUBT, "two Tatianas never form the pair")
	t.eq(results[0].moment, "", "two Tatianas match no moment")

func test_ending() -> void:
	var ending := logic.ending(solution())
	t.check(ending != null, "solved phase has an ending")
	if ending:
		t.eq(ending.frame_index, 2, "ending lands on the last frame")
		t.eq(ending.scene_variant, "default", "ending keeps the hospital")
		t.eq(ending.sounds.size(), 0, "ending has no sounds")
		t.eq([ending.left_pose, ending.right_pose], ["cured", "happy"], "ending poses")

	var swapped := board([
		fc(hospital, patient, tatiana),
		fc(lab, tatiana, slide),
		fc(hospital, tatiana, patient),
	])
	var swapped_ending := logic.ending(swapped)
	t.check(swapped_ending != null, "swapped last frame still solves")
	if swapped_ending:
		t.eq(
			[swapped_ending.left_pose, swapped_ending.right_pose],
			["happy", "cured"],
			"ending poses follow the side each piece is on"
		)

func test_ending_needs_a_solved_board() -> void:
	t.check(logic.ending(board([])) == null, "no ending without a solved board")
	t.check(logic.ending(board([fc(hospital, patient, tatiana)])) == null, "no ending from one frame")
