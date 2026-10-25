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

	t.finish(self)
