extends Node2D

## Safe Zone 1: KingdomHub (40x28 tiles = 640x448 px) matching the ASCII design layout.

const MAP_COLS: int = 40
const MAP_ROWS: int = 28
const TILE_SIZE: int = 16

@onready var ground_layer: TileMapLayer = $GroundLayer
@onready var wall_layer: TileMapLayer = $WallLayer
@onready var entities_layer: Node2D = $Entities
@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var north_return_spawn: Marker2D = $NorthReturnSpawn
@onready var fireflies: CPUParticles2D = $Fireflies
@onready var north_gate_area: Area2D = $NorthGateTrigger

const TEX_TOWN_ATLAS: Texture2D = preload("res://assets/tiles/tiny_town_tilemap_packed.png")

var _solid_coords: Array[Vector2i] = []


func _ready() -> void:
	GameState.is_safe_zone = true
	_setup_tileset()
	_paint_ground()
	_paint_borders_and_props()
	_build_ruined_hall()
	GameState.time_changed.connect(_on_time_changed)
	_on_time_changed(GameState.time_of_day)


func get_camera_bounds() -> Rect2i:
	return Rect2i(0, 0, MAP_COLS * TILE_SIZE, MAP_ROWS * TILE_SIZE)


func get_entities_parent() -> Node2D:
	return entities_layer


func get_spawn_position(spawn_tag: String = "default") -> Vector2:
	if spawn_tag == "from_north" and north_return_spawn != null:
		return north_return_spawn.global_position
	return player_spawn.global_position


func _on_time_changed(new_time: float) -> void:
	var night_active: bool = new_time >= 0.70 or new_time < 0.08
	fireflies.emitting = night_active


func _setup_tileset() -> void:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	ts.add_physics_layer(0)
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 0)

	var atlas := TileSetAtlasSource.new()
	atlas.texture = TEX_TOWN_ATLAS
	atlas.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)

	for r: int in range(11):
		for c: int in range(12):
			atlas.create_tile(Vector2i(c, r))

	ts.add_source(atlas, 0)

	_solid_coords = [
		Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0),
		Vector2i(3, 1), Vector2i(4, 1),
		Vector2i(3, 2), Vector2i(4, 2),
		Vector2i(6, 0), Vector2i(7, 0), Vector2i(8, 0),
		Vector2i(6, 1), Vector2i(7, 1), Vector2i(8, 1),
		Vector2i(6, 2), Vector2i(7, 2), Vector2i(8, 2),
		Vector2i(9, 0), Vector2i(10, 0), Vector2i(11, 0),
		Vector2i(9, 1), Vector2i(10, 1), Vector2i(11, 1),
		Vector2i(9, 2), Vector2i(10, 2), Vector2i(11, 2),
		Vector2i(3, 8), Vector2i(4, 8), Vector2i(5, 8), Vector2i(6, 8),
		Vector2i(3, 9), Vector2i(4, 9),
		Vector2i(5, 10), Vector2i(6, 10),
		Vector2i(8, 7), Vector2i(8, 8),
		Vector2i(11, 6),
	]

	var box_poly := PackedVector2Array([
		Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8),
	])
	for coord: Vector2i in _solid_coords:
		var data: TileData = atlas.get_tile_data(coord, 0)
		if data != null:
			data.add_collision_polygon(0)
			data.set_collision_polygon_points(0, 0, box_poly)

	ground_layer.tile_set = ts
	wall_layer.tile_set = ts


func _paint_ground() -> void:
	# Base grass meadow with gentle deterministic tufts and flowers
	for y: int in range(MAP_ROWS):
		for x: int in range(MAP_COLS):
			var hash_val: int = (x * 37 + y * 91) % 19
			var tile_coord := Vector2i(0, 0)
			if hash_val == 0:
				tile_coord = Vector2i(2, 0)
			elif hash_val <= 4:
				tile_coord = Vector2i(1, 0)
			ground_layer.set_cell(Vector2i(x, y), 0, tile_coord)

	# Cobblestone Main Plaza (9-slice: cols 15..24, rows 12..16)
	_paint_9slice(15, 12, 24, 16, Vector2i(0, 8))

	# Starter Farm Patch (cols 6..12, rows 14..17)
	_paint_9slice(6, 14, 12, 17, Vector2i(0, 1))

	# Locked Farmstead Expansion Patch (cols 13..19, rows 20..24)
	_paint_9slice(13, 20, 19, 24, Vector2i(0, 1))

	# Dirt paths connecting plaza to North Gate, Ruined Hall, 4 Ruins & Farm
	_paint_dirt_rect(19, 2, 20, 11)   # Plaza -> North Gate
	_paint_dirt_rect(12, 10, 19, 11)  # Hall porch -> North path
	_paint_dirt_rect(8, 6, 18, 7)     # Gatehouse path
	_paint_dirt_rect(21, 6, 31, 7)    # Forge path
	_paint_dirt_rect(25, 14, 31, 16)  # Plaza -> Apothecary
	_paint_dirt_rect(12, 14, 14, 15)  # Plaza -> Starter Farm
	_paint_dirt_rect(9, 18, 13, 22)   # Starter Farm -> Farmstead & expansion

	# Decorative stepping stones & mushrooms
	ground_layer.set_cell(Vector2i(26, 12), 0, Vector2i(7, 3))
	ground_layer.set_cell(Vector2i(29, 17), 0, Vector2i(5, 2))
	ground_layer.set_cell(Vector2i(6, 11), 0, Vector2i(5, 2))


func _paint_9slice(x0: int, y0: int, x1: int, y1: int, top_left: Vector2i) -> void:
	for y: int in range(y0, y1 + 1):
		for x: int in range(x0, x1 + 1):
			var ox: int = 1
			if x == x0:
				ox = 0
			elif x == x1:
				ox = 2
			var oy: int = 1
			if y == y0:
				oy = 0
			elif y == y1:
				oy = 2
			ground_layer.set_cell(Vector2i(x, y), 0, top_left + Vector2i(ox, oy))


func _paint_dirt_rect(x0: int, y0: int, x1: int, y1: int) -> void:
	for y: int in range(y0, y1 + 1):
		for x: int in range(x0, x1 + 1):
			ground_layer.set_cell(Vector2i(x, y), 0, Vector2i(1, 2))


func _paint_borders_and_props() -> void:
	# Northern stone castle border with central Northern Gate (cols 19..20)
	for x: int in range(MAP_COLS):
		if x == 19:
			wall_layer.set_cell(Vector2i(x, 0), 0, Vector2i(3, 9))
			ground_layer.set_cell(Vector2i(x, 1), 0, Vector2i(3, 10))
		elif x == 20:
			wall_layer.set_cell(Vector2i(x, 0), 0, Vector2i(4, 9))
			ground_layer.set_cell(Vector2i(x, 1), 0, Vector2i(4, 10))
		elif x == 18 or x == 21:
			wall_layer.set_cell(Vector2i(x, 0), 0, Vector2i(4, 8))
			wall_layer.set_cell(Vector2i(x, 1), 0, Vector2i(5, 10))
		else:
			wall_layer.set_cell(Vector2i(x, 0), 0, Vector2i(4, 8))
			wall_layer.set_cell(Vector2i(x, 1), 0, Vector2i(6, 10))

	# Southern pine tree border (rows 26..27)
	for x: int in range(MAP_COLS):
		var is_autumn: bool = (x % 5 == 0)
		var top_coord := Vector2i(3, 0) if is_autumn else Vector2i(4, 0)
		var bot_coord := Vector2i(3, 1) if is_autumn else Vector2i(4, 1)
		wall_layer.set_cell(Vector2i(x, 26), 0, top_coord)
		wall_layer.set_cell(Vector2i(x, 27), 0, bot_coord)

	# West & East pine borders (cols 0..1 and 38..39)
	for y: int in range(2, 26, 2):
		for x: int in [0, 1, 38, 39]:
			var is_autumn: bool = ((x + y) % 4 == 0)
			var top_coord := Vector2i(3, 0) if is_autumn else Vector2i(4, 0)
			var bot_coord := Vector2i(3, 1) if is_autumn else Vector2i(4, 1)
			wall_layer.set_cell(Vector2i(x, y), 0, top_coord)
			wall_layer.set_cell(Vector2i(x, y + 1), 0, bot_coord)

	# Plaza well & North Gate signpost
	wall_layer.set_cell(Vector2i(26, 13), 0, Vector2i(8, 7))
	wall_layer.set_cell(Vector2i(26, 14), 0, Vector2i(8, 8))
	wall_layer.set_cell(Vector2i(17, 2), 0, Vector2i(11, 6))


func _build_ruined_hall() -> void:
	# Multi-tile 4x3 Royal Hall (from ASSET_MANIFEST.md Section 4.1)
	var hall := Node2D.new()
	hall.name = "RuinedHall"
	hall.position = Vector2(216.0, 132.0)

	var grid: Array = [
		[
			"res://assets/buildings/tiny_town_tile_0048.png",
			"res://assets/buildings/tiny_town_tile_0049.png",
			"res://assets/buildings/tiny_town_tile_0049.png",
			"res://assets/buildings/tiny_town_tile_0050.png",
		],
		[
			"res://assets/buildings/tiny_town_tile_0060.png",
			"res://assets/buildings/tiny_town_tile_0061.png",
			"res://assets/buildings/tiny_town_tile_0061.png",
			"res://assets/buildings/tiny_town_tile_0062.png",
		],
		[
			"res://assets/buildings/tiny_town_tile_0088.png",
			"res://assets/buildings/tiny_town_tile_0090.png",
			"res://assets/buildings/tiny_town_tile_0091.png",
			"res://assets/buildings/tiny_town_tile_0088.png",
		],
	]

	for r: int in range(grid.size()):
		var row_arr: Array = grid[r]
		for c: int in range(row_arr.size()):
			var spr := Sprite2D.new()
			spr.texture = load(str(row_arr[c])) as Texture2D
			spr.position = Vector2(-24.0 + c * 16.0, -16.0 + r * 16.0)
			hall.add_child(spr)

	var banner := Sprite2D.new()
	banner.texture = load("res://assets/tiles/tiny_dungeon_tile_0029.png") as Texture2D
	banner.position = Vector2(-24.0, 16.0)
	hall.add_child(banner)

	var hall_label := Label.new()
	hall_label.text = "Ruined Hall"
	hall_label.position = Vector2(-42.0, -40.0)
	hall_label.size = Vector2(84.0, 14.0)
	hall_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hall_label.add_theme_font_size_override("font_size", 6)
	hall_label.add_theme_color_override("font_color", Color(0.9, 0.92, 1.0, 0.95))
	hall_label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08, 1.0))
	hall_label.add_theme_constant_override("outline_size", 2)
	hall.add_child(hall_label)

	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(60.0, 36.0)
	col.shape = rect
	col.position = Vector2(0.0, -4.0)
	body.add_child(col)
	hall.add_child(body)

	entities_layer.add_child(hall)
	north_gate_area.set_meta("prompt", "[E] Northern Gate (Wild Frontier)")
