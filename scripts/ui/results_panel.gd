extends Control
## ResultsPanel — Tela mostrada no Game Over (Vitória ou Derrota).

@onready var title_label: Label = $CenterContainer/Panel/VBoxContainer/TitleLabel
@onready var time_label: Label = $CenterContainer/Panel/VBoxContainer/StatsGrid/TimeValue
@onready var coins_label: Label = $CenterContainer/Panel/VBoxContainer/StatsGrid/CoinsValue
@onready var kills_label: Label = $CenterContainer/Panel/VBoxContainer/StatsGrid/KillsValue
@onready var bosses_label: Label = $CenterContainer/Panel/VBoxContainer/StatsGrid/BossesValue

@onready var restart_button: Button = $CenterContainer/Panel/VBoxContainer/RestartButton
@onready var phase_label: Label = $CenterContainer/Panel/VBoxContainer/PhaseLabel
@onready var epilogue_label: Label = $CenterContainer/Panel/VBoxContainer/EpilogueLabel
@onready var epilogue_separator: ColorRect = $CenterContainer/Panel/VBoxContainer/EpilogueSeparator

## Fecho da campanha inicial: recapitula as três rupturas e deixa a origem da
## Fenda em aberto, como descrito em docs/lore.md.
const EPILOGUE_TEXT := "Três Fendas foram seladas.

A primeira apenas vazava. A segunda trouxe um exército que decidiu ficar. A terceira trouxe o fim do mundo, e errou de mundo.

Nenhuma delas explicou o que rachou o Véu. As feras atravessaram porque o caminho estava aberto — e alguém o abriu.

O Véu resiste. Por enquanto."


func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	restart_button.pressed.connect(_on_restart_pressed)


func show_results(is_victory: bool, stats: Dictionary, time_str: String, kills: int) -> void:
	# Sem próxima fase depois de uma vitória, a campanha inicial acabou.
	var campaign_complete := is_victory \
		and String(stats.get("next_phase_name", "")).is_empty()

	if campaign_complete:
		title_label.text = PixelText.fit("O VÉU RESISTE")
		title_label.modulate = Color(1, 0.8, 0.2)
	elif is_victory:
		title_label.text = "RUPTURA SELADA"
		title_label.modulate = Color(1, 0.8, 0.2) # Gold
	else:
		title_label.text = "DERROTA"
		title_label.modulate = Color(0.8, 0.2, 0.2) # Red
	_update_phase_line(is_victory, stats)
	_update_epilogue(campaign_complete)

	time_label.text = time_str
	coins_label.text = str(stats.get("coins_collected", 0))
	kills_label.text = str(kills)
	bosses_label.text = str(stats.get("bosses_defeated", 0))
	
	show()


## Fecha o ciclo narrativo da fase: qual ruptura caiu e qual foi detectada em seguida.
func _update_phase_line(is_victory: bool, stats: Dictionary) -> void:
	if phase_label == null:
		return
	var phase_name := String(stats.get("phase_name", ""))
	if phase_name.is_empty():
		phase_label.visible = false
		return
	if is_victory:
		var next_name := String(stats.get("next_phase_name", ""))
		# Na última fase o epílogo assume o fecho; aqui fica só a ruptura que caiu.
		phase_label.text = "%s foi selada.
Uma nova Fenda responde ao chamado: %s." % [
			phase_name, next_name,
		] if not next_name.is_empty() else "%s foi selada." % phase_name
	else:
		var defeated := int(stats.get("bosses_defeated", 0))
		var total := int(stats.get("anchor_count", 0))
		phase_label.text = "%s resiste.
Âncoras derrubadas: %d de %d." % [phase_name, defeated, total]
	phase_label.visible = true


## O epílogo só aparece quando a última ruptura cai; nas demais ele fica fora.
func _update_epilogue(campaign_complete: bool) -> void:
	if epilogue_label == null or epilogue_separator == null:
		return
	epilogue_label.text = PixelText.fit(EPILOGUE_TEXT) if campaign_complete else ""
	epilogue_label.visible = campaign_complete
	epilogue_separator.visible = campaign_complete


func _on_restart_pressed() -> void:
	MusicManager.play_menu_music()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
