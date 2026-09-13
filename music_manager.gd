extends Node

# Pré-carrega as faixas
const MENU_THEME = preload("res://assets/audio/music/Strength%20of%20the%20Titans.mp3")
const GAME_AMBIENCE = preload("res://assets/audio/music/The%20Ice%20Giants.mp3")
const BOSS_THEME = preload("res://assets/audio/music/Aggressor.mp3") # use o nome exato do arquivo

const SFX_LEVEL_UP = preload("res://assets/audio/sfx/levelUp.wav") # confirme se o arquivo está na pasta sfx
const SFX_UI_CLICK = preload("res://assets/audio/sfx/ui_click.mp3")
const SFX_XP_GEM = preload("res://assets/audio/sfx/xp_gem.wav")
const SFX_MJOLNIR = preload("res://assets/audio/sfx/mjolnir_attack.wav")
const SFX_ZEUS_LIGHTNING = preload("res://assets/audio/sfx/zeus_lightning.ogg")
const SFX_EXCALIBUR = preload("res://assets/audio/sfx/excalibur_slash.wav")
const SFX_SOLAR_DISK = preload("res://assets/audio/sfx/solar_disk_hit.wav")
const SFX_MEDUSA_GAZE = preload("res://assets/audio/sfx/medusa_gaze.wav")
const SFX_POSEIDON_TRIDENT = preload("res://assets/audio/sfx/poseidon_trident_shoot.wav")
const SFX_PLAYER_HURT = preload("res://assets/audio/sfx/player_hurt.wav")

		
var player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer
var _music_volume_linear := 0.8
var _current_base_volume_db := -10.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	player = AudioStreamPlayer.new()
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	
	sfx_player = AudioStreamPlayer.new()
	sfx_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(sfx_player)
	_music_volume_linear = SaveManager.get_music_volume()
	
	play_menu_music()

func set_music_volume(value: float) -> void:
	_music_volume_linear = clampf(value, 0.0, 1.0)
	_apply_music_volume()

func _apply_music_volume() -> void:
	if not player:
		return
	if _music_volume_linear <= 0.001:
		player.volume_db = -80.0
	else:
		player.volume_db = _current_base_volume_db + linear_to_db(_music_volume_linear)

func play_menu_music() -> void:
	play_music(MENU_THEME, -10.0)

func play_game_music() -> void:
	play_music(GAME_AMBIENCE, -12.0)

func play_boss_music() -> void:
	play_music(BOSS_THEME, -8.0) # volume um pouco mais presente para o combate

func play_level_up_sfx() -> void:
	if sfx_player:
		sfx_player.stream = SFX_LEVEL_UP
		sfx_player.volume_db = -6.0 # volume nítido por cima da música
		sfx_player.play()
		
func play_ui_click() -> void:
	if sfx_player:
		sfx_player.stream = SFX_UI_CLICK
		sfx_player.volume_db = -2.0
		sfx_player.play()
		
func play_xp_sfx() -> void:
	if sfx_player:
		sfx_player.stream = SFX_XP_GEM
		sfx_player.volume_db = -12.0 # mais suave para não cansar o ouvido
		# Variação sutil de tom a cada coleta (efeito clássico de satisfação)
		sfx_player.pitch_scale = randf_range(0.92, 1.15)
		sfx_player.play()

func play_mjolnir_sfx() -> void:
	if sfx_player:
		sfx_player.stream = SFX_MJOLNIR
		sfx_player.volume_db = -6.0
		# Varia levemente o pitch para o martelo não soar repetitivo a cada lançamento
		sfx_player.pitch_scale = randf_range(0.95, 1.08)
		sfx_player.play()
		
func play_zeus_lightning_sfx() -> void:
	if sfx_player:
		sfx_player.stream = SFX_ZEUS_LIGHTNING
		sfx_player.volume_db = -8.0
		# Pitch mais alto (1.2 a 1.35) faz o som durar menos de 1 segundo e soar mais estridente/elétrico
		sfx_player.pitch_scale = randf_range(1.15, 1.35)
		sfx_player.play()
		
func play_excalibur_sfx() -> void:
	if sfx_player:
		sfx_player.stream = SFX_EXCALIBUR
		sfx_player.volume_db = -5.0
		sfx_player.pitch_scale = randf_range(0.95, 1.10)
		sfx_player.play()
		
func play_solar_disk_sfx() -> void:
	if sfx_player:
		sfx_player.stream = SFX_SOLAR_DISK
		sfx_player.volume_db = -10.0
		sfx_player.pitch_scale = randf_range(0.95, 1.15)
		sfx_player.play()
		
func play_medusa_sfx() -> void:
	if sfx_player:
		sfx_player.stream = SFX_MEDUSA_GAZE
		sfx_player.volume_db = -6.0
		# Aumentar o pitch acelera a reprodução e reduz a duração:
		sfx_player.pitch_scale = randf_range(1.25, 1.4)
		sfx_player.play()
		
func play_poseidon_trident_sfx() -> void:
	if sfx_player:
		sfx_player.stream = SFX_POSEIDON_TRIDENT
		sfx_player.volume_db = -12.0 # mais baixo devido à alta cadência
		sfx_player.pitch_scale = randf_range(0.92, 1.18)
		sfx_player.play()
		
func play_player_hurt_sfx() -> void:
	if sfx_player:
		sfx_player.stream = SFX_PLAYER_HURT
		sfx_player.volume_db = -4.0 # volume com presença para avisar perigo
		sfx_player.pitch_scale = randf_range(0.95, 1.05)
func play_punisher_shot_sfx() -> void:
	if sfx_player:
		sfx_player.stream = SFX_POSEIDON_TRIDENT
		sfx_player.volume_db = -8.0
		sfx_player.pitch_scale = randf_range(1.4, 1.7)
		sfx_player.play()

func play_grenade_explosion_sfx() -> void:
	if sfx_player:
		sfx_player.stream = SFX_MJOLNIR
		sfx_player.volume_db = -3.0
		sfx_player.pitch_scale = randf_range(0.65, 0.8)
		sfx_player.play()

func play_music(stream: AudioStream, volume_db: float = -10.0) -> void:
	if player == null:
		return
	_current_base_volume_db = volume_db
	_apply_music_volume()
	if player.stream == stream and player.playing:
		return
	player.stream = stream
	player.play()

func stop_music() -> void:
	if player:
		player.stop()
