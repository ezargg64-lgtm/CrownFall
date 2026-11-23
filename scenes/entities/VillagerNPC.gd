extends Node2D

## Returning villager NPC with idle bob, short story dialogue, and shop/upgrade handoff.

@export_enum("pip", "gideon", "astrid", "vance") var villager_id: String = "pip"

const VILLAGER_DATA: Dictionary = {
	"pip": {
		"name": "Old Pip",
		"body": "res://assets/characters/tiny_dungeon_tile_0100.png",
		"tool": "res://assets/crops/tiny_town_tile_0116.png",
		"shop": "pip",
		"first_lines": [
			"Your Majesty! I thought the border village was gone for good.",
			"You restored the Royal Farmstead with your own dirt-stained hands! The soil remembers a true king.",
			"Here — those 6 plots are yours again, and I brought my finest Golden Wheat seeds!",
		],
		"repeat_lines": [
			"Need fast-growing Golden Wheat seeds, Sire? They mature in a single night!",
		],
	},
	"gideon": {
		"name": "Gideon",
		"body": "res://assets/characters/tiny_dungeon_tile_0086.png",
		"tool": "res://assets/ui/tiny_dungeon_tile_0117.png",
		"shop": "gideon",
		"first_lines": [
			"By the embers... a king swinging a hammer to rebuild his own forge!",
			"Take this technique before we trade: Spin Slash [U / Q / Y]! Channel your Royal Gauge into a 360-degree cleave.",
			"Bring me Monster Shards and Gold whenever you want your blade and armor reforged.",
		],
		"repeat_lines": [
			"The anvil's hot, Sire. Let's sharpen your steel or reinforce your Royal Armor!",
		],
	},
	"astrid": {
		"name": "Astrid",
		"body": "res://assets/characters/tiny_dungeon_tile_0099.png",
		"tool": "res://assets/ui/tiny_dungeon_tile_0114.png",
		"shop": "astrid",
		"first_lines": [
			"I smelled fresh Sunwheat on the wind and hurried straight home, Your Highness!",
			"With my Apothecary lit again, merchants across the realm will pay +50% more for all your crops and shards.",
			"Give me 2 Crops and 10G anytime, and I'll brew you a fresh Harvest Flask!",
		],
		"repeat_lines": [
			"Need a Harvest Flask brewed, or ready to cash in with my +50% Apothecary bonus?",
		],
	},
	"vance": {
		"name": "Captain Vance",
		"body": "res://assets/characters/tiny_dungeon_tile_0097.png",
		"tool": "res://assets/ui/tiny_dungeon_tile_0102.png",
		"shop": "",
		"first_lines": [
			"Hail, my King! You rallied every soul in this ruined outpost.",
			"I've reinforced your Cracked Shield into the Explosive Bounce Shield — every parried shot blasts enemies nearby!",
			"The Usurper's seal on the Northern Boss Gate is broken. Go bounce his dark magic right back in his face!",
		],
		"repeat_lines": [
			"The Explosive Bounce Shield is yours, and the Boss Gate in the Wild Frontier stands unsealed!",
		],
	},
}

@onready var visual_pivot: Node2D = $VisualPivot
@onready var body_sprite: Sprite2D = $VisualPivot/BodySprite
@onready var tool_sprite: Sprite2D = $VisualPivot/ToolSprite
@onready var name_label: Label = $NameLabel
@onready var interact_area: Area2D = $InteractArea
@onready var body_shape: CollisionShape2D = $StaticBody2D/CollisionShape2D

var _display_name: String = "Villager"
var _body_path: String = ""
var _shop_id: String = ""
var _bob_time: float = 0.0
var _active: bool = true


func _ready() -> void:
	configure(villager_id)


func _process(delta: float) -> void:
	if _active and visible:
		_bob_time += delta * 3.2
		visual_pivot.position.y = sin(_bob_time) * 1.1


func configure(id_val: String) -> void:
	villager_id = id_val
	var data: Dictionary = VILLAGER_DATA.get(villager_id, VILLAGER_DATA["pip"])
	_display_name = str(data.get("name", "Villager"))
	_body_path = str(data.get("body", "res://assets/characters/tiny_dungeon_tile_0100.png"))
	_shop_id = str(data.get("shop", ""))

	body_sprite.texture = load(_body_path) as Texture2D
	tool_sprite.texture = load(str(data.get("tool", ""))) as Texture2D
	name_label.text = _display_name


func set_active(enabled: bool) -> void:
	_active = enabled
	visible = enabled
	interact_area.monitorable = enabled
	interact_area.monitoring = enabled
	body_shape.set_deferred("disabled", not enabled)


func get_prompt_text() -> String:
	if not _active:
		return ""
	return "[E] Talk to %s" % _display_name


func interact(_player: Node2D) -> void:
	if not _active:
		return
	var data: Dictionary = VILLAGER_DATA.get(villager_id, VILLAGER_DATA["pip"])
	var has_talked: bool = bool(GameState.talked_villagers.get(villager_id, false))
	var raw_lines: Array = data["repeat_lines"] if has_talked else data["first_lines"]
	var lines: PackedStringArray = PackedStringArray(raw_lines)
	GameState.talked_villagers[villager_id] = true

	if villager_id == "vance" and not GameState.shield_upgraded:
		GameState.shield_upgraded = true
		GameState.stats_changed.emit()

	GameState.request_dialogue(_display_name, _body_path, lines, _shop_id)
