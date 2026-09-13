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
	preload("res://resources/weapons/zeus_lightning_data.tres"),
	preload("res://resources/weapons/anubis_curse.tres"),
	preload("res://resources/weapons/gungnir_data.tres"),
	preload("res://resources/weapons/sumarbrander_data.tres")
]

# Armas exclusivas do Punisher — só aparecem no pool se o personagem atual for o Punisher
const PUNISHER_EXCLUSIVE_WEAPONS = [
	preload("res://resources/weapons/punisher_gun_data.tres"),
	preload("res://resources/weapons/punisher_grenade_data.tres")
]

const KRATOS_EXCLUSIVE_WEAPONS = [
	preload("res://resources/weapons/blades_of_chaos_data.tres")
]

const SHOP_WEAPON_IDS: Array[StringName] = [
	&"anubis_curse",
	&"gungnir",
	&"sumarbrander",
]

const AVAILABLE_RELICS = [
	preload("res://resources/relics/speed_relic_data.tres")
]

const EVOLUTION_RECIPES = []

var _player_weapons: Node2D
var _obtained_relics: Array[RelicData] = []
var _player: CharacterBody2D


func setup(weapon_holder: Node2D) -> void:
	_player_weapons = weapon_holder
	if weapon_holder:
		_player = weapon_holder.get_parent() as CharacterBody2D


func get_obtained_relics() -> Array[RelicData]:
	return _obtained_relics.duplicate()


func debug_grant_weapon(data: WeaponData) -> bool:
	if not data or not is_instance_valid(_player_weapons):
		return false
	var existing := _get_weapon(data.id)
	if existing:
		if existing.has_method("upgrade"):
			existing.upgrade()
		return true
	var scene_path := _resolve_weapon_scene_path(data.id)
	if not ResourceLoader.exists(scene_path):
		return false
	var scene := load(scene_path) as PackedScene
	if not scene:
		return false
	_player_weapons.add_child(scene.instantiate())
	return true


func debug_grant_relic(data: RelicData) -> bool:
	if not data or _has_relic(data.id):
		return false
	var option := UpgradeOption.new()
	option.item_data = data
	option.is_relic = true
	apply_option(option)
	return true


func debug_reset_inventory() -> void:
	_obtained_relics.clear()


func generate_options(count: int = 3) -> Array[UpgradeOption]:
	var options: Array[UpgradeOption] = []
	var pool: Array[Resource] = []
	
	# Construir o pool de possibilidades (Armas)
	var weapon_pool: Array = []
	weapon_pool.append_array(AVAILABLE_WEAPONS)
	# Inclui armas exclusivas do Punisher se for o personagem atual
	if Global.selected_character_id == &"punisher":
		weapon_pool.append_array(PUNISHER_EXCLUSIVE_WEAPONS)
	elif Global.selected_character_id == &"kratos":
		weapon_pool.append_array(KRATOS_EXCLUSIVE_WEAPONS)

	for data in weapon_pool:
		# Não oferece armas base se elas já foram evoluídas! (Simplificação: checa se está no player)
		var current_lvl := _get_weapon_level(data.id)
		if data.id in SHOP_WEAPON_IDS \
				and current_lvl == 0 \
				and not SaveManager.is_unlocked(&"weapon", data.id):
			continue
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
			var scene_path = _resolve_weapon_scene_path(option.item_data.id)
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


func _resolve_weapon_scene_path(weapon_id: StringName) -> String:
	var scene_path := "res://scenes/weapons/%s.tscn" % weapon_id
	if ResourceLoader.exists(scene_path):
		return scene_path
	
	var alt_scene_path := "res://scenes/weapons/%s.tscn" % String(weapon_id).replace("_", "")
	if ResourceLoader.exists(alt_scene_path):
		return alt_scene_path
	
	return scene_path
