extends RefCounted
class_name ContentRegistry
## Fonte única de IDs e caminhos de conteúdo. Carrega resources sob demanda.

const ENEMIES := {
	&"bat": ["Morcego", "res://resources/enemies/bat_data.tres", "res://scenes/enemies/bat_enemy.tscn"],
	&"draugr": ["Draugr", "res://resources/enemies/draugr_data.tres", "res://scenes/enemies/basic_enemy.tscn"],
	&"harpy": ["Harpia", "res://resources/enemies/harpy_data.tres", "res://scenes/enemies/basic_enemy.tscn"],
	&"ranged_slime": ["Slime Arcano", "res://resources/enemies/ranged_slime_data.tres", "res://scenes/enemies/ranged_enemy.tscn"],
	&"healer_slime": ["Slime Curandeiro", "res://resources/enemies/healer_slime_data.tres", "res://scenes/enemies/healer_enemy.tscn"],
	&"medusa": ["Medusa", "res://resources/enemies/medusa_data.tres", "res://scenes/enemies/medusa.tscn"],
	&"mummy": ["Múmia", "res://resources/enemies/mummy_data.tres", "res://scenes/enemies/directional_ranged_enemy.tscn"],
	&"cyclops": ["Ciclope", "res://resources/enemies/cyclops_data.tres", "res://scenes/enemies/basic_enemy.tscn"],
	&"orc": ["Orc", "res://resources/enemies/orc_data.tres", "res://scenes/enemies/tank_enemy.tscn"],
	&"minotaur": ["Minotauro", "res://resources/enemies/minotaur_data.tres", "res://scenes/enemies/charger_enemy.tscn"],
	&"ammit": ["Ammit", "res://resources/enemies/ammit_data.tres", "res://scenes/enemies/ammit.tscn"],
	&"corrupted_valkyrie": ["Corrupted Valkyrie", "res://resources/enemies/corrupted_valkyrie_data.tres", "res://scenes/enemies/corrupted_valkyrie.tscn"],
	&"skeleton": ["Esqueleto", "res://resources/enemies/skeleton_data.tres", "res://scenes/enemies/skeleton_enemy.tscn"],
	&"wolf": ["Lobo", "res://resources/enemies/wolf_data.tres", "res://scenes/enemies/wolf_enemy.tscn"],
	&"warlock": ["Bruxo", "res://resources/enemies/warlock_data.tres", "res://scenes/enemies/warlock_enemy.tscn"],
	&"lizard": ["Lagarto", "res://resources/enemies/lizard_data.tres", "res://scenes/enemies/lizard_enemy.tscn"],
	&"imp": ["Diabrete", "res://resources/enemies/imp_data.tres", "res://scenes/enemies/imp_enemy.tscn"],
}

const BOSSES := {
	&"king_slime": ["King Slime", "res://resources/bosses/king_slime_data.tres", "res://scenes/bosses/king_slime.tscn"],
	&"orc_warlord": ["Orc Warlord", "res://resources/bosses/orc_warlord_data.tres", "res://scenes/bosses/orc_warlord.tscn"],
	&"cerberus": ["Cerberus", "res://resources/bosses/cerberus_data.tres", "res://scenes/bosses/cerberus.tscn"],
	&"lernaean_hydra": ["Lernaean Hydra", "res://resources/bosses/lernaean_hydra_data.tres", "res://scenes/bosses/lernaean_hydra.tscn"],
	&"amheh": ["Amheh", "res://resources/bosses/amheh_data.tres", "res://scenes/bosses/amheh.tscn"],
	&"anubis": ["Anubis", "res://resources/bosses/anubis_data.tres", "res://scenes/bosses/anubis.tscn"],
	&"apophis": ["Apophis", "res://resources/bosses/apophis_data.tres", "res://scenes/bosses/apophis.tscn"],
	&"corrupted_treant": ["Corrupted Treant", "res://resources/bosses/corrupted_treant_data.tres", "res://scenes/bosses/corrupted_treant.tscn"],
	&"jormungandr": ["Jormungandr", "res://resources/bosses/jormungandr_data.tres", "res://scenes/bosses/jormungandr.tscn"],
	&"fenrir": ["Fenrir", "res://resources/bosses/fenrir_data.tres", "res://scenes/bosses/fenrir.tscn"],
}

const CHARACTERS := {
	&"eirik": ["Eirik", "res://resources/characters/eirik_data.tres"],
	&"arthur": ["Arthur", "res://resources/characters/arthur_data.tres"],
	&"neferu": ["Neferu", "res://resources/characters/neferu_data.tres"],
	&"perseus": ["Perseus", "res://resources/characters/perseus_data.tres"],
	&"punisher": ["Justiceiro", "res://resources/characters/punisher_data.tres"],
	&"kratos": ["Kratos", "res://resources/characters/kratos_data.tres"],
}

const WEAPONS := {
	&"mjolnir": ["Mjolnir", "res://resources/weapons/mjolnir_data.tres"],
	&"excalibur": ["Excalibur", "res://resources/weapons/excalibur_data.tres"],
	&"solar_disk": ["Disco Solar", "res://resources/weapons/solar_disk_data.tres"],
	&"poseidon_trident": ["Tridente de Poseidon", "res://resources/weapons/poseidon_trident_data.tres"],
	&"medusa_head": ["Cabeça da Medusa", "res://resources/weapons/medusa_head_data.tres"],
	&"zeus_lightning": ["Raio de Zeus", "res://resources/weapons/zeus_lightning_data.tres"],
	&"anubis_curse": ["Maldição de Anúbis", "res://resources/weapons/anubis_curse.tres"],
	&"gungnir": ["Gungnir", "res://resources/weapons/gungnir_data.tres"],
	&"sumarbrander": ["Sumarbrander", "res://resources/weapons/sumarbrander_data.tres"],
	&"punisher_gun": ["Arma do Justiceiro", "res://resources/weapons/punisher_gun_data.tres"],
	&"punisher_grenade": ["Granada do Justiceiro", "res://resources/weapons/punisher_grenade_data.tres"],
	&"blades_of_chaos": ["Lâminas do Caos", "res://resources/weapons/blades_of_chaos_data.tres"],
	&"leviathan_axe": ["Machado Leviatã", "res://resources/weapons/leviathan_axe_data.tres"],
	&"horusfeather": ["Pena de Hórus", "res://resources/weapons/horusfeather_data.tres"],
	&"apollos_lyre": ["Lira de Apolo", "res://resources/weapons/apollos_lyre_data.tres"],
	&"gjallarhorn": ["Gjallarhorn", "res://resources/weapons/gjallarhorn_data.tres"],
	&"khepris_scarab": ["Escaravelho de Khepri", "res://resources/weapons/khepris_scarab_data.tres"],
}


static func get_enemy_data(id: StringName) -> EnemyData:
	var entry: Array = ENEMIES.get(id, [])
	return load(entry[1]) as EnemyData if entry.size() >= 3 else null


static func get_enemy_scene(id: StringName) -> PackedScene:
	var entry: Array = ENEMIES.get(id, [])
	return load(entry[2]) as PackedScene if entry.size() >= 3 else null


static func get_enemy_options() -> Dictionary:
	return _options(ENEMIES)


static func get_boss_scene(id: StringName) -> PackedScene:
	var entry: Array = BOSSES.get(id, [])
	return load(entry[2]) as PackedScene if entry.size() >= 3 else null


static func get_boss_data(id: StringName) -> BossData:
	var entry: Array = BOSSES.get(id, [])
	return load(entry[1]) as BossData if entry.size() >= 3 else null


static func get_boss_display_name(id: StringName) -> String:
	var entry: Array = BOSSES.get(id, [])
	return String(entry[0]) if not entry.is_empty() else String(id)


static func get_boss_options() -> Dictionary:
	return _options(BOSSES)


static func get_character_data(id: StringName) -> CharacterData:
	var entry: Array = CHARACTERS.get(id, [])
	return load(entry[1]) as CharacterData if entry.size() >= 2 else null


static func get_character_options() -> Dictionary:
	return _options(CHARACTERS)


static func get_weapon_data(id: StringName) -> WeaponData:
	var entry: Array = WEAPONS.get(id, [])
	return load(entry[1]) as WeaponData if entry.size() >= 2 else null


static func get_weapon_options() -> Dictionary:
	return _options(WEAPONS)


static func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	_validate_group("enemy", ENEMIES, 3, errors)
	_validate_group("boss", BOSSES, 3, errors)
	_validate_group("character", CHARACTERS, 2, errors)
	_validate_group("weapon", WEAPONS, 2, errors)
	return errors


static func _options(registry: Dictionary) -> Dictionary:
	var result := {}
	for id in registry:
		var entry: Array = registry[id]
		if not entry.is_empty():
			result[String(entry[0])] = id
	return result


static func _validate_group(label: String, registry: Dictionary, path_count: int, errors: PackedStringArray) -> void:
	for id in registry:
		var entry: Array = registry[id]
		if entry.size() < path_count:
			errors.append("%s '%s' possui registro incompleto." % [label, id])
			continue
		for index in range(1, path_count):
			var path := String(entry[index])
			if not ResourceLoader.exists(path):
				errors.append("%s '%s' referencia caminho ausente: %s" % [label, id, entry[index]])
		var resource := load(String(entry[1]))
		if label == "enemy" and (not (resource is EnemyData) or resource.get("id") != id):
			errors.append("enemy '%s' possui resource com ID divergente." % id)
		elif label == "boss" and (not (resource is BossData) or resource.get("id") != id):
			errors.append("boss '%s' possui resource com ID divergente." % id)
		elif label == "character" and (not (resource is CharacterData) or resource.get("id") != id):
			errors.append("character '%s' possui resource com ID divergente." % id)
		elif label == "weapon" and (not (resource is WeaponData) or resource.get("id") != id):
			errors.append("weapon '%s' possui resource com ID divergente." % id)
