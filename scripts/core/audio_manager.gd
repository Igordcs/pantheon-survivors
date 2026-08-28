extends Node
## AudioManager — Toca SFX e BGM.

@onready var bgm_player: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var sfx_players: Array[AudioStreamPlayer] = []

const MAX_SFX_PLAYERS = 8

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	add_child(bgm_player)
	bgm_player.bus = "Music"
	
	for i in range(MAX_SFX_PLAYERS):
		var p = AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		sfx_players.append(p)


func play_sfx(sound_name: String) -> void:
	# Como não temos arquivos, vamos apenas logar ou dar um bip via pitch
	# print("AUDIO: Playing SFX -> ", sound_name)
	pass


func play_bgm(track_name: String) -> void:
	# print("AUDIO: Playing BGM -> ", track_name)
	pass
