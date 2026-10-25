extends SceneTree

func _initialize() -> void:
	var t := TestUtils.new()

	var ada: CharacterData = load("res://data/characters/ada.tres")
	t.check(ada != null, "ada.tres loads")
	if ada:
		for key in ["default", "pen", "pen_articles", "pile", "doubt", "laughing"]:
			t.check(ada.poses.get(key) is Texture2D, "ada pose %s" % key)
		t.eq(ada.get_pose("nao_existe"), ada.poses["default"], "pose fallback to default")

	var charles: CharacterData = load("res://data/characters/charles.tres")
	t.check(charles != null, "charles.tres loads")
	if charles:
		for key in ["default", "clipboard", "cup", "scared_cup", "laughing"]:
			t.check(charles.poses.get(key) is Texture2D, "charles pose %s" % key)

	var teapot: CharacterData = load("res://data/characters/teapot.tres")
	t.check(teapot != null and teapot.poses.get("default") is Texture2D, "teapot default")

	var office: SceneData = load("res://data/scenes/office.tres")
	t.check(office != null, "office.tres loads")
	if office:
		for key in ["default", "open_door", "papers"]:
			t.check(office.variants.get(key) is Texture2D, "office %s" % key)
		t.eq(office.get_variant("nao_existe"), office.variants["default"], "variant fallback to default")

	var kitchen: SceneData = load("res://data/scenes/kitchen.tres")
	t.check(kitchen != null and kitchen.variants.get("default") is Texture2D, "kitchen default")

	if ada and charles and teapot and office and kitchen:
		t.eq(
			[ada.id, charles.id, teapot.id, office.id, kitchen.id],
			["ada", "charles", "teapot", "office", "kitchen"],
			"ids"
		)

	var patient: CharacterData = load("res://data/characters/patient.tres")
	t.check(patient != null, "patient.tres loads")
	if patient:
		for key in ["default", "hopeful", "cured"]:
			t.check(patient.poses.get(key) is Texture2D, "patient pose %s" % key)

	var tatiana: CharacterData = load("res://data/characters/tatiana.tres")
	t.check(tatiana != null, "tatiana.tres loads")
	if tatiana:
		for key in ["default", "exams", "microscope", "syringe", "doubt", "happy"]:
			t.check(tatiana.poses.get(key) is Texture2D, "tatiana pose %s" % key)
		t.eq(tatiana.get_pose("nao_existe"), tatiana.poses["default"], "phase 2 pose fallback")

	var slide: CharacterData = load("res://data/characters/slide.tres")
	t.check(slide != null and slide.poses.get("default") is Texture2D, "slide default")

	var hospital: SceneData = load("res://data/scenes/hospital.tres")
	t.check(hospital != null and hospital.variants.get("default") is Texture2D, "hospital default")

	var lab: SceneData = load("res://data/scenes/lab.tres")
	t.check(lab != null and lab.variants.get("default") is Texture2D, "lab default")

	if patient and tatiana and slide and hospital and lab:
		t.eq(
			[patient.id, tatiana.id, slide.id, hospital.id, lab.id],
			["patient", "tatiana", "slide", "hospital", "lab"],
			"phase 2 ids"
		)

	t.finish(self)
