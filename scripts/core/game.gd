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
@onready var damage_feedback: DamageFeedback = $CanvasLayer/DamageFeedback
@onready var world_generator: WorldGenerator = $World/Environment
@onready var game_camera: GameCameraController = $World/Player/Camera2D
@onready var loot_manager: LootManager = $LootManager
@onready var sandbox_controller := $SandboxController

var _active_boss: Node2D
var _coins_collected_this_run: int = 0


func _ready() -> void:
	for registry_error in ContentRegistry.validate():
		push_error("ContentRegistry: %s" % registry_error)
	for item_error in ItemCatalog.validate():
		push_error("ItemCatalog: %s" % item_error)
	MusicManager.play_game_music()
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
		health_comp.damaged.connect(_on_player_damaged)
		hud.update_hp(health_comp.current_health, health_comp.max_health)
	var pickup_area := player.get_node_or_null("PickupArea")
	if pickup_area and pickup_area.has_signal("currency_collected"):
		pickup_area.connect("currency_collected", _on_currency_collected)
	hud.update_coins(0)
		
	# Adicionar armas iniciais ao HUD
	if weapon_holder:
		for child in weapon_holder.get_children():
			if child.has_method("get_weapon_id"):
				var weapon_data := child.weapon_data as WeaponData if "weapon_data" in child else null
				if weapon_data:
					hud.add_weapon_icon(weapon_data.id, weapon_data.icon, weapon_data.display_name)
				else:
					hud.add_weapon_icon(child.get_weapon_id())
	for item_id in SaveManager.get_equipped_items():
		var equipped_item := ItemCatalog.get_item(item_id)
		if equipped_item:
			hud.add_weapon_icon(equipped_item.id, equipped_item.icon, equipped_item.display_name)
		
	level_up_panel.option_chosen.connect(_on_upgrade_option_chosen)
	spawn_director.time_updated.connect(hud.update_time)
	spawn_director.horde_event_started.connect(hud.show_horde_event)
	enemy_spawner.kill_scored.connect(hud.add_kill)
	enemy_spawner.enemy_defeated.connect(
		func(position: Vector2): loot_manager.handle_defeat(position, LootManager.Source.REGULAR_ENEMY)
	)
	enemy_spawner.enemy_defeated.connect(_on_regular_enemy_defeated_for_items)
	
	# Conectar RunManager
	run_manager.boss_spawned.connect(_on_boss_spawned)
	run_manager.run_ended.connect(_on_run_ended)
	run_manager.boss_fight_started.connect(_on_boss_fight_started)
	run_manager.boss_fight_ended.connect(_on_boss_fight_ended)
	run_manager.boss_warning_started.connect(hud.show_boss_warning)
	run_manager.anchor_progress_changed.connect(hud.update_anchor_progress)
	if Global.sandbox_mode:
		spawn_director.set_progression_paused(true)
		enemy_spawner.stop_spawning()
		sandbox_controller.setup(self, player, upgrade_system, hud)
	else:
		sandbox_controller.queue_free()


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
		hud.show_boss_bar(_resolve_boss_name(boss_node), boss_health.max_health)
	
	# Conectar morte para dropar o baú
	if boss_node.has_signal("died"):
		boss_node.died.connect(_on_boss_died_for_chest.bind(boss_node))
		boss_node.died.connect(_on_boss_defeated_for_items)
		boss_node.died.connect(
			func(): loot_manager.handle_defeat(boss_node.global_position, LootManager.Source.BOSS)
		)


## O nome mostrado na barra vem do encontro em curso; o nó é o último recurso.
func _resolve_boss_name(boss_node: Node2D) -> String:
	var encounters: Array = run_manager.boss_encounters
	var index: int = run_manager._current_encounter_index
	if index >= 0 and index < encounters.size():
		var encounter: BossEncounterData = encounters[index]
		if not encounter.display_name.is_empty():
			return encounter.display_name
	return boss_node.name


func _on_boss_died_for_chest(boss_node: Node2D) -> void:
	var chest_scene = preload("res://scenes/pickups/chest.tscn")
	var chest = chest_scene.instantiate() as Chest
	chest.global_position = boss_node.global_position
	chest.collected.connect(_on_chest_collected)
	$World.add_child(chest)
	# Oculta a barra do boss
	hud.hide_boss_bar()


func _on_chest_collected(_chest: Chest) -> void:
	print("Baú coletado.")
	run_manager.complete_boss_reward()


func _on_run_ended(is_victory: bool, stats: Dictionary) -> void:
	stats["coins_collected"] = _coins_collected_this_run
	results_panel.show_results(is_victory, stats, hud.time_label.text, hud._kills)


func _on_currency_collected(amount: int) -> void:
	_coins_collected_this_run += amount
	hud.update_coins(_coins_collected_this_run)


func _on_regular_enemy_defeated_for_items(_position: Vector2) -> void:
	var controller := player.get_node_or_null("ItemEffectController") as ItemEffectController
	if controller:
		controller.notify_enemy_defeated()


func _on_boss_defeated_for_items() -> void:
	var controller := player.get_node_or_null("ItemEffectController") as ItemEffectController
	if controller:
		controller.notify_enemy_defeated()


func _on_player_died() -> void:
	print("Game Over!")
	run_manager.trigger_defeat()


func _on_player_damaged(amount: float, _source_position: Vector2) -> void:
	damage_feedback.flash_damage(amount)


func _on_player_level_up(new_level: int) -> void:
	MusicManager.play_level_up_sfx()
	hud.update_level(new_level)
	var options = upgrade_system.generate_options(3)
	if options.is_empty():
		return
	level_up_panel.show_options(options)


func _on_upgrade_option_chosen(option: UpgradeOption) -> void:
	upgrade_system.apply_option(option)
	if option.item_data is WeaponData:
		var weapon_data := option.item_data as WeaponData
		hud.add_weapon_icon(weapon_data.id, weapon_data.icon, weapon_data.display_name)
	elif option.item_data is ItemData:
		var item_data := option.item_data as ItemData
		var controller := player.get_node_or_null("ItemEffectController") as ItemEffectController
		var item_level := controller.get_item_level(item_data.id) if controller else 1
		hud.add_weapon_icon(
			item_data.id,
			item_data.icon,
			"%s — Nível %d" % [item_data.display_name, item_level]
		)


func _on_boss_fight_started(_boss_pos: Vector2) -> void:
	MusicManager.play_boss_music()
	if is_instance_valid(_active_boss):
		game_camera.focus_boss(_active_boss)


func _on_boss_fight_ended() -> void:
	MusicManager.play_game_music()
	game_camera.release_boss()
	_active_boss = null
