extends Node
class_name UpgradeSystem
## Gerencia as opções de upgrade e aplica as escolhas do jogador.

const EIRIK_WEAPON_IDS: Array[StringName] = [&"gungnir", &"mjolnir", &"sumarbrander", &"gjallarhorn"]
const NEFERU_WEAPON_IDS: Array[StringName] = [&"anubis_curse", &"horusfeather", &"solar_disk", &"khepris_scarab"]
const PERSEUS_WEAPON_IDS: Array[StringName] = [&"medusa_head", &"poseidon_trident", &"zeus_lightning", &"apollos_lyre"]

const ARTHUR_WEAPON_IDS: Array[StringName] = [&"excalibur", &"avalon_shield"]

const PUNISHER_EXCLUSIVE_WEAPON_IDS: Array[StringName] = [&"punisher_gun", &"punisher_grenade"]

const KRATOS_EXCLUSIVE_WEAPON_IDS: Array[StringName] = [&"blades_of_chaos", &"leviathan_axe", &"gungnir", &"mjolnir", &"sumarbrander", &"gjallarhorn", &"medusa_head", &"poseidon_trident", &"zeus_lightning", &"apollos_lyre"]

const SHOP_WEAPON_IDS: Array[StringName] = [
	&"anubis_curse",
	&"gungnir",
	&"sumarbrander",
	&"leviathan_axe",
]

var _player_weapons: Node2D
var _player: CharacterBody2D
var _item_controller: ItemEffectController


func setup(weapon_holder: Node2D) -> void:
	_player_weapons = weapon_holder
	if weapon_holder:
		_player = weapon_holder.get_parent() as CharacterBody2D
		_item_controller = _player.get_node_or_null("ItemEffectController") as ItemEffectController


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


func generate_options(count: int = 3) -> Array[UpgradeOption]:
	var options: Array[UpgradeOption] = []
	var pool: Array[Resource] = []
	
	# Construir o pool de possibilidades (Armas) baseado no personagem
	var weapon_pool: Array[WeaponData] = []
	
	# Selecionar armas específicas do personagem
	var character_weapon_ids: Array[StringName] = []
	match Global.selected_character_id:
		&"eirik":
			character_weapon_ids = EIRIK_WEAPON_IDS
		&"neferu":
			character_weapon_ids = NEFERU_WEAPON_IDS
		&"perseus":
			character_weapon_ids = PERSEUS_WEAPON_IDS
		&"arthur":
			character_weapon_ids = ARTHUR_WEAPON_IDS
		&"punisher":
			character_weapon_ids = PUNISHER_EXCLUSIVE_WEAPON_IDS
		&"kratos":
			character_weapon_ids = KRATOS_EXCLUSIVE_WEAPON_IDS
	
	# Carregar armas específicas do personagem
	for weapon_id in character_weapon_ids:
		var weapon_data := ContentRegistry.get_weapon_data(weapon_id)
		if weapon_data:
			weapon_pool.append(weapon_data)

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
			
	# Fundamentais são encontrados durante a run e não pertencem à loja.
	if _item_controller:
		for item in ItemCatalog.get_fundamentals():
			if _item_controller.get_item_level(item.id) < item.max_level:
				pool.append(item)

	# Poderes especiais e sinergias equipados podem ter progressão própria.
	if _item_controller:
		for item_id in SaveManager.get_equipped_items():
			var item := ItemCatalog.get_item(item_id)
			if item and _item_controller.get_item_level(item.id) < item.max_level:
				pool.append(item)
			
	# Escolher até 'count' opções sem duplicatas
	pool.shuffle()
	var to_pick = mini(count, pool.size())
	
	for i in range(to_pick):
		var data = pool[i]
		var opt := UpgradeOption.new()
		opt.item_data = data
		
		if data is WeaponData:
			var current_lvl := _get_weapon_level(data.id)
			if current_lvl == 0:
				opt.is_new_weapon = true
				opt.current_level = 0
				opt.kind_label = "ARMA DIVINA ATRAVESSA O VÉU"
				opt.display_text = data.display_name
				opt.description_text = data.description
			else:
				opt.is_new_weapon = false
				opt.current_level = current_lvl
				opt.kind_label = "O ECO DESPERTA  ·  NÍVEL %d" % (current_lvl + 1)
				opt.display_text = data.display_name
				var weapon := _get_weapon(data.id)
				if weapon and weapon.has_method("get_next_upgrade_description"):
					opt.description_text = weapon.get_next_upgrade_description()
				else:
					opt.description_text = data.get_level_description(current_lvl + 1)
		elif data is ItemData:
			opt.is_item = true
			var item := data as ItemData
			var item_level := _item_controller.get_item_level(item.id)
			opt.current_level = item_level
			opt.kind_label = "RELÍQUIA CONCEDIDA" if item_level == 0 \
				else "A RELÍQUIA RESSOA  ·  NÍVEL %d" % (item_level + 1)
			opt.display_text = item.display_name
			opt.description_text = item.get_level_description(item_level + 1)
			
		options.append(opt)
		
	return options


func apply_option(option: UpgradeOption) -> void:
	if option.is_item:
		if _item_controller:
			var item := option.item_data as ItemData
			if _item_controller.get_item_level(item.id) == 0:
				_item_controller.debug_grant_item(item)
			else:
				_item_controller.upgrade_item(item.id)
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
