extends Node2D

## Interactive crop tile supporting planting, watering, overnight growth, and harvesting.

@export var plot_id: String = "starter_0"
@export var requires_farmstead: bool = false

@onready var soil_sprite: Sprite2D = $SoilSprite
@onready var crop_sprite: Sprite2D = $CropSprite
@onready var lock_sprite: Sprite2D = $LockSprite
@onready var fx_particles: CPUParticles2D = $FXParticles

const TEX_SOIL_BASE: Texture2D = preload("res://assets/tiles/tiny_town_tile_0025.png")
const TEX_SOIL_SEEDED: Texture2D = preload("res://assets/tiles/tiny_town_tile_0041.png")
const TEX_SPROUT: Texture2D = preload("res://assets/tiles/tiny_town_tile_0017.png")
const TEX_MATURE_SUNWHEAT: Texture2D = preload("res://assets/tiles/tiny_town_tile_0027.png")
const TEX_MATURE_GOLDEN: Texture2D = preload("res://assets/crops/tiny_town_tile_0094.png")

var _bob_time: float = 0.0
var _is_mature: bool = false


func _ready() -> void:
	GameState.soil_plot_updated.connect(_on_soil_plot_updated)
	GameState.building_rebuilt.connect(_on_building_rebuilt)
	_refresh_visuals()


func _process(delta: float) -> void:
	if _is_mature and crop_sprite.visible:
		_bob_time += delta * 4.5
		crop_sprite.position.y = -2.0 + sin(_bob_time) * 1.0
	else:
		crop_sprite.position.y = -2.0


func _is_locked() -> bool:
	return requires_farmstead and not bool(GameState.rebuilt_buildings.get("farmstead", false))


func _get_max_stage(crop_type: String) -> int:
	return 1 if crop_type == "golden_wheat" else 2


func get_prompt_text() -> String:
	if _is_locked():
		return "Locked (Rebuild Farmstead)"

	var state: Dictionary = GameState.get_soil_plot_state(plot_id)
	var planted: bool = bool(state.get("planted", false))
	if not planted:
		if GameState.gold_seeds_count > 0:
			return "[E] Plant Golden Wheat (%d)" % GameState.gold_seeds_count
		return "[E] Plant Sunwheat"

	var crop_type: String = str(state.get("crop_type", "sunwheat"))
	var stage: int = int(state.get("stage", 0))
	var max_stage: int = _get_max_stage(crop_type)
	if stage >= max_stage:
		return "[E] Harvest Golden Wheat" if crop_type == "golden_wheat" else "[E] Harvest Sunwheat"

	var watered: bool = bool(state.get("watered", false))
	if not watered:
		return "[E] Water Crop"
	return "Watered (Sleep to grow)"


func interact(_player: Node2D) -> void:
	if _is_locked():
		GameState.show_toast("Rebuild the Royal Farmstead to unlock these 6 plots!")
		return

	var state: Dictionary = GameState.get_soil_plot_state(plot_id)
	var planted: bool = bool(state.get("planted", false))

	if not planted:
		var new_crop_type: String = "sunwheat"
		if GameState.gold_seeds_count > 0:
			GameState.gold_seeds_count -= 1
			new_crop_type = "golden_wheat"
			GameState.resources_changed.emit()

		state["planted"] = true
		state["crop_type"] = new_crop_type
		state["stage"] = 0
		state["watered"] = false
		GameState.set_soil_plot_state(plot_id, state)
		AudioManager.play_plant()
		_emit_fx(Color(0.86, 0.72, 0.35, 1.0))
		return

	var crop_type: String = str(state.get("crop_type", "sunwheat"))
	var stage: int = int(state.get("stage", 0))
	var max_stage: int = _get_max_stage(crop_type)

	if stage >= max_stage:
		if crop_type == "golden_wheat":
			GameState.gold_crops_count += 1
			GameState.show_toast("Harvested Golden Wheat!")
		else:
			GameState.crops_count += 1
			GameState.show_toast("Harvested Sunwheat!")
		GameState.total_crops_harvested += 1
		GameState.resources_changed.emit()
		GameState.set_soil_plot_state(plot_id, {
			"planted": false,
			"crop_type": "sunwheat",
			"stage": 0,
			"watered": false,
		})
		_emit_fx(Color(1.0, 0.88, 0.32, 1.0))
		AudioManager.play_harvest()
		return

	if not bool(state.get("watered", false)):
		state["watered"] = true
		GameState.set_soil_plot_state(plot_id, state)
		AudioManager.play_water()
		_emit_fx(Color(0.38, 0.72, 1.0, 1.0))
		return

	GameState.show_toast("Already watered! Sleep in Ruined Hall to grow.")


func _on_soil_plot_updated(updated_id: String) -> void:
	if updated_id == plot_id:
		_refresh_visuals()


func _on_building_rebuilt(building_id: String, _new_level: int) -> void:
	if building_id == "farmstead":
		_refresh_visuals()


func _refresh_visuals() -> void:
	var locked: bool = _is_locked()
	lock_sprite.visible = locked

	if locked:
		soil_sprite.texture = TEX_SOIL_BASE
		soil_sprite.modulate = Color(0.55, 0.55, 0.55, 0.85)
		crop_sprite.visible = false
		_is_mature = false
		return

	var state: Dictionary = GameState.get_soil_plot_state(plot_id)
	var planted: bool = bool(state.get("planted", false))
	var watered: bool = bool(state.get("watered", false))
	var crop_type: String = str(state.get("crop_type", "sunwheat"))
	var stage: int = int(state.get("stage", 0))
	var max_stage: int = _get_max_stage(crop_type)

	soil_sprite.modulate = Color(0.62, 0.48, 0.38, 1.0) if watered else Color(1.0, 1.0, 1.0, 1.0)

	if not planted:
		soil_sprite.texture = TEX_SOIL_BASE
		crop_sprite.visible = false
		_is_mature = false
		return

	if stage == 0:
		soil_sprite.texture = TEX_SOIL_SEEDED
		if crop_type == "golden_wheat" and not watered:
			soil_sprite.modulate = Color(1.0, 0.94, 0.72, 1.0)
		crop_sprite.visible = false
		_is_mature = false
		return

	soil_sprite.texture = TEX_SOIL_BASE
	crop_sprite.visible = true

	if stage >= max_stage:
		_is_mature = true
		crop_sprite.texture = TEX_MATURE_GOLDEN if crop_type == "golden_wheat" else TEX_MATURE_SUNWHEAT
		crop_sprite.modulate = Color(1.0, 0.96, 0.78, 1.0) if crop_type == "golden_wheat" else Color(1.0, 1.0, 1.0, 1.0)
	else:
		_is_mature = false
		crop_sprite.texture = TEX_SPROUT
		crop_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)


func _emit_fx(color: Color) -> void:
	fx_particles.color = color
	fx_particles.restart()
	fx_particles.emitting = true
