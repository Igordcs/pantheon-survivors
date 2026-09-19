extends Control
## StoryIntro — Introdução narrativa exibida uma única vez, antes da seleção de personagem.

## Emitido ao concluir ou pular a introdução, imediatamente antes da troca de cena.
signal intro_finished(next_scene_path: String)

const PHASE_SELECTION_SCENE := "res://scenes/ui/phase_selection.tscn"
const FADE_OUT_DURATION := 0.14
const FADE_IN_DURATION := 0.22

const PAGES := [
	{
		"title": "O VÉU SE ROMPEU",
		"body": "Por eras, o Véu separou a Terra dos domínios de Asgard, Duat, do Olimpo e de mundos esquecidos.\n\nMas uma força desconhecida abriu fendas entre as realidades.\n\nAgora monstros de diferentes mitologias atravessam para a Terra.",
		"image": "res://assets/sprites/ui/story/intro_01_veil_breaking.png",
		"fallback_color": Color(0.09, 0.07, 0.16, 1.0),
	},
	{
		"title": "OS DEUSES NÃO PODEM LUTAR",
		"body": "A presença dos deuses destruiria o que ainda resta da barreira entre os mundos.\n\nPor isso, Thor, Rá e Atena escolheram mortais para carregar fragmentos de seu poder.",
		"image": "res://assets/sprites/ui/story/intro_02_gods_choose_mortals.png",
		"fallback_color": Color(0.13, 0.09, 0.06, 1.0),
	},
	{
		"title": "OS ESCOLHIDOS",
		"body": "Eirik recebeu Mjölnir.\n\nNeferu recebeu o Disco Solar.\n\nPerseus recebeu a Cabeça de Medusa.\n\nEles são os Sobreviventes do Panteão.",
		"image": "res://assets/sprites/ui/story/intro_03_weapons_granted.png",
		"fallback_color": Color(0.12, 0.10, 0.04, 1.0),
	},
	{
		"title": "A MISSÃO",
		"body": "Três rupturas ameaçam consumir a Terra.\n\nSobreviva às hordas. Reúna os Ecos Divinos. Enfrente as criaturas que sustentam a Fenda.\n\nFeche o Véu antes que os mundos se tornem um só.",
		"image": "res://assets/sprites/ui/story/intro_04_three_rifts.png",
		"fallback_color": Color(0.07, 0.09, 0.16, 1.0),
	},
]

@onready var page_layer: Control = $PageLayer
@onready var fallback_rect: ColorRect = $PageLayer/FallbackRect
@onready var page_image: TextureRect = $PageLayer/PageImage
@onready var title_label: Label = $PageLayer/PageContent/TitleLabel
@onready var body_label: Label = $PageLayer/PageContent/BodyLabel
@onready var progress_label: Label = $Footer/ProgressLabel
@onready var back_button: Button = $Footer/ButtonsRow/BackButton
@onready var skip_button: Button = $Footer/ButtonsRow/SkipButton
@onready var next_button: Button = $Footer/ButtonsRow/NextButton

var page_index := 0

var _fade_tween: Tween
var _finished := false
var _texture_cache: Dictionary = {}


func _ready() -> void:
	MusicManager.play_menu_music()

	back_button.pressed.connect(func():
		MusicManager.play_ui_click()
		_go_to_page(page_index - 1)
	)
	skip_button.pressed.connect(func():
		MusicManager.play_ui_click()
		_finish()
	)
	next_button.pressed.connect(func():
		MusicManager.play_ui_click()
		_advance()
	)

	_apply_current_page()
	_update_footer()
	next_button.grab_focus()


func _input(event: InputEvent) -> void:
	if _finished or not is_inside_tree():
		return
	if event is InputEventKey and event.echo:
		return

	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		MusicManager.play_ui_click()
		_finish()
	elif event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		MusicManager.play_ui_click()
		_advance()
	elif event.is_action_pressed("ui_right"):
		get_viewport().set_input_as_handled()
		_navigate(1)
	elif event.is_action_pressed("ui_left"):
		get_viewport().set_input_as_handled()
		_navigate(-1)


## Avança para a próxima página ou conclui a introdução na última.
func _advance() -> void:
	if page_index >= PAGES.size() - 1:
		_finish()
		return
	_go_to_page(page_index + 1)


func _navigate(step: int) -> void:
	var target := clampi(page_index + step, 0, PAGES.size() - 1)
	if target == page_index:
		return
	MusicManager.play_ui_click()
	_go_to_page(target)


func _go_to_page(index: int) -> void:
	if _finished:
		return
	var target := clampi(index, 0, PAGES.size() - 1)
	if target == page_index:
		return
	page_index = target
	_update_footer()
	_start_page_transition()


## Fade suave entre páginas. A transição nunca bloqueia o input: navegar durante a
## animação apenas descarta o tween anterior e recomeça a partir do estado atual.
func _start_page_transition() -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(page_layer, "modulate:a", 0.0, FADE_OUT_DURATION)
	_fade_tween.tween_callback(_apply_current_page)
	_fade_tween.tween_property(page_layer, "modulate:a", 1.0, FADE_IN_DURATION)


func _apply_current_page() -> void:
	var page: Dictionary = PAGES[page_index]
	title_label.text = PixelText.fit(String(page.get("title", "")))
	body_label.text = PixelText.fit(String(page.get("body", "")))
	fallback_rect.color = page.get("fallback_color", Color(0.08, 0.06, 0.12, 1.0))
	var texture := _load_page_texture(String(page.get("image", "")))
	page_image.texture = texture
	page_image.visible = texture != null


func _update_footer() -> void:
	progress_label.text = "%d / %d" % [page_index + 1, PAGES.size()]
	var show_back := page_index > 0
	if not show_back and back_button.has_focus():
		next_button.grab_focus()
	back_button.visible = show_back
	# "É"/"Ó" maiúsculos não têm forma própria na fonte pixelada; o menu já usa
	# rótulos sem acento por esse motivo.
	next_button.text = "COMEÇAR" if page_index == PAGES.size() - 1 else "PROXIMO"


## Carrega a arte da página. Enquanto uma imagem não existir, a cena continua
## funcionando com o fundo de reserva e avisa no console.
func _load_page_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _texture_cache.has(path):
		return _texture_cache[path]

	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		texture = ResourceLoader.load(path) as Texture2D
	if texture == null:
		push_warning(
			"StoryIntro: a imagem \"%s\" não foi encontrada; a página usará o fundo de reserva." % path
		)
	_texture_cache[path] = texture
	return texture


func _finish() -> void:
	if _finished:
		return
	_finished = true
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_mark_intro_as_seen()
	intro_finished.emit(PHASE_SELECTION_SCENE)
	if is_inside_tree():
		get_tree().change_scene_to_file(PHASE_SELECTION_SCENE)


func _mark_intro_as_seen() -> void:
	if not SaveManager.set_intro_seen():
		push_warning("StoryIntro: não foi possível registrar que a introdução já foi vista.")
