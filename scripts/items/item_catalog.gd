extends RefCounted
class_name ItemCatalog

const DEFINITIONS := [
	[&"chronos_hourglass", "Ampulheta de Cronos", &"Grega", 55, &"cooldown", 0.08, 0.0, "Reduz o cooldown de todas as armas em 8%.", "chronos_hourglass.png"],
	[&"thoths_papyrus", "Papiro de Thoth", &"Egípcia", 40, &"xp", 0.12, 0.0, "Aumenta todo XP recebido em 12%.", "thoths_papyrus.png"],
	[&"amphora_of_ambrosia", "Ânfora de Ambrosia", &"Grega", 50, &"regen", 0.003, 5.0, "Regenera vida; pausa por 5 s após sofrer dano.", "amphora_of_ambrosia.png"],
	[&"aegis_of_athena", "Égide de Atena", &"Grega", 60, &"max_health", 0.15, 0.0, "Aumenta a vida máxima em 15%.", "aegis_of_athena.png"],
	[&"megingjord", "Megingjörð", &"Nórdica", 65, &"damage", 0.10, 0.0, "Aumenta todo dano de armas em 10%.", "megingjord.png"],
	[&"tyches_cornucopia", "Cornucópia de Tique", &"Grega", 45, &"luck", 0.10, 0.0, "Concede 10% de sorte.", "tyches_cornucopia.png"],
	[&"ankh_of_osiris", "Ankh de Osíris", &"Egípcia", 120, &"revive", 0.35, 2.0, "Reanima uma vez por run com 35% da vida.", "ankh_of_osiris.png"],
	[&"horn_of_poetic_mead", "Chifre do Hidromel Poético", &"Nórdica", 75, &"level_haste", 0.20, 8.0, "Level-up acelera ataques por 8 s.", "horn_of_poetic_mead.png"],
	[&"golden_fleece", "Velocino de Ouro", &"Grega", 90, &"shield", 30.0, 0.0, "30 s sem dano concedem um escudo.", "golden_fleece.png"],
	[&"vial_of_mimirs_waters", "Frasco das Águas de Mímir", &"Nórdica", 70, &"level_heal", 0.05, 0.0, "Cada level-up cura 5% da vida.", "vial_of_mimirs_waters.png"],
	[&"feather_of_maat", "Pena de Ma'at", &"Egípcia", 80, &"kill_streak", 20.0, 10.0, "20 kills sem dano concedem um buff.", "feather_of_maat.png"],
	[&"ariadnes_thread_ball", "Novelo de Ariadne", &"Grega", 65, &"pickup", 0.35, 15.0, "Amplia a coleta e ativa atração após 15 pickups.", "ariadnes_thread_ball.png"],
	[&"eye_of_horus", "Olho de Hórus", &"Egípcia", 100, &"solar_block", 5.0, 0.75, "Cinco bloqueios solares emitem um pulso.", "eye_of_horus.png"],
	[&"draupnir_ring", "Anel de Draupnir", &"Nórdica", 110, &"attack_echo", 8.0, 0.5, "A cada oitavo ataque, cria um eco.", "draupnir_ring.png"],
	[&"tyet_amulet_of_isis", "Amuleto Tyet de Ísis", &"Egípcia", 95, &"overheal_barrier", 0.15, 0.0, "Cura excedente vira barreira.", "tyet_amulet_of_isis.png"],
	[&"odins_sacrificed_eye", "Olho Sacrificado de Odin", &"Nórdica", 105, &"mark", 0.25, 4.0, "Marca um alvo para receber mais dano.", "odins_sacrificed_eye.png"],
	[&"hippolytas_belt", "Cinto de Hipólita", &"Grega", 85, &"area", 0.20, 0.0, "Aumenta a área dos ataques em até 20%.", "hippolytas_belt.png"],
	[&"hermes_sandals", "Sandálias de Hermes", &"Grega", 75, &"move_speed", 0.08, 0.0, "Aumenta a velocidade e pode chegar ao nível 5 durante a run.", "res://assets/sprites/weapons/hermes_sandals.png"],
]

const FUNDAMENTAL_IDS: Array[StringName] = [
	&"chronos_hourglass",
	&"thoths_papyrus",
	&"amphora_of_ambrosia",
	&"aegis_of_athena",
	&"megingjord",
	&"tyches_cornucopia",
	&"hermes_sandals",
]

static var _items: Dictionary = {}

static func get_all() -> Array[ItemData]:
	_ensure_loaded()
	var result: Array[ItemData] = []
	for value in _items.values(): result.append(value as ItemData)
	return result

static func get_item(id: StringName) -> ItemData:
	_ensure_loaded()
	return _items.get(id) as ItemData

static func has_item(id: StringName) -> bool:
	_ensure_loaded()
	return _items.has(id)


static func is_fundamental(id: StringName) -> bool:
	return id in FUNDAMENTAL_IDS


static func is_shop_item(id: StringName) -> bool:
	return has_item(id) and not is_fundamental(id)


static func get_fundamentals() -> Array[ItemData]:
	var result: Array[ItemData] = []
	for id in FUNDAMENTAL_IDS:
		var item := get_item(id)
		if item:
			result.append(item)
	return result

static func _ensure_loaded() -> void:
	if not _items.is_empty(): return
	for definition in DEFINITIONS:
		var item := ItemData.new()
		item.id = definition[0]; item.display_name = definition[1]; item.mythology = definition[2]
		item.price = definition[3]; item.effect_id = definition[4]; item.value = definition[5]
		item.secondary_value = definition[6]; item.description = definition[7]
		item.is_fundamental = item.id in FUNDAMENTAL_IDS
		var icon_path := String(definition[8])
		if not icon_path.begins_with("res://"):
			icon_path = "res://assets/sprites/items/%s" % icon_path
		item.icon = load(icon_path) as Texture2D
		if item.id == &"hermes_sandals":
			item.max_level = 5
			item.level_values = [0.08, 0.12, 0.16, 0.20, 0.25]
			item.level_descriptions = [
				"Aumenta a velocidade de movimento em 8%.",
				"Aumenta a velocidade de movimento em 12%.",
				"Aumenta a velocidade de movimento em 16%.",
				"Aumenta a velocidade de movimento em 20%.",
				"Poder de Hermes: aumenta a velocidade de movimento em 25%.",
			]
		_items[item.id] = item
