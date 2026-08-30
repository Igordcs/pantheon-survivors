extends Node
class_name UpgradeSystem
## Gerencia as opções de upgrade e aplica as escolhas do jogador.

# Lista hardcoded das armas e relíquias disponíveis
const AVAILABLE_WEAPONS = [
	preload("res://resources/weapons/mjolnir_data.tres"),
	preload("res://resources/weapons/excalibur_data.tres"),
	preload("res://resources/weapons/solar_disk_data.tres"),
	preload("res://resources/weapons/poseidon_trident_data.tres"),
	preload("res://resources/weapons/medusa_head_data.tres"),
	preload("res://resources/weapons/zeus_lightning_data.tres")
]

const AVAILABLE_RELICS = [
	preload("res://resources/relics/thor_relic_data.tres"),
	preload("res://resources/relics/speed_relic_data.tres")
]

const EVOLUTION_RECIPES = [
	preload("res://resources/evolutions/mjolnir_evolution.tres")
]

var _player_weapons: Node2D
var _obtained_relics: Array[RelicData] = []
var _player: CharacterBody2D


func setup(weapon_holder: Node2D) -> void:
	_player_weapons = weapon_holder
	if weapon_holder:
		_player = weapon_holder.get_parent() as CharacterBody2D


func get_obtained_relics() -> Array[RelicData]:
	return _obtained_relics.duplicate()


func generate_options(count: int = 3) -> Array[UpgradeOption]:
	var options: Array[UpgradeOption] = []
	var pool: Array[Resource] = []
	
	# Construir o pool de possibilidades (Armas)
	for data in AVAILABLE_WEAPONS:
		# Não oferece armas base se elas já foram evoluídas! (Simplificação: checa se está no player)
		var current_lvl := _get_weapon_level(data.id)
		# Só adiciona no pool se não tem a arma, ou se tem e não tá no level maximo
		if current_lvl < data.max_level:
			# Mas pera, se ela foi evoluída, current_lvl é 0 (pois não está equipada com o ID original)
			# Porém, o max_level de armas normais é 8, então ela entraria de novo.
			# Idealmente teríamos uma lista de "armas evoluídas" pra bloquear a base.
			# Simplificação: se level 0 (nova arma), só adiciona se tiver slot (vamos ignorar slots por agora).
			pool.append(data)
			
	# Construir o pool de possibilidades (Relíquias)
	for relic in AVAILABLE_RELICS:
		if not _has_relic(relic.id):
			pool.append(relic)
			
	# Escolher até 'count' opções sem duplicatas
	pool.shuffle()
	var to_pick = mini(count, pool.size())
	
	for i in range(to_pick):
		var data = pool[i]
		var opt := UpgradeOption.new()
		opt.item_data = data
		
		if data is WeaponData:
			opt.is_relic = false
			var current_lvl := _get_weapon_level(data.id)
			if current_lvl == 0:
				opt.is_new_weapon = true
				opt.current_level = 0
				opt.display_text = "Nova Arma: %s" % data.display_name
				opt.description_text = data.description
			else:
				opt.is_new_weapon = false
				opt.current_level = current_lvl
				opt.display_text = "Upgrade: %s Lv %d" % [data.display_name, current_lvl + 1]
				var weapon := _get_weapon(data.id)
				if weapon and weapon.has_method("get_next_upgrade_description"):
					opt.description_text = weapon.get_next_upgrade_description()
				else:
					opt.description_text = data.get_level_description(current_lvl + 1)
		elif data is RelicData:
			opt.is_relic = true
			opt.display_text = "Relíquia: %s" % data.display_name
			opt.description_text = data.description
			
		options.append(opt)
		
	return options


func apply_option(option: UpgradeOption) -> void:
	if option.is_relic:
		_obtained_relics.append(option.item_data as RelicData)
		print("Relíquia obtida: ", option.item_data.display_name)
		# Efeitos passivos poderiam ser aplicados aqui
		if option.item_data.id == &"speed_relic" and _player:
			_player.speed += 20.0
	else:
		if not is_instance_valid(_player_weapons):
			return
			
		if option.is_new_weapon:
			# Instanciar nova arma
			var scene_path = "res://scenes/weapons/%s.tscn" % option.item_data.id
			if ResourceLoader.exists(scene_path):
				var weapon_scene = load(scene_path) as PackedScene
				if weapon_scene:
					var weapon_inst = weapon_scene.instantiate()
					_player_weapons.add_child(weapon_inst)
		else:
			# Fazer upgrade da arma existente
			for child in _player_weapons.get_children():
				if child.has_method("get_weapon_id") and child.get_weapon_id() == option.item_data.id:
					if child.has_method("upgrade"):
						child.upgrade()
					break


func check_evolutions() -> EvolutionRecipe:
	# Retorna a primeira receita válida
	for recipe in EVOLUTION_RECIPES:
		if not _has_relic(recipe.required_relic.id):
			continue
			
		var weapon_lvl = _get_weapon_level(recipe.base_weapon.id)
		if weapon_lvl == 0:
			continue
			
		if recipe.require_max_weapon_level and weapon_lvl < recipe.base_weapon.max_level:
			continue
			
		return recipe
		
	return null


func apply_evolution(recipe: EvolutionRecipe) -> void:
	# Remove arma base
	for child in _player_weapons.get_children():
		if child.has_method("get_weapon_id") and child.get_weapon_id() == recipe.base_weapon.id:
			child.queue_free()
			break
			
	# Instancia arma evoluída
	var scene_path = "res://scenes/weapons/%s.tscn" % recipe.evolved_weapon.id
	if ResourceLoader.exists(scene_path):
		var weapon_scene = load(scene_path) as PackedScene
		if weapon_scene:
			var weapon_inst = weapon_scene.instantiate()
			_player_weapons.add_child(weapon_inst)


func _has_relic(relic_id: StringName) -> bool:
	for r in _obtained_relics:
		if r.id == relic_id:
			return true
	return false


func _get_weapon_level(weapon_id: StringName) -> int:
	var weapon := _get_weapon(weapon_id)
	if weapon:
		if weapon.has_method("get_current_level"):
			return weapon.get_current_level()
		return 1
	return 0


func _get_weapon(weapon_id: StringName) -> Node:
	if not is_instance_valid(_player_weapons):
		return null
	for child in _player_weapons.get_children():
		if child.has_method("get_weapon_id") and child.get_weapon_id() == weapon_id:
			return child
	return null
