extends Node

# Small pool of players so overlapping effects (surprise + broken glass) don't cut each other

signal played(stream: AudioStream)

const POOL_SIZE := 6

var _players: Array[AudioStreamPlayer] = []

func _ready() -> void:
	for index in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)

func play(stream: AudioStream) -> void:
	if not stream:
		return

	var player := _players[0]
	for candidate in _players:
		if not candidate.playing:
			player = candidate
			break

	player.stream = stream
	player.play()
	played.emit(stream)

func play_all(streams: Array[AudioStream]) -> void:
	for stream in streams:
		play(stream)
