extends Node
## O epílogo só pode fechar a campanha quando a última ruptura cai, e nunca
## pode aparecer numa vitória intermediária ou numa derrota (docs/lore.md).

const RESULTS_PANEL_SCENE := "res://scenes/ui/results_panel.tscn"

var _failures: int = 0


func _ready() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	_test_middle_victory_has_no_epilogue()
	_test_final_victory_shows_epilogue()
	_test_defeat_has_no_epilogue()

	if _failures == 0:
		print("Results panel tests passed.")
	get_tree().quit(_failures)


## Vitória com próxima fase: o painel aponta para a Fenda seguinte, sem epílogo.
func _test_middle_victory_has_no_epilogue() -> void:
	var panel := _make_panel()
	panel.show_results(true, {
		"phase_name": "Campos da Ruptura",
		"next_phase_name": "Ruínas do Conflito",
		"bosses_defeated": 1,
		"anchor_count": 1,
	}, "05:00", 120)

	if panel.epilogue_label.visible:
		_fail("A mid-campaign victory should not show the epilogue.")
	if panel.epilogue_separator.visible:
		_fail("The epilogue separator should stay hidden mid-campaign.")
	if panel.title_label.text != "RUPTURA SELADA":
		_fail("A mid-campaign victory should keep the sealed-rupture title.")
	if "Ruínas do Conflito" not in panel.phase_label.text:
		_fail("A mid-campaign victory should announce the next phase.")
	panel.free()


## Vitória sem próxima fase: a campanha inicial terminou.
func _test_final_victory_shows_epilogue() -> void:
	var panel := _make_panel()
	panel.show_results(true, {
		"phase_name": "Fronteira do Fim",
		"next_phase_name": "",
		"bosses_defeated": 3,
		"anchor_count": 3,
	}, "18:30", 900)

	if not panel.epilogue_label.visible:
		_fail("Sealing the last rupture should show the epilogue.")
	if not panel.epilogue_separator.visible:
		_fail("The epilogue separator should appear with the epilogue.")
	if panel.epilogue_label.text.strip_edges().is_empty():
		_fail("The epilogue should carry text.")
	if panel.title_label.text != PixelText.fit("O VÉU RESISTE"):
		_fail("The final victory should use the campaign-closing title.")
	# O fecho precisa deixar claro que a história continua.
	if "Por enquanto" not in panel.epilogue_label.text:
		_fail("The epilogue should make clear the story is not over.")
	# A linha da fase não repete o fecho que o epílogo já dá.
	if "campanha" in panel.phase_label.text.to_lower():
		_fail("The phase line should not duplicate the epilogue's closing.")
	panel.free()


func _test_defeat_has_no_epilogue() -> void:
	var panel := _make_panel()
	panel.show_results(false, {
		"phase_name": "Fronteira do Fim",
		"next_phase_name": "",
		"bosses_defeated": 1,
		"anchor_count": 3,
	}, "07:10", 300)

	if panel.epilogue_label.visible:
		_fail("A defeat must never show the campaign epilogue.")
	if panel.title_label.text != "DERROTA":
		_fail("A defeat should be labelled as such.")
	panel.free()


func _make_panel() -> Control:
	var panel := (load(RESULTS_PANEL_SCENE) as PackedScene).instantiate() as Control
	add_child(panel)
	return panel


func _fail(message: String) -> void:
	_failures += 1
	push_error("Results panel test: %s" % message)
