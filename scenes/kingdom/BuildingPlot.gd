extends Node2D

## Multi-tile building plot transitioning from ruined rubble to restored Kenney building + villager.

@export_enum("farmstead", "forge", "apothecary", "gatehouse") var building_id: String = "farmstead"

@onready var ruined_visual: Node2D = $RuinedVisual
@onready var restored_visual: Node2D = $RestoredVisual
@onready var villager_npc: Node2D = $VillagerNPC
@onready var body_collision: CollisionShape2D = $StaticBody2D/CollisionShape2D
@onready var interact_area: Area2D = $InteractArea
@onready var cost_label: Label = $CostLabel
@onready var rebuild_particles: CPUParticles2D = $RebuildParticles

const BUILDING_TO_VILLAGER: Dictionary = {
	"farmstead": "pip",
	"forge": "gideon",
	"apothecary": "astrid",
	"gatehouse": "vance",
}

var _smoke_particles: CPUParticles2D = null


func _ready() -> void:
	_build_ruined_visual()
	_build_restored_visual()
	_configure_collision_and_villager()

	GameState.building_rebuilt.connect(_on_building_rebuilt)
	GameState.resources_changed.connect(_refresh_cost_label)
	GameState.day_advanced.connect(_on_day_advanced)
	_sync_state()


func get_prompt_text() -> String:
	if bool(GameState.rebuilt_buildings.get(building_id, false)):
		return ""
	var cost: Dictionary = GameState.BUILDING_COSTS.get(building_id, {})
	var b_name: String = str(cost.get("name", building_id.capitalize()))
	if GameState.can_afford_building(building_id):
		return "[E] Rebuild %s" % b_name
	return "%s (%s)" % [b_name, GameState.get_missing_building_text(building_id)]


func interact(_player: Node2D) -> void:
	if bool(GameState.rebuilt_buildings.get(building_id, false)):
		return

	if GameState.rebuild_building(building_id):
		AudioManager.play_rebuild()
		rebuild_particles.restart()
		rebuild_particles.emitting = true
		restored_visual.scale = Vector2(0.85, 1.15)
		var tw: Tween = create_tween()
		tw.tween_property(restored_visual, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		AudioManager.play_ui_close()
		GameState.show_toast(GameState.get_missing_building_text(building_id))


func _on_building_rebuilt(rebuilt_id: String, _new_level: int) -> void:
	if rebuilt_id == building_id:
		_sync_state()


func _on_day_advanced(_new_day: int) -> void:
	_sync_state()


func _sync_state() -> void:
	var is_rebuilt: bool = bool(GameState.rebuilt_buildings.get(building_id, false))
	ruined_visual.visible = not is_rebuilt
	restored_visual.visible = is_rebuilt
	interact_area.monitorable = not is_rebuilt
	if villager_npc.has_method("set_active"):
		villager_npc.set_active(is_rebuilt)
	if _smoke_particles != null:
		_smoke_particles.emitting = is_rebuilt
	_refresh_cost_label()


func _refresh_cost_label() -> void:
	var cost: Dictionary = GameState.BUILDING_COSTS.get(building_id, {})
	var b_name: String = str(cost.get("name", building_id.capitalize()))
	var is_rebuilt: bool = bool(GameState.rebuilt_buildings.get(building_id, false))

	if is_rebuilt:
		var villager: String = str(cost.get("villager", ""))
		cost_label.text = "%s\n(%s)" % [b_name, villager]
		cost_label.add_theme_color_override("font_color", Color(0.65, 0.96, 0.68, 1.0))
		return

	var parts: PackedStringArray = []
	if int(cost.get("gold", 0)) > 0:
		parts.append("%dG" % int(cost["gold"]))
	if int(cost.get("crops", 0)) > 0:
		parts.append("%d Crops" % int(cost["crops"]))
	if int(cost.get("monster_shards", 0)) > 0:
		parts.append("%d Shards" % int(cost["monster_shards"]))
	if int(cost.get("blight_shards", 0)) > 0:
		parts.append("%d Blight" % int(cost["blight_shards"]))

	cost_label.text = "%s\n%s" % [b_name, " + ".join(parts)]
	if GameState.can_afford_building(building_id):
		cost_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.42, 1.0))
	else:
		cost_label.add_theme_color_override("font_color", Color(0.95, 0.88, 0.85, 0.92))


func _configure_collision_and_villager() -> void:
	var v_id: String = str(BUILDING_TO_VILLAGER.get(building_id, "pip"))
	if villager_npc.has_method("configure"):
		villager_npc.configure(v_id)
	villager_npc.position = Vector2(24.0, 24.0)

	var rect := RectangleShape2D.new()
	if building_id == "gatehouse":
		rect.size = Vector2(60.0, 36.0)
	else:
		rect.size = Vector2(44.0, 36.0)
	body_collision.shape = rect
	body_collision.position = Vector2(0.0, -4.0)
	interact_area.position = Vector2(0.0, 22.0)


func _build_ruined_visual() -> void:
	for child: Node in ruined_visual.get_children():
		child.queue_free()

	_add_tile_sprite(ruined_visual, "res://assets/tiles/tiny_dungeon_tile_0024.png", Vector2(-8, -4))
	_add_tile_sprite(ruined_visual, "res://assets/tiles/tiny_dungeon_tile_0024.png", Vector2(10, 0))
	_add_tile_sprite(ruined_visual, "res://assets/tiles/tiny_town_tile_0106.png", Vector2(0, -10))
	_add_tile_sprite(ruined_visual, "res://assets/buildings/tiny_town_tile_0068.png", Vector2(-16, 4))
	_add_tile_sprite(ruined_visual, "res://assets/buildings/tiny_town_tile_0080.png", Vector2(0, 6))
	_add_tile_sprite(ruined_visual, "res://assets/buildings/tiny_town_tile_0082.png", Vector2(16, 4))
	_add_tile_sprite(ruined_visual, "res://assets/buildings/tiny_town_tile_0083.png", Vector2(-16, 16))


func _build_restored_visual() -> void:
	for child: Node in restored_visual.get_children():
		child.queue_free()

	var grid: Array = []
	match building_id:
		"farmstead":
			grid = [
				[
					"res://assets/buildings/tiny_town_tile_0052.png",
					"res://assets/buildings/tiny_town_tile_0053.png",
					"res://assets/buildings/tiny_town_tile_0054.png",
				],
				[
					"res://assets/buildings/tiny_town_tile_0064.png",
					"res://assets/buildings/tiny_town_tile_0065.png",
					"res://assets/buildings/tiny_town_tile_0066.png",
				],
				[
					"res://assets/buildings/tiny_town_tile_0084.png",
					"res://assets/buildings/tiny_town_tile_0085.png",
					"res://assets/buildings/tiny_town_tile_0084.png",
				],
			]
		"forge":
			grid = [
				[
					"res://assets/buildings/tiny_town_tile_0048.png",
					"res://assets/buildings/tiny_town_tile_0051.png",
					"res://assets/buildings/tiny_town_tile_0050.png",
				],
				[
					"res://assets/buildings/tiny_town_tile_0060.png",
					"res://assets/buildings/tiny_town_tile_0061.png",
					"res://assets/buildings/tiny_town_tile_0062.png",
				],
				[
					"res://assets/buildings/tiny_town_tile_0076.png",
					"res://assets/buildings/tiny_town_tile_0089.png",
					"res://assets/buildings/tiny_town_tile_0088.png",
				],
			]
		"apothecary":
			grid = [
				[
					"res://assets/buildings/tiny_town_tile_0052.png",
					"res://assets/buildings/tiny_town_tile_0055.png",
					"res://assets/buildings/tiny_town_tile_0054.png",
				],
				[
					"res://assets/buildings/tiny_town_tile_0064.png",
					"res://assets/buildings/tiny_town_tile_0067.png",
					"res://assets/buildings/tiny_town_tile_0066.png",
				],
				[
					"res://assets/buildings/tiny_town_tile_0088.png",
					"res://assets/buildings/tiny_town_tile_0089.png",
					"res://assets/buildings/tiny_town_tile_0088.png",
				],
			]
		"gatehouse":
			grid = [
				[
					"res://assets/tiles/tiny_town_tile_0099.png",
					"res://assets/tiles/tiny_town_tile_0100.png",
					"res://assets/tiles/tiny_town_tile_0100.png",
					"res://assets/tiles/tiny_town_tile_0101.png",
				],
				[
					"res://assets/tiles/tiny_town_tile_0126.png",
					"res://assets/tiles/tiny_town_tile_0111.png",
					"res://assets/tiles/tiny_town_tile_0112.png",
					"res://assets/tiles/tiny_town_tile_0126.png",
				],
				[
					"res://assets/tiles/tiny_town_tile_0125.png",
					"res://assets/tiles/tiny_town_tile_0123.png",
					"res://assets/tiles/tiny_town_tile_0124.png",
					"res://assets/tiles/tiny_town_tile_0125.png",
				],
			]

	var rows: int = grid.size()
	var cols: int = (grid[0] as Array).size() if rows > 0 else 0
	var start_x: float = -float(cols - 1) * 8.0
	var start_y: float = -16.0

	for r: int in range(rows):
		var row_arr: Array = grid[r]
		for c: int in range(row_arr.size()):
			var tex_path: String = str(row_arr[c])
			_add_tile_sprite(restored_visual, tex_path, Vector2(start_x + c * 16.0, start_y + r * 16.0))

	match building_id:
		"farmstead":
			_add_tile_sprite(restored_visual, "res://assets/buildings/tiny_town_tile_0057.png", Vector2(-30, 12))
			_add_tile_sprite(restored_visual, "res://assets/crops/tiny_town_tile_0094.png", Vector2(28, 12))
		"forge":
			_add_tile_sprite(restored_visual, "res://assets/tiles/tiny_dungeon_tile_0074.png", Vector2(-26, 14))
			_add_tile_sprite(restored_visual, "res://assets/tiles/tiny_town_tile_0106.png", Vector2(26, 14))
			_smoke_particles = CPUParticles2D.new()
			_smoke_particles.position = Vector2(4, -22)
			_smoke_particles.amount = 8
			_smoke_particles.lifetime = 1.4
			_smoke_particles.direction = Vector2(0.15, -1)
			_smoke_particles.spread = 20.0
			_smoke_particles.gravity = Vector2(0, -10)
			_smoke_particles.initial_velocity_min = 8.0
			_smoke_particles.initial_velocity_max = 16.0
			_smoke_particles.scale_amount_min = 2.0
			_smoke_particles.scale_amount_max = 3.5
			_smoke_particles.color = Color(0.78, 0.78, 0.82, 0.55)
			restored_visual.add_child(_smoke_particles)
		"apothecary":
			_add_tile_sprite(restored_visual, "res://assets/tiles/tiny_town_tile_0107.png", Vector2(-24, 14))
			_add_tile_sprite(restored_visual, "res://assets/tiles/tiny_town_tile_0029.png", Vector2(-12, 20))
			_add_tile_sprite(restored_visual, "res://assets/tiles/tiny_dungeon_tile_0082.png", Vector2(24, 14))
		"gatehouse":
			_add_tile_sprite(restored_visual, "res://assets/crops/tiny_town_tile_0095.png", Vector2(-34, 16))


func _add_tile_sprite(parent_node: Node2D, tex_path: String, offset: Vector2) -> void:
	var spr: Sprite2D = Sprite2D.new()
	spr.texture = load(tex_path) as Texture2D
	spr.position = offset
	parent_node.add_child(spr)
