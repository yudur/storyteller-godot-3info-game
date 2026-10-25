extends Node

# MenuScreen: lista de capítulos declarada, seleção e marcas de progresso.
# Roda como cena (test_menu.tscn) para os autoloads do projeto existirem

var t := TestUtils.new()

var lovelace: StoryData = load("res://data/stories/lovelace_notes.tres")

const UNCHECKED := preload("res://assets/themes/chapter_checkbox_unchecked.svg")
const CHECKED := preload("res://assets/themes/chapter_checkbox_checked.svg")

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	await test_chapter_list()
	await test_pressing_a_chapter_selects_it()
	await test_progress_marks_and_resets()
	await test_empty_stories()
	await test_back_button()
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
