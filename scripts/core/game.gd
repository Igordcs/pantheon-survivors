extends Node2D
## Game — cena raiz da run.

@onready var player := $World/Player
@onready var upgrade_system := $UpgradeSystem
@onready var level_up_panel := $CanvasLayer/LevelUpPanel
@onready var hud := $CanvasLayer/HUD
@onready var spawn_director := $SpawnDirector
@onready var enemy_spawner := $EnemySpawner
@onready var run_manager := $RunManager
@onready var results_panel := $CanvasLayer/ResultsPanel
@onready var pause_panel := $CanvasLayer/PausePanel
@onready var world_generator: WorldGenerator = $World/Environment
@onready var game_camera: GameCameraController = $World/Player/Camera2D

var _active_boss: Node2D


func _ready() -> void:
	print("Pantheon Survivors — Game started")
	
	if not player:
		push_error("Game: Player node not found at World/Player!")
		return
	if not world_generator.initial_spawn_position.is_equal_approx(player.global_position):
		world_generator.initial_spawn_position = player.global_position
		world_generator.generate_world()
	world_generator.setup(player)
	player.setup_world_generator(world_generator)
	
	# Setup do UpgradeSystem com a referência das armas do Player
	var weapon_holder := player.get_node_or_null("WeaponHolder") as Node2D
	upgrade_system.setup(weapon_holder)
	pause_panel.setup(player, upgrade_system)
	enemy_spawner.setup_world_generator(world_generator)
	
	# Conectar os sinais do HUD
	var exp_comp := player.get_node_or_null("ExperienceComponent") as ExperienceComponent
	if exp_comp:
		exp_comp.level_up.connect(_on_player_level_up)
		exp_comp.experience_changed.connect(hud.update_xp)
		hud.update_xp(exp_comp.current_xp, exp_comp.xp_for_next_level())
		
	var health_comp := player.get_node_or_null("HealthComponent") as HealthComponent
	if health_comp:
		health_comp.health_changed.connect(hud.update_hp)
		health_comp.died.connect(_on_player_died)
		hud.update_hp(health_comp.current_health, health_comp.max_health)
		
	# Adicionar armas iniciais ao HUD
	if weapon_holder:
		for child in weapon_holder.get_children():
			if child.has_method("get_weapon_id"):
				hud.add_weapon_icon(child.get_weapon_id())
		
	level_up_panel.option_chosen.connect(_on_upgrade_option_chosen)
	spawn_director.time_updated.connect(hud.update_time)
	spawn_director.horde_event_started.connect(hud.show_horde_event)
	enemy_spawner.kill_scored.connect(hud.add_kill)
	
	# Conectar RunManager
	run_manager.boss_spawned.connect(_on_boss_spawned)
	run_manager.run_ended.connect(_on_run_ended)
	run_manager.boss_fight_started.connect(_on_boss_fight_started)
	run_manager.boss_fight_ended.connect(_on_boss_fight_ended)
	run_manager.boss_warning_started.connect(hud.show_boss_warning)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		print("DEBUG: Executando Stress Test (1000 inimigos)!")
		for i in range(1000):
			enemy_spawner._active_count -= 1 # Burla o limite para o teste
			enemy_spawner._on_spawn_timer_timeout()


func _on_boss_spawned(boss_node: Node2D) -> void:
	_active_boss = boss_node
	var boss_health = boss_node.get_node_or_null("HealthComponent") as HealthComponent
	if boss_health:
		boss_health.health_changed.connect(hud.update_boss_hp)
		hud.show_boss_bar(boss_health.max_health)
	
	# Conectar morte para dropar o baú
	if boss_node.has_signal("died"):
		boss_node.died.connect(_on_boss_died_for_chest.bind(boss_node))


func _on_boss_died_for_chest(boss_node: Node2D) -> void:
	var chest_scene = preload("res://scenes/pickups/chest.tscn")
	var chest = chest_scene.instantiate() as Chest
	chest.global_position = boss_node.global_position
	chest.collected.connect(_on_chest_collected)
	$World.add_child(chest)
	# Oculta a barra do boss
	hud.boss_bar.hide()


func _on_chest_collected(_chest: Chest) -> void:
	var recipe = upgrade_system.check_evolutions()
	if recipe:
		print("Evolução Divina Encontrada: ", recipe.evolved_weapon.display_name)
		# Não aplica aqui, aplica só quando o usuário clicar no botão!
		var opt = UpgradeOption.new()
		opt.item_data = recipe.evolved_weapon
		opt.is_new_weapon = true
		opt.display_text = "EVOLUÇÃO DIVINA: %s" % recipe.evolved_weapon.display_name
		opt.description_text = recipe.evolved_weapon.description
		level_up_panel.show_options([opt])
	else:
		print("Nenhuma evolução disponível. Você encontrou Ouro!")
		run_manager.complete_boss_reward()


func _on_run_ended(is_victory: bool, stats: Dictionary) -> void:
	results_panel.show_results(is_victory, stats, hud.time_label.text, hud._kills)


func _on_player_died() -> void:
	print("Game Over!")
	run_manager.trigger_defeat()


func _on_player_level_up(new_level: int) -> void:
	hud.update_level(new_level)
	var options = upgrade_system.generate_options(3)
	if options.is_empty():
		return
	level_up_panel.show_options(options)


func _on_upgrade_option_chosen(option: UpgradeOption) -> void:
	if option.display_text.begins_with("EVOLUÇÃO"):
		var recipe = upgrade_system.check_evolutions()
		if recipe:
			upgrade_system.apply_evolution(recipe)
			hud.add_weapon_icon(recipe.evolved_weapon.id)
			run_manager.complete_boss_reward()
		return
		
	upgrade_system.apply_option(option)
	if option.item_data is WeaponData:
		hud.add_weapon_icon(option.item_data.id)
	elif option.item_data is RelicData:
		# Poderíamos adicionar ícones de relíquia no HUD também, por ora usamos o mesmo container
		hud.add_weapon_icon(option.item_data.id)


func _on_boss_fight_started(_boss_pos: Vector2) -> void:
	if is_instance_valid(_active_boss):
		game_camera.focus_boss(_active_boss)


func _on_boss_fight_ended() -> void:
	game_camera.release_boss()
	_active_boss = null
