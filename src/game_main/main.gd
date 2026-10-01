extends Control


func _ready() -> void:
	SignalBus.frame_changed.connect(_on_story_changed)
	
# This function runs every time any frame of the game changes.
func _on_story_changed() -> void:
	print("a hisotria mudou")
	
	# Here we will loop through the frames to read the history state.
	var index = 1
	for frame in $ComicGrid.get_children():
		if frame is ComicFrame:
			var cena = frame.current_scene.id if frame.current_scene else "Vazio"
			var heroi = frame.character_left.id if frame.character_left else "Ninguém"
			print("Quadro %d -> Cena: %s | Personagem: %s" % [index, cena, heroi])
			index += 1
