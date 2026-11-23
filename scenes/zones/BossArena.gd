extends Node2D

## Final Boss Arena (30x22 tiles = 480x352 px) matching the ASCII design layout.

const MAP_COLS: int = 30
const MAP_ROWS: int = 22
const TILE_SIZE: int = 16

const TEX_DUNGEON_ATLAS: Texture2D = preload("res://assets/tiles/tiny_dungeon_tilemap_packed.png")
const BOSS_SCENE: PackedScene = preload("res://scenes/entities/BossUsurper.tscn")

@onready var ground_layer: TileMapLayer = $GroundLayer
@onready var wall_layer: TileMapLayer = $WallLayer
@onready var entities_layer: Node2D = $Entities
@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var boss_spawn: Marker2D = $BossSpawn

var _boss: CharacterBody2D = null


func _ready() -> void:
	GameState.is_safe_zone = false
	_setup_tileset()
	_paint_arena()

	if not GameState.boss_defeated:
		_boss = BOSS_SCENE.instantiate() as CharacterBody2D
		_boss.position = boss_spawn.position
		entities_layer.add_child(_boss)
		call_deferred("_start_entry_cutscene")
	else:
		GameState.boss_hp_changed.emit(0, 350, false)
		GameState.show_toast("The throne room stands quiet — the Usurper is already vanquished.")


func get_camera_bounds() -> Rect2i:
	return Rect2i(0, 0, MAP_COLS * TILE_SIZE, MAP_ROWS * TILE_SIZE)


func get_entities_parent() -> Node2D:
	return entities_layer


func get_spawn_position(_spawn_tag: String = "default") -> Vector2:
	return player_spawn.global_position


func _start_entry_cutscene() -> void:
	GameState.dialogue_closed.connect(_on_entry_dialogue_closed, CONNECT_ONE_SHOT)
	GameState.request_dialogue(
		"The Usurper",
		"res://assets/characters/tiny_dungeon_tile_0111.png",
		PackedStringArray([
			"You? A dirt-farming king? Let's see how fast you fall!",
			"Your crown is dust — try bouncing my dark magic back if you dare!",
		]),
		""
	)


func _on_entry_dialogue_closed() -> void:
	if is_instance_valid(_boss) and _boss.has_method("activate_boss"):
		_boss.activate_boss()


func _setup_tileset() -> void:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	ts.add_physics_layer(0)
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 0)

	var atlas := TileSetAtlasSource.new()
	atlas.texture = TEX_DUNGEON_ATLAS
	atlas.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)

	for r: int in range(11):
		for c: int in range(12):
			atlas.create_tile(Vector2i(c, r))

	ts.add_source(atlas, 0)

	var solid_coords: Array[Vector2i] = [
		Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1),
		Vector2i(4, 3), Vector2i(5, 2),
		Vector2i(6, 0), Vector2i(6, 1), Vector2i(6, 2),
	]
	var box_poly := PackedVector2Array([
		Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8),
	])
	for coord: Vector2i in solid_coords:
		var data: TileData = atlas.get_tile_data(coord, 0)
		if data != null:
			data.add_collision_polygon(0)
			data.set_collision_polygon_points(0, 0, box_poly)

	ground_layer.tile_set = ts
	wall_layer.tile_set = ts


func _paint_arena() -> void:
	for y: int in range(MAP_ROWS):
		for x: int in range(MAP_COLS):
			var tile_coord := Vector2i(0, 0)
			if (x + y) % 7 == 0:
				tile_coord = Vector2i(0, 1)
			ground_layer.set_cell(Vector2i(x, y), 0, tile_coord)

	# Central stone runner aisle
	for y: int in range(2, MAP_ROWS):
		ground_layer.set_cell(Vector2i(14, y), 0, Vector2i(6, 3))
		ground_layer.set_cell(Vector2i(15, y), 0, Vector2i(6, 3))

	# Outer walls with Southern Exit Gate (cols 14..15, bottom)
	for x: int in range(MAP_COLS):
		wall_layer.set_cell(Vector2i(x, 0), 0, Vector2i(2, 1))
		if x == 11 or x == 14 or x == 15 or x == 18:
			wall_layer.set_cell(Vector2i(x, 1), 0, Vector2i(5, 2))
		else:
			wall_layer.set_cell(Vector2i(x, 1), 0, Vector2i(4, 3))

		if x != 14 and x != 15:
			wall_layer.set_cell(Vector2i(x, MAP_ROWS - 1), 0, Vector2i(2, 1))

	for y: int in range(1, MAP_ROWS - 1):
		wall_layer.set_cell(Vector2i(0, y), 0, Vector2i(2, 1))
		wall_layer.set_cell(Vector2i(1, y), 0, Vector2i(4, 3))
		wall_layer.set_cell(Vector2i(MAP_COLS - 1, y), 0, Vector2i(2, 1))
		wall_layer.set_cell(Vector2i(MAP_COLS - 2, y), 0, Vector2i(4, 3))

	# Two symmetrical ricochet stone pillars matching ASCII map
	for px: int in [8, 21]:
		wall_layer.set_cell(Vector2i(px, 11), 0, Vector2i(6, 0))
		wall_layer.set_cell(Vector2i(px, 12), 0, Vector2i(6, 1))
		wall_layer.set_cell(Vector2i(px, 13), 0, Vector2i(6, 2))
