extends SceneTree

var t := TestUtils.new()
var logic: StoryLogic

var office: SceneData = load("res://data/scenes/office.tres")
var kitchen: SceneData = load("res://data/scenes/kitchen.tres")
var ada: CharacterData = load("res://data/characters/ada.tres")
var charles: CharacterData = load("res://data/characters/charles.tres")
var teapot: CharacterData = load("res://data/characters/teapot.tres")

func _initialize() -> void:
	logic = LovelaceLogic.new()

	test_solution_moments()
	test_moment_backgrounds_and_poses()
	test_swapped_sides()
	test_incomplete_frames_are_neutral()
	test_neutral_cascades()
	test_removing_character_cascades()
	test_doubt_cases()
	test_doubt_propagates()
	test_wrong_frame_is_not_solved()
	test_ending()

	t.finish(self)

func fc(scene: SceneData, left: CharacterData, right: CharacterData) -> FrameContent:
	return FrameContent.new(scene, left, right)

func board(frames: Array) -> Array[FrameContent]:
	var result: Array[FrameContent] = []
	for frame in frames:
		result.append(frame)
	while result.size() < 4:
		result.append(fc(null, null, null))
	return result

func solution() -> Array[FrameContent]:
	return board([
		fc(office, ada, charles),
		fc(office, ada, charles),
		fc(kitchen, charles, teapot),
		fc(office, ada, charles),
	])

func swapped_solution() -> Array[FrameContent]:
	return board([
		fc(office, charles, ada),
		fc(office, charles, ada),
		fc(kitchen, teapot, charles),
		fc(office, charles, ada),
	])

func moments(results: Array[FrameResult]) -> Array:
	return results.map(func(r: FrameResult) -> String: return r.moment)

func states(results: Array[FrameResult]) -> Array:
	return results.map(func(r: FrameResult) -> int: return r.state)

const N := FrameResult.State.NEUTRAL
const C := FrameResult.State.COHERENT
const D := FrameResult.State.DOUBT

func test_solution_moments() -> void:
	var results := logic.evaluate(solution())
	t.eq(moments(results), ["M1", "M2", "M3", "M4"], "solution moments")
	t.eq(states(results), [C, C, C, C], "solution states")
	t.check(logic.is_solved(solution()), "solution is solved")

func test_moment_backgrounds_and_poses() -> void:
	var r := logic.evaluate(solution())
	t.eq([r[0].scene_variant, r[0].left_pose, r[0].right_pose], ["default", "pen", "clipboard"], "M1 visuals")
	t.eq([r[1].scene_variant, r[1].left_pose, r[1].right_pose], ["open_door", "pen_articles", "default"], "M2 visuals")
	t.eq([r[2].scene_variant, r[2].left_pose, r[2].right_pose], ["default", "cup", "default"], "M3 visuals")
	t.eq([r[3].scene_variant, r[3].left_pose, r[3].right_pose], ["papers", "pile", "scared_cup"], "M4 visuals")
	for result in r:
		t.check(not result.show_doubt_icon, "no doubt icon on coherent frame")

func test_swapped_sides() -> void:
	var r := logic.evaluate(swapped_solution())
	t.eq(moments(r), ["M1", "M2", "M3", "M4"], "swapped moments")
	t.eq([r[0].left_pose, r[0].right_pose], ["clipboard", "pen"], "swapped M1 poses")
	t.eq([r[2].left_pose, r[2].right_pose], ["default", "cup"], "swapped M3 poses")
	t.check(logic.is_solved(swapped_solution()), "swapped solution is solved")

func test_incomplete_frames_are_neutral() -> void:
	t.eq(logic.evaluate(board([fc(office, null, null)]))[0].state, N, "scene only")
	t.eq(logic.evaluate(board([fc(office, ada, null)]))[0].state, N, "one character")
	t.eq(logic.evaluate(board([fc(null, ada, charles)]))[0].state, N, "characters without scene")

	var empty := logic.evaluate(board([]))
	t.eq(states(empty), [N, N, N, N], "empty board")
	for result in empty:
		t.eq([result.scene_variant, result.left_pose, result.right_pose], ["default", "default", "default"], "neutral visuals")
		t.check(not result.show_doubt_icon, "neutral has no doubt icon")

func test_neutral_cascades() -> void:
	var r := logic.evaluate(board([fc(null, null, null), fc(office, ada, charles)]))
	t.eq(r[1].state, N, "Q2 neutral after empty Q1")

	r = logic.evaluate(board([fc(office, null, null), fc(office, ada, charles)]))
	t.eq(r[1].state, N, "Q2 neutral after scene-only Q1")

	r = logic.evaluate(board([fc(office, ada, null), fc(office, ada, charles), fc(kitchen, charles, teapot)]))
	t.eq([r[1].state, r[2].state], [N, N], "neutral cascades to Q2 and Q3")

func test_removing_character_cascades() -> void:
	var frames := solution()
	logic.evaluate(frames)
	frames[0].right = null
	t.eq(states(logic.evaluate(frames)), [N, N, N, N], "removing Charles from Q1 neutralizes all")

func test_doubt_cases() -> void:
	var r := logic.evaluate(board([fc(kitchen, ada, charles)]))
	t.eq(r[0].state, D, "Ada and Charles in kitchen")
	t.eq([r[0].left_pose, r[0].right_pose], ["doubt", "default"], "doubt poses")
	t.check(r[0].show_doubt_icon, "doubt icon")
	t.eq(r[0].moment, "", "doubt has no moment")

	r = logic.evaluate(board([fc(office, ada, charles), fc(kitchen, charles, teapot)]))
	t.eq(r[1].state, D, "kitchen right after M1")

	r = logic.evaluate(board([fc(office, ada, charles), fc(office, ada, charles), fc(office, ada, charles)]))
	t.eq(r[2].state, D, "office after M2 skips kitchen")

	r = logic.evaluate(board([fc(office, ada, ada)]))
	t.eq(r[0].state, D, "same character on both sides")

	r = logic.evaluate(board([fc(kitchen, charles, teapot)]))
	t.eq(r[0].state, D, "kitchen in Q1")
	t.eq([r[0].left_pose, r[0].right_pose], ["default", "default"], "doubt without Ada keeps defaults")

func test_doubt_propagates() -> void:
	var r := logic.evaluate(board([fc(kitchen, ada, charles), fc(office, ada, charles)]))
	t.eq(r[1].state, D, "office after doubtful frame")

func test_wrong_frame_is_not_solved() -> void:
	var frames := solution()
	frames[2] = fc(office, ada, charles)
	t.check(not logic.is_solved(frames), "wrong Q3 is not solved")
	t.check(not logic.is_solved(board([])), "empty board is not solved")

func test_ending() -> void:
	var ending := logic.ending(solution())
	t.check(ending != null, "ending exists when solved")
	if ending:
		t.eq(ending.frame_index, 3, "ending frame")
		t.eq(ending.scene_variant, "papers", "ending background")
		t.eq([ending.left_pose, ending.right_pose], ["laughing", "laughing"], "ending poses")
		t.eq(ending.sounds.size(), 2, "ending sounds")

	var swapped := logic.ending(swapped_solution())
	t.check(swapped != null and swapped.left_pose == "laughing" and swapped.right_pose == "laughing", "swapped ending poses")
	t.check(logic.ending(board([])) == null, "no ending when unsolved")
