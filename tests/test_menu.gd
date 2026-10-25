extends Node

# MenuScreen: lista de capítulos declarada, seleção e marcas de progresso.
# Roda como cena (test_menu.tscn) para os autoloads do projeto existirem

var t := TestUtils.new()

var lovelace: StoryData = load("res://data/stories/lovelace_notes.tres")

const UNCHECKED := preload("res://assets/themes/chapter_checkbox_unchecked.svg")
const CHECKED := preload("res://assets/themes/chapter_checkbox_checked.svg")
const BELL := "soundreality-bell-sound-effect-613873.mp3"
const LEFT := ComicFrame.CharacterSide.LEFT
const RIGHT := ComicFrame.CharacterSide.RIGHT

var office: SceneData = load("res://data/scenes/office.tres")
var kitchen: SceneData = load("res://data/scenes/kitchen.tres")
var ada: CharacterData = load("res://data/characters/ada.tres")
var charles: CharacterData = load("res://data/characters/charles.tres")
var teapot: CharacterData = load("res://data/characters/teapot.tres")
var played: Array[String] = []

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	SoundPlayer.played.connect(func(stream: AudioStream) -> void: played.append(stream.resource_path.get_file()))
	await test_chapter_list()
	await test_pressing_a_chapter_selects_it()
	await test_progress_marks_and_resets()
	await test_empty_stories()
	await test_back_button()
	await test_back_button_is_compact()
	await test_completing_a_chapter_returns_to_the_menu_marked()
	await test_returning_to_the_start_screen_clears_progress()
	await test_leaving_mid_ending_completes_nothing()
	await test_reentering_a_phase_starts_clean()
	t.finish(get_tree())

func new_menu(stories: Array[StoryData]) -> MenuScreen:
	var menu: MenuScreen = load("res://src/screens/menu_screen/menu_screen.tscn").instantiate()
	menu.stories = stories
	add_child(menu)
	return menu

func one_chapter() -> Array[StoryData]:
	var stories: Array[StoryData] = [lovelace]
	return stories

func rows(menu: MenuScreen) -> Array[Node]:
	return menu.phase_list.get_children()

func drop(menu: MenuScreen) -> void:
	menu.queue_free()
	await get_tree().process_frame

func test_chapter_list() -> void:
	var menu := new_menu(one_chapter())
	var buttons := rows(menu)
	t.eq(buttons.size(), 1, "one chapter row")
	t.eq(buttons[0].text, "Capítulo 1", "chapter label")
	t.eq(buttons[0].tooltip_text, "As notas de Lovelace", "tooltip is the title")
	t.eq(buttons[0].icon, UNCHECKED, "starts unchecked")
	await drop(menu)

func test_pressing_a_chapter_selects_it() -> void:
	var menu := new_menu(one_chapter())
	var selected: Array = []
	menu.phase_selected.connect(func(story: StoryData) -> void: selected.append(story))
	rows(menu)[0].pressed.emit()
	t.eq(selected, [lovelace], "pressing emits the story")
	await drop(menu)

func test_progress_marks_and_resets() -> void:
	var menu := new_menu(one_chapter())
	menu.mark_completed(lovelace)
	t.eq(rows(menu)[0].icon, CHECKED, "completed chapter is checked")

	menu.mark_completed(lovelace)
	t.eq(rows(menu).size(), 1, "marking twice keeps one row")
	t.eq(rows(menu)[0].icon, CHECKED, "marking twice stays checked")

	menu.reset_progress()
	t.eq(rows(menu)[0].icon, UNCHECKED, "reset clears the mark")
	await drop(menu)

func test_empty_stories() -> void:
	var menu := new_menu([] as Array[StoryData])
	t.eq(rows(menu).size(), 0, "no rows without stories")
	await drop(menu)

func test_back_button() -> void:
	var menu := new_menu(one_chapter())
	var backs := [0]
	menu.back_requested.connect(func() -> void: backs[0] += 1)
	menu.get_node("BackButton").pressed.emit()
	t.eq(backs[0], 1, "back button requests going back")
	await drop(menu)

# Compacto mas sem cortar o rótulo: get_combined_minimum_size é o que o texto
# e o estilo exigem, então o botão tem de ser pelo menos isso e no máximo 48px
func test_back_button_is_compact() -> void:
	var menu := new_menu(one_chapter())
	await get_tree().process_frame
	var back: Button = menu.get_node("BackButton")
	var needed := back.get_combined_minimum_size()
	t.check(back.size.x >= needed.x, "back button fits its label width")
	t.check(back.size.y >= needed.y, "back button fits its label height")
	t.check(back.size.y <= 48.0, "back button stays compact")
	await drop(menu)

# --- Integração pelo ScreenManager: menu entre a tela inicial e o jogo ---
# Os helpers abaixo são irmãos dos de test_ending.gd; precisam da árvore deste
# nó de teste, então vivem aqui em vez de em TestUtils (RefCounted, sem árvore)

func new_manager() -> ScreenManager:
	var manager: ScreenManager = load("res://src/screen_manager/screen_manager.tscn").instantiate()
	add_child(manager)
	await get_tree().process_frame
	await get_tree().process_frame
	manager.game_screen.recap_interval = 0.05
	manager.game_screen.ending_hold = 0.05
	return manager

func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func chapter_button(manager: ScreenManager) -> Button:
	return manager.menu_screen.phase_list.get_child(0)

func fill(frame: ComicFrame, scene: SceneData, left: CharacterData, right: CharacterData) -> void:
	frame.set_scene(scene)
	frame.add_character(left, LEFT)
	frame.add_character(right, RIGHT)
	await get_tree().process_frame

func solve(game: GameScreen) -> void:
	await fill(game.frames[0], office, ada, charles)
	await fill(game.frames[1], office, ada, charles)
	await fill(game.frames[2], kitchen, charles, teapot)
	await fill(game.frames[3], office, ada, charles)

func enter_chapter(manager: ScreenManager) -> void:
	manager.navigate_to(ScreenManager.Screen.MENU)
	await wait(manager.flip_duration + 0.3)
	chapter_button(manager).pressed.emit()
	await wait(manager.flip_duration + 0.3)

func test_completing_a_chapter_returns_to_the_menu_marked() -> void:
	var manager := await new_manager()
	await enter_chapter(manager)
	t.eq(manager._current_index, ScreenManager.Screen.GAME, "pressing a chapter opens the game")

	await solve(manager.game_screen)
	await wait(1.0 + manager.flip_duration)
	t.eq(manager._current_index, ScreenManager.Screen.MENU, "the ending lands on the menu")
	t.eq(chapter_button(manager).icon, CHECKED, "chapter 1 is marked")
	manager.queue_free()
	await get_tree().process_frame

func test_returning_to_the_start_screen_clears_progress() -> void:
	var manager := await new_manager()
	manager.navigate_to(ScreenManager.Screen.MENU)
	await wait(manager.flip_duration + 0.3)
	manager.menu_screen.mark_completed(lovelace)
	t.eq(chapter_button(manager).icon, CHECKED, "marked before leaving")

	manager.navigate_to(ScreenManager.Screen.START)
	await wait(manager.flip_duration + 0.3)
	t.eq(chapter_button(manager).icon, UNCHECKED, "progress is per visitor")
	manager.queue_free()
	await get_tree().process_frame

func test_leaving_mid_ending_completes_nothing() -> void:
	var manager := await new_manager()
	await enter_chapter(manager)
	# Recapitulação lenta de propósito, para o clique cair no meio dela
	manager.game_screen.recap_interval = 0.5
	await solve(manager.game_screen)
	played.clear()

	manager.game_screen.get_node("BackButton").pressed.emit()
	await wait(2.0 + manager.flip_duration)
	t.eq(manager._current_index, ScreenManager.Screen.MENU, "leaving lands on the menu")
	t.eq(chapter_button(manager).icon, UNCHECKED, "chapter is not marked")
	t.eq(played.count(BELL), 0, "no bell after leaving")
	manager.queue_free()
	await get_tree().process_frame

func test_reentering_a_phase_starts_clean() -> void:
	var manager := await new_manager()
	await enter_chapter(manager)
	var game := manager.game_screen
	await fill(game.frames[0], office, ada, charles)

	game.get_node("BackButton").pressed.emit()
	await wait(manager.flip_duration + 0.3)
	chapter_button(manager).pressed.emit()
	await wait(manager.flip_duration + 0.3)
	t.check(game.frames[0].get_content().is_empty(), "board is clean on reentry")
	t.check(game.frames[3].sprite_left.texture == null, "no pending ending applies poses")
	manager.queue_free()
	await get_tree().process_frame
