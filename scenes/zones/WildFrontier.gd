extends Node2D

## Combat Zone 2: WildFrontier (44x32 tiles = 704x512 px) with Day/Night enemies & ricochet pillars.

const MAP_COLS: int = 44
const MAP_ROWS: int = 32
const TILE_SIZE: int = 16

const TEX_DUNGEON_ATLAS: Texture2D = preload("res://assets/tiles/tiny_dungeon_tilemap_packed.png")
const BOAR_SCENE: PackedScene = preload("res://scenes/entities/EnemyBoar.tscn")
const IMP_SCENE: PackedScene = preload("res://scenes/entities/EnemyImp.tscn")
const WRAITH_SCENE: PackedScene = preload("res://scenes/entities/EnemyWraith.tscn")

@onready var ground_layer: TileMapLayer = $GroundLayer
@onready var wall_layer: TileMapLayer = $WallLayer
@onready var entities_layer: Node2D = $Entities
@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var boss_return_spawn: Marker2D = $BossReturnSpawn

var _night_announced: bool = false
var _wraith_check_timer: float = 0.0
var _wraith_spawns: Array[Vector2] = [
	Vector2(230.0, 345.0),
	Vector2(475.0, 345.0),
]


func _ready() -> void:
	GameState.is_safe_zone = false
	_setup_tileset()
	_paint_map()
	_spawn_day_enemies()
	_check_night_wraiths(true)


func _process(delta: float) -> void:
	if GameState.time_of_day >= 0.72:
		_wraith_check_timer -= delta
		if not _night_announced or _wraith_check_timer <= 0.0:
			_wraith_check_timer = 16.0
			_check_night_wraiths(false)
	else:
		_night_announced = false


func get_camera_bounds() -> Rect2i:
	return Rect2i(0, 0, MAP_COLS * TILE_SIZE, MAP_ROWS * TILE_SIZE)


func get_entities_parent() -> Node2D:
	return entities_layer


func get_spawn_position(spawn_tag: String = "default") -> Vector2:
	if spawn_tag == "from_boss" and boss_return_spawn != null:
		return boss_return_spawn.global_position
	return player_spawn.global_position


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
		Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2),
		Vector2i(4, 3),
		Vector2i(9, 4), Vector2i(10, 4), Vector2i(11, 4),
		Vector2i(6, 0), Vector2i(6, 1), Vector2i(6, 2),
		Vector2i(10, 3), Vector2i(11, 3),
		Vector2i(5, 2),
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


func _paint_map() -> void:
	# Base frontier floor
	for y: int in range(MAP_ROWS):
		for x: int in range(MAP_COLS):
			var h: int = (x * 29 + y * 67) % 17
			var tile_coord := Vector2i(0, 4)
			if h == 0:
				tile_coord = Vector2i(3, 4)
			elif h <= 3:
				tile_coord = Vector2i(1, 4)
			elif h == 5:
				tile_coord = Vector2i(0, 1)
			ground_layer.set_cell(Vector2i(x, y), 0, tile_coord)

	# Stone paver trail connecting South Gate -> Plaza -> Boss Gate
	for y: int in range(1, MAP_ROWS):
		ground_layer.set_cell(Vector2i(21, y), 0, Vector2i(6, 3))
		ground_layer.set_cell(Vector2i(22, y), 0, Vector2i(6, 3))

	# Outer stone walls with South Gate (cols 21..22, bottom) and Boss Gate (cols 21..22, top)
	var gate_unsealed: bool = bool(GameState.rebuilt_buildings.get("gatehouse", false))
	for x: int in range(MAP_COLS):
		if x == 21:
			wall_layer.set_cell(Vector2i(x, 0), 0, Vector2i(10, 1) if gate_unsealed else Vector2i(10, 3))
		elif x == 22:
			wall_layer.set_cell(Vector2i(x, 0), 0, Vector2i(11, 1) if gate_unsealed else Vector2i(11, 3))
		else:
			wall_layer.set_cell(Vector2i(x, 0), 0, Vector2i(2, 1))
			wall_layer.set_cell(Vector2i(x, 1), 0, Vector2i(4, 3))

		if x != 21 and x != 22:
			wall_layer.set_cell(Vector2i(x, MAP_ROWS - 1), 0, Vector2i(2, 1))

	for y: int in range(1, MAP_ROWS - 1):
		wall_layer.set_cell(Vector2i(0, y), 0, Vector2i(2, 1))
		wall_layer.set_cell(Vector2i(1, y), 0, Vector2i(4, 3))
		wall_layer.set_cell(Vector2i(MAP_COLS - 1, y), 0, Vector2i(2, 1))
		wall_layer.set_cell(Vector2i(MAP_COLS - 2, y), 0, Vector2i(4, 3))

	# Boss Gate flanking banners
	wall_layer.set_cell(Vector2i(20, 1), 0, Vector2i(5, 2))
	wall_layer.set_cell(Vector2i(23, 1), 0, Vector2i(5, 2))

	# 4 Central Ricochet Stone Pillars (3 tiles tall each)
	var pillar_positions: Array[Vector2i] = [
		Vector2i(14, 11),
		Vector2i(29, 11),
		Vector2i(14, 20),
		Vector2i(29, 20),
	]
	for p: Vector2i in pillar_positions:
		wall_layer.set_cell(p, 0, Vector2i(6, 0))
		wall_layer.set_cell(p + Vector2i(0, 1), 0, Vector2i(6, 1))
		wall_layer.set_cell(p + Vector2i(0, 2), 0, Vector2i(6, 2))

	# Side rocky cover alcoves
	var rock_clusters: Array[Vector2i] = [
		Vector2i(6, 7), Vector2i(7, 7),
		Vector2i(36, 7), Vector2i(37, 7),
		Vector2i(6, 23), Vector2i(7, 23),
		Vector2i(36, 23), Vector2i(37, 23),
	]
	for rc: Vector2i in rock_clusters:
		wall_layer.set_cell(rc, 0, Vector2i(2, 1))


func _spawn_day_enemies() -> void:
	var boar_positions: Array[Vector2] = [
		Vector2(205.0, 228.0),
		Vector2(492.0, 276.0),
	]
	for pos: Vector2 in boar_positions:
		var boar := BOAR_SCENE.instantiate() as CharacterBody2D
		boar.position = pos
		entities_layer.add_child(boar)

	var imp_positions: Array[Vector2] = [
		Vector2(248.0, 128.0),
		Vector2(488.0, 168.0),
	]
	for pos: Vector2 in imp_positions:
		var imp := IMP_SCENE.instantiate() as CharacterBody2D
		imp.position = pos
		entities_layer.add_child(imp)


func _check_night_wraiths(initial_check: bool) -> void:
	if GameState.time_of_day < 0.72:
		return

	if not _night_announced:
		_night_announced = true
		if not initial_check or GameState.time_of_day >= 0.72:
			GameState.show_toast("Night risk! Wraiths patrol the Frontier (drop Blight Shards).")

	var live_wraiths: int = 0
	for child: Node in entities_layer.get_children():
		if child.scene_file_path.ends_with("EnemyWraith.tscn"):
			live_wraiths += 1

	var spawn_idx: int = 0
	while live_wraiths < 2 and spawn_idx < _wraith_spawns.size():
		var wraith := WRAITH_SCENE.instantiate() as CharacterBody2D
		wraith.position = _wraith_spawns[spawn_idx]
		entities_layer.add_child(wraith)
		live_wraiths += 1
		spawn_idx += 1
