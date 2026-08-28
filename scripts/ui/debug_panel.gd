extends CanvasLayer
## DebugPanel — Monitor de performance ativado por F3.

@onready var label: Label = $MarginContainer/VBoxContainer/StatsLabel

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_f3") or (event is InputEventKey and event.keycode == KEY_F3 and event.pressed):
		visible = not visible


func _process(_delta: float) -> void:
	if not visible:
		return
		
	var fps = Performance.get_monitor(Performance.TIME_FPS)
	var objects = Performance.get_monitor(Performance.OBJECT_COUNT)
	var draw_calls = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	
	label.text = "FPS: %d\nObjects: %d\nDraw Calls: %d" % [fps, objects, draw_calls]
