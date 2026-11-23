extends Node

## Central single source of truth for persistent Crownfall game state.

signal stats_changed
signal resources_changed
signal day_advanced(new_day: int)
signal time_changed(new_time: float)
signal building_rebuilt(building_id: String, new_kingdom_level: int)
signal soil_plot_updated(plot_id: String)
signal toast_requested(message: String)
signal sleep_requested
signal zone_change_requested(target_zone: String, spawn_tag: String)
signal player_defeated
signal camera_shake_requested(intensity: float, duration: float)
signal dialogue_requested(speaker_name: String, portrait_path: String, lines: PackedStringArray, follow_up_shop_id: String)
signal shop_requested(shop_id: String)
signal dialogue_closed
signal boss_hp_changed(current: int, maximum: int, show_bar: bool)
signal boss_vanquished

const DAY_DURATION_SEC: float = 150.0
const SUNWHEAT_PRICE: int = 12
const GOLDEN_WHEAT_PRICE: int = 35
const MONSTER_SHARD_PRICE: int = 15
const BLIGHT_SHARD_PRICE: int = 30

const BUILDING_COSTS: Dictionary = {
	"farmstead": {
		"name": "Royal Farmstead",
		"villager": "Old Pip",
		"gold": 30,
		"crops": 3,
		"monster_shards": 0,
		"blight_shards": 0,
	},
	"forge": {
		"name": "The Forge",
		"villager": "Gideon",
		"gold": 60,
		"crops": 0,
		"monster_shards": 4,
		"blight_shards": 0,
	},
	"apothecary": {
		"name": "The Apothecary",
		"villager": "Astrid",
		"gold": 80,
		"crops": 5,
		"monster_shards": 3,
		"blight_shards": 0,
	},
	"gatehouse": {
		"name": "The Gatehouse",
		"villager": "Captain Vance",
		"gold": 140,
		"crops": 6,
		"monster_shards": 0,
		"blight_shards": 3,
	},
}

var hp: int = 100
var max_hp: int = 100
var royal_gauge: float = 0.0
var max_royal_gauge: float = 100.0
var gold: int = 20
var crops_count: int = 0
var gold_crops_count: int = 0
var gold_seeds_count: int = 0
var monster_shards: int = 0
var blight_shards: int = 0
var flask_count: int = 1
var sword_level: int = 1
var armor_level: int = 0
var shield_upgraded: bool = false
var spin_slash_unlocked: bool = false
var kingdom_level: int = 0
var rebuilt_buildings: Dictionary = {
	"farmstead": false,
	"forge": false,
	"apothecary": false,
	"gatehouse": false,
}
var day_number: int = 1
var time_of_day: float = 0.15
var is_safe_zone: bool = true
var comeback_buff_timer: float = 0.0
var flask_buff_timer: float = 0.0
var soil_plots_state: Dictionary = {}
var talked_villagers: Dictionary = {}
var boss_defeated: bool = false
var total_crops_harvested: int = 0
var total_projectiles_bounced: int = 0
var is_sleeping: bool = false
var is_ui_open: bool = false
var skip_title_once: bool = false
var _hit_stop_active: bool = false


## Restores every persistent value to its New Game default (used by Replay / Return to Title).
func reset_state() -> void:
	hp = 100
	max_hp = 100
	royal_gauge = 0.0
	max_royal_gauge = 100.0
	gold = 20
	crops_count = 0
	gold_crops_count = 0
	gold_seeds_count = 0
	monster_shards = 0
	blight_shards = 0
	flask_count = 1
	sword_level = 1
	armor_level = 0
	shield_upgraded = false
	spin_slash_unlocked = false
	kingdom_level = 0
	rebuilt_buildings = {
		"farmstead": false,
		"forge": false,
		"apothecary": false,
		"gatehouse": false,
	}
	day_number = 1
	time_of_day = 0.15
	is_safe_zone = true
	comeback_buff_timer = 0.0
	flask_buff_timer = 0.0
	soil_plots_state = {}
	talked_villagers = {}
	boss_defeated = false
	total_crops_harvested = 0
	total_projectiles_bounced = 0
	is_sleeping = false
	is_ui_open = false
	_hit_stop_active = false
	Engine.time_scale = 1.0


func advance_time(delta: float) -> void:
	if is_sleeping or is_ui_open:
		return
	time_of_day += delta / DAY_DURATION_SEC
	if time_of_day >= 1.0:
		time_of_day = fmod(time_of_day, 1.0)
	time_changed.emit(time_of_day)


func get_time_phase_name() -> String:
	if time_of_day < 0.35:
		return "Morning"
	if time_of_day < 0.60:
		return "Afternoon"
	if time_of_day < 0.72:
		return "Dusk"
	return "Night"


func get_sell_multiplier() -> float:
	if bool(rebuilt_buildings.get("apothecary", false)):
		return 1.5
	return 1.0


func get_pending_crop_sale_value() -> int:
	var base_value: float = float(crops_count * SUNWHEAT_PRICE + gold_crops_count * GOLDEN_WHEAT_PRICE)
	return int(round(base_value * get_sell_multiplier()))


func get_pending_shard_sale_value() -> int:
	var base_value: float = float(monster_shards * MONSTER_SHARD_PRICE + blight_shards * BLIGHT_SHARD_PRICE)
	return int(round(base_value * get_sell_multiplier()))


func sell_goods_at_crate() -> Dictionary:
	var crop_value: int = get_pending_crop_sale_value()
	if crop_value > 0:
		var sold_count: int = get_total_crops()
		crops_count = 0
		gold_crops_count = 0
		gold += crop_value
		resources_changed.emit()
		return {"gold": crop_value, "kind": "crops", "count": sold_count}

	var shard_value: int = get_pending_shard_sale_value()
	if shard_value > 0:
		var sold_shards: int = monster_shards + blight_shards
		monster_shards = 0
		blight_shards = 0
		gold += shard_value
		resources_changed.emit()
		return {"gold": shard_value, "kind": "shards", "count": sold_shards}

	return {"gold": 0, "kind": "none", "count": 0}


func get_total_crops() -> int:
	return crops_count + gold_crops_count


func can_afford_building(building_id: String) -> bool:
	if not BUILDING_COSTS.has(building_id):
		return false
	if bool(rebuilt_buildings.get(building_id, false)):
		return false
	var cost: Dictionary = BUILDING_COSTS[building_id]
	return (
		gold >= int(cost["gold"])
		and get_total_crops() >= int(cost["crops"])
		and monster_shards >= int(cost["monster_shards"])
		and blight_shards >= int(cost["blight_shards"])
	)


func get_missing_building_text(building_id: String) -> String:
	if not BUILDING_COSTS.has(building_id):
		return "Unknown plot"
	var cost: Dictionary = BUILDING_COSTS[building_id]
	var missing: PackedStringArray = []
	var need_gold: int = max(0, int(cost["gold"]) - gold)
	var need_crops: int = max(0, int(cost["crops"]) - get_total_crops())
	var need_shards: int = max(0, int(cost["monster_shards"]) - monster_shards)
	var need_blight: int = max(0, int(cost["blight_shards"]) - blight_shards)
	if need_gold > 0:
		missing.append("%dG" % need_gold)
	if need_crops > 0:
		missing.append("%d Crops" % need_crops)
	if need_shards > 0:
		missing.append("%d Shards" % need_shards)
	if need_blight > 0:
		missing.append("%d Blight" % need_blight)
	return "Need " + ", ".join(missing)


func rebuild_building(building_id: String) -> bool:
	if not can_afford_building(building_id):
		return false

	var cost: Dictionary = BUILDING_COSTS[building_id]
	gold -= int(cost["gold"])
	_deduct_crops(int(cost["crops"]))
	monster_shards -= int(cost["monster_shards"])
	blight_shards -= int(cost["blight_shards"])

	rebuilt_buildings[building_id] = true
	var rebuilt_total: int = 0
	for key: Variant in rebuilt_buildings.keys():
		if bool(rebuilt_buildings[key]):
			rebuilt_total += 1
	kingdom_level = rebuilt_total

	if building_id == "forge":
		spin_slash_unlocked = true
	elif building_id == "gatehouse":
		shield_upgraded = true

	building_rebuilt.emit(building_id, kingdom_level)
	resources_changed.emit()
	stats_changed.emit()
	toast_requested.emit("%s rebuilt! %s returned." % [str(cost["name"]), str(cost["villager"])])
	return true


func get_soil_plot_state(plot_id: String) -> Dictionary:
	if soil_plots_state.has(plot_id):
		return (soil_plots_state[plot_id] as Dictionary).duplicate()
	return {
		"planted": false,
		"crop_type": "sunwheat",
		"stage": 0,
		"watered": false,
	}


func set_soil_plot_state(plot_id: String, state: Dictionary) -> void:
	soil_plots_state[plot_id] = state.duplicate()
	soil_plot_updated.emit(plot_id)


func advance_day_overnight() -> int:
	day_number += 1
	time_of_day = 0.15
	hp = max_hp

	var grew_count: int = 0
	for plot_id: Variant in soil_plots_state.keys():
		var state: Dictionary = soil_plots_state[plot_id]
		var planted: bool = bool(state.get("planted", false))
		var watered: bool = bool(state.get("watered", false))
		var crop_type: String = str(state.get("crop_type", "sunwheat"))
		var max_stage: int = 1 if crop_type == "golden_wheat" else 2
		var stage: int = int(state.get("stage", 0))

		if planted and watered and stage < max_stage:
			state["stage"] = stage + 1
			grew_count += 1

		if watered:
			state["watered"] = false

		soil_plots_state[plot_id] = state
		soil_plot_updated.emit(str(plot_id))

	day_advanced.emit(day_number)
	time_changed.emit(time_of_day)
	stats_changed.emit()
	return grew_count


func request_sleep() -> void:
	if is_sleeping or is_ui_open:
		return
	sleep_requested.emit()


func show_toast(message: String) -> void:
	toast_requested.emit(message)


func request_zone_change(target_zone: String, spawn_tag: String) -> void:
	zone_change_requested.emit(target_zone, spawn_tag)


func tick_buffs(delta: float) -> void:
	if is_sleeping or is_ui_open:
		return
	var changed: bool = false
	if comeback_buff_timer > 0.0:
		comeback_buff_timer = maxf(0.0, comeback_buff_timer - delta)
		changed = true
	if flask_buff_timer > 0.0:
		flask_buff_timer = maxf(0.0, flask_buff_timer - delta)
		changed = true
	if changed:
		stats_changed.emit()


func get_speed_multiplier() -> float:
	var mult: float = 1.0
	if comeback_buff_timer > 0.0:
		mult += 0.2
	if flask_buff_timer > 0.0:
		mult += 0.2
	return mult


func get_damage_multiplier() -> float:
	var mult: float = 1.0
	if comeback_buff_timer > 0.0:
		mult += 0.2
	if flask_buff_timer > 0.0:
		mult += 0.2
	return mult


func get_sword_damage() -> int:
	var base: int = 15
	if sword_level == 2:
		base = 25
	elif sword_level >= 3:
		base = 38
	return int(round(float(base) * get_damage_multiplier()))


func add_royal_gauge(amount: float) -> void:
	royal_gauge = clampf(royal_gauge + amount, 0.0, max_royal_gauge)
	stats_changed.emit()


func spend_royal_gauge(amount: float) -> bool:
	if royal_gauge < amount:
		return false
	royal_gauge = maxf(0.0, royal_gauge - amount)
	stats_changed.emit()
	return true


func apply_player_damage(amount: int) -> void:
	if is_sleeping or hp <= 0:
		return
	hp = max(0, hp - amount)
	stats_changed.emit()
	if hp <= 0:
		player_defeated.emit()


func heal_player(amount: int) -> void:
	hp = min(max_hp, hp + amount)
	stats_changed.emit()


func consume_flask() -> bool:
	if flask_count <= 0:
		return false
	flask_count -= 1
	hp = min(max_hp, hp + 50)
	flask_buff_timer = 15.0
	stats_changed.emit()
	resources_changed.emit()
	return true


func add_enemy_loot(gold_amt: int, m_shards: int, b_shards: int) -> void:
	gold += gold_amt
	monster_shards += m_shards
	blight_shards += b_shards
	resources_changed.emit()


func request_camera_shake(intensity: float, duration: float) -> void:
	camera_shake_requested.emit(intensity, duration)


func trigger_hit_stop(duration: float) -> void:
	if _hit_stop_active:
		return
	_hit_stop_active = true
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
	_hit_stop_active = false


func _deduct_crops(crops_needed: int) -> void:
	var take_regular: int = min(crops_count, crops_needed)
	crops_count -= take_regular
	var remaining: int = crops_needed - take_regular
	if remaining > 0:
		gold_crops_count = max(0, gold_crops_count - remaining)


func request_dialogue(speaker_name: String, portrait_path: String, lines: PackedStringArray, follow_up_shop_id: String = "") -> void:
	dialogue_requested.emit(speaker_name, portrait_path, lines, follow_up_shop_id)


func request_shop(shop_id: String) -> void:
	shop_requested.emit(shop_id)


func buy_golden_seeds(qty: int) -> bool:
	var cost: int = 15 * qty
	if qty <= 0 or gold < cost:
		return false
	gold -= cost
	gold_seeds_count += qty
	resources_changed.emit()
	return true


func upgrade_sword(target_level: int) -> bool:
	if target_level == 2 and sword_level == 1 and gold >= 50 and monster_shards >= 3:
		gold -= 50
		monster_shards -= 3
		sword_level = 2
		stats_changed.emit()
		resources_changed.emit()
		return true
	if target_level == 3 and sword_level == 2 and gold >= 100 and monster_shards >= 6:
		gold -= 100
		monster_shards -= 6
		sword_level = 3
		stats_changed.emit()
		resources_changed.emit()
		return true
	return false


func upgrade_royal_armor() -> bool:
	if armor_level >= 2 or gold < 60 or monster_shards < 4:
		return false
	gold -= 60
	monster_shards -= 4
	armor_level += 1
	max_hp += 25
	hp = min(max_hp, hp + 25)
	stats_changed.emit()
	resources_changed.emit()
	return true


func brew_harvest_flask() -> bool:
	if get_total_crops() < 2 or gold < 10:
		return false
	gold -= 10
	_deduct_crops(2)
	flask_count += 1
	stats_changed.emit()
	resources_changed.emit()
	return true


func sell_crops_only() -> int:
	var crop_value: int = get_pending_crop_sale_value()
	if crop_value <= 0:
		return 0
	crops_count = 0
	gold_crops_count = 0
	gold += crop_value
	resources_changed.emit()
	return crop_value


func sell_shards_only() -> int:
	var shard_value: int = get_pending_shard_sale_value()
	if shard_value <= 0:
		return 0
	monster_shards = 0
	blight_shards = 0
	gold += shard_value
	resources_changed.emit()
	return shard_value
