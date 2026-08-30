extends Node

const ICON_RESOURCES: Array[String] = [
	"res://resources/weapons/mjolnir_data.tres",
	"res://resources/weapons/excalibur_data.tres",
	"res://resources/weapons/solar_disk_data.tres",
	"res://resources/weapons/poseidon_trident_data.tres",
	"res://resources/weapons/medusa_head_data.tres",
	"res://resources/weapons/zeus_lightning_data.tres",
	"res://resources/relics/speed_relic_data.tres",
]

var _failures: int = 0


func _ready() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	for resource_path in ICON_RESOURCES:
		var item_data := load(resource_path) as Resource
		var item_icon := item_data.get("icon") as Texture2D
		if item_icon == null:
			_fail("Item resource has no icon: %s" % resource_path)

	var weapon_data := load("res://resources/weapons/mjolnir_data.tres") as WeaponData
	var option := UpgradeOption.new()
	option.item_data = weapon_data
	option.display_text = "Nova Arma: %s" % weapon_data.display_name
	option.description_text = weapon_data.description
	var options: Array[UpgradeOption] = [option]

	var level_up_scene := load("res://scenes/ui/level_up_panel.tscn") as PackedScene
	var level_up_panel := level_up_scene.instantiate() as Control
	add_child(level_up_panel)
	await get_tree().process_frame
	level_up_panel.show_options(options)
	var option_button := level_up_panel.get_node("Panel/VBoxContainer").get_child(0) as Button
	if option_button.icon != weapon_data.icon:
		_fail("Level-up options should display the selected item's icon.")
	level_up_panel.hide()
	get_tree().paused = false
	level_up_panel.free()

	var hud_scene := load("res://scenes/ui/hud.tscn") as PackedScene
	var hud := hud_scene.instantiate() as Control
	add_child(hud)
	await get_tree().process_frame
	hud.add_weapon_icon(weapon_data.id, weapon_data.icon, weapon_data.display_name)
	var equipped_icon := hud.get_node("VBoxContainer/BottomBar/WeaponsContainer").get_child(0)
	if not equipped_icon is TextureRect:
		_fail("Equipped items should use their texture in the HUD.")
	hud.free()

	var solar_scene := load("res://scenes/weapons/solar_disk.tscn") as PackedScene
	var solar_weapon := solar_scene.instantiate() as Node2D
	var orbital_sprite := solar_weapon.get_node("DiskArea/Sprite2D") as Sprite2D
	var solar_data := load("res://resources/weapons/solar_disk_data.tres") as WeaponData
	if orbital_sprite.texture != solar_data.icon:
		_fail("The Solar Disk orbiting attack should use its weapon asset.")
	solar_weapon.free()

	var pause_scene := load("res://scenes/ui/pause_panel.tscn") as PackedScene
	var pause_panel := pause_scene.instantiate() as Control
	add_child(pause_panel)
	await get_tree().process_frame
	var inventory_line := pause_panel.call(
		"_format_inventory_line", weapon_data.icon, weapon_data.display_name, 1
	) as String
	if "[img=40x40]" not in inventory_line or weapon_data.icon.resource_path not in inventory_line:
		_fail("Pause inventory rows should include the item's icon.")
	pause_panel.free()

	if _failures == 0:
		print("Item icon tests passed.")
	get_tree().quit(_failures)


func _fail(message: String) -> void:
	_failures += 1
	push_error("Item icon test: %s" % message)
