extends Control
## LevelUpPanel — UI para escolhas de level up. Pausa o jogo enquanto ativa.

signal option_chosen(option: UpgradeOption)

@onready var buttons_container: VBoxContainer = $Panel/VBoxContainer
var _current_options: Array[UpgradeOption] = []


func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS # Continua rodando quando pausado


func show_options(options: Array[UpgradeOption]) -> void:
	if options.is_empty():
		return
		
	_current_options = options
	
	# Limpar botões antigos
	for child in buttons_container.get_children():
		child.queue_free()
		
	# Criar novos botões
	for i in range(options.size()):
		var opt = options[i]
		var btn = Button.new()
		btn.text = opt.display_text
		btn.custom_minimum_size = Vector2(0, 60)
		btn.pressed.connect(_on_button_pressed.bind(i))
		buttons_container.add_child(btn)
		
	show()
	get_tree().paused = true


func _on_button_pressed(index: int) -> void:
	if index < 0 or index >= _current_options.size():
		return
		
	var chosen = _current_options[index]
	hide()
	get_tree().paused = false
	option_chosen.emit(chosen)
