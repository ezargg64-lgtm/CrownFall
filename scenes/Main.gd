extends Node2D

## Root scene manager: loads active zone, spawns Player, drives Day/Night tint & sleep fade.

const KINGDOM_HUB_SCENE: PackedScene = preload("res://scenes/zones/KingdomHub.tscn")
const WILD_FRONTIER_SCENE: PackedScene = preload("res://scenes/zones/WildFrontier.tscn")
const BOSS_ARENA_SCENE: PackedScene = preload("res://scenes/zones/BossArena.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/entities/Player.tscn")

@onready var zone_container: Node2D = $ZoneContainer
@onready var day_night_modulate: CanvasModulate = $DayNightModulate
@onready var dialogue_box: Control = $UILayer/DialogueBox
@onready var shop_ui: Control = $UILayer/ShopUI
@onready var end_screen: Control = $UILayer/EndScreen
@onready var fade_overlay: ColorRect = $UILayer/FadeOverlay

var _current_zone: Node2D = null
var _player: CharacterBody2D = null
var _is_transitioning: bool = false


func _ready() -> void:
	fade_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	GameState.sleep_requested.connect(_on_sleep_requested)
	GameState.zone_change_requested.connect(_on_zone_change_requested)
	GameState.player_defeated.connect(_on_player_defeated)
	GameState.dialogue_requested.connect(_on_dialogue_requested)
	GameState.shop_requested.connect(_on_shop_requested)
	GameState.boss_vanquished.connect(_on_boss_vanquished)

	end_screen.start_new_game_requested.connect(_on_start_new_game)
	end_screen.continue_after_victory_requested.connect(_on_continue_after_victory)
	end_screen.replay_requested.connect(_on_replay_requested)
	end_screen.return_to_title_requested.connect(_on_return_to_title)

	_load_zone(KINGDOM_HUB_SCENE, "default")
	_update_day_night_color()

	if GameState.skip_title_once:
		GameState.skip_title_once = false
		end_screen.call_deferred("show_intro")
	else:
		end_screen.call_deferred("show_title")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if not GameState.is_ui_open and not GameState.is_sleeping and not _is_transitioning and not end_screen.is_open():
			get_viewport().set_input_as_handled()
			end_screen.show_pause()


func _process(delta: float) -> void:
	GameState.advance_time(delta)
	GameState.tick_buffs(delta)
	_update_day_night_color()


func _load_zone(zone_scene: PackedScene, spawn_tag: String = "default") -> void:
	for child: Node in zone_container.get_children():
		child.queue_free()

	_current_zone = zone_scene.instantiate() as Node2D
	zone_container.add_child(_current_zone)

	_player = PLAYER_SCENE.instantiate() as CharacterBody2D
	var entities_parent: Node2D = _current_zone
	if _current_zone.has_method("get_entities_parent"):
		entities_parent = _current_zone.get_entities_parent()
	entities_parent.add_child(_player)

	if _current_zone.has_method("get_spawn_position"):
		_player.global_position = _current_zone.get_spawn_position(spawn_tag)
	if _current_zone.has_method("get_camera_bounds") and _player.has_method("set_camera_limits"):
		_player.set_camera_limits(_current_zone.get_camera_bounds())
	GameState.stats_changed.emit()


func _update_day_night_color() -> void:
	var t: float = GameState.time_of_day
	var target_color: Color
	if t < 0.15:
		var k: float = t / 0.15
		target_color = Color(0.62, 0.64, 0.82, 1.0).lerp(Color(1.0, 1.0, 1.0, 1.0), k)
	elif t < 0.55:
		target_color = Color(1.0, 1.0, 1.0, 1.0)
	elif t < 0.72:
		var k: float = (t - 0.55) / 0.17
		target_color = Color(1.0, 1.0, 1.0, 1.0).lerp(Color(0.92, 0.72, 0.64, 1.0), k)
	elif t < 0.84:
		var k: float = (t - 0.72) / 0.12
		target_color = Color(0.92, 0.72, 0.64, 1.0).lerp(Color(0.48, 0.52, 0.74, 1.0), k)
	else:
		var k: float = (t - 0.84) / 0.16
		target_color = Color(0.48, 0.52, 0.74, 1.0).lerp(Color(0.62, 0.64, 0.82, 1.0), k)

	day_night_modulate.color = target_color


func _on_sleep_requested() -> void:
	if GameState.is_sleeping:
		return
	GameState.is_sleeping = true
	AudioManager.play_gate()

	var tw: Tween = create_tween()
	tw.tween_property(fade_overlay, "color:a", 1.0, 0.35)
	await tw.finished

	var grew: int = GameState.advance_day_overnight()
	_update_day_night_color()
	await get_tree().create_timer(0.2).timeout

	var tw_out: Tween = create_tween()
	tw_out.tween_property(fade_overlay, "color:a", 0.0, 0.35)
	await tw_out.finished

	GameState.is_sleeping = false
	GameState.show_toast("Day %d! Full HP. %d crop(s) grew overnight." % [GameState.day_number, grew])


func _on_zone_change_requested(target_zone: String, spawn_tag: String) -> void:
	if _is_transitioning or GameState.is_sleeping:
		return
	var target_scene: PackedScene = null
	if target_zone == "wild_frontier":
		target_scene = WILD_FRONTIER_SCENE
	elif target_zone == "kingdom_hub":
		target_scene = KINGDOM_HUB_SCENE
	elif target_zone == "boss_arena":
		target_scene = BOSS_ARENA_SCENE
	else:
		return

	_is_transitioning = true
	GameState.is_ui_open = true
	AudioManager.play_gate()
	var tw: Tween = create_tween()
	tw.tween_property(fade_overlay, "color:a", 1.0, 0.18)
	await tw.finished

	if target_zone != "boss_arena":
		GameState.boss_hp_changed.emit(0, 350, false)
	_load_zone(target_scene, spawn_tag)
	_update_day_night_color()

	var tw_out: Tween = create_tween()
	tw_out.tween_property(fade_overlay, "color:a", 0.0, 0.18)
	await tw_out.finished

	if not dialogue_box.visible and not shop_ui.visible and not end_screen.is_open():
		GameState.is_ui_open = false
	_is_transitioning = false
	if target_zone == "wild_frontier":
		GameState.show_toast("Wild Frontier — J/X: Slash • K/B: Bounce Shield • L/RB: Roll")


func _on_player_defeated() -> void:
	if GameState.is_sleeping:
		return
	GameState.is_sleeping = true
	_is_transitioning = true
	GameState.boss_hp_changed.emit(0, 350, false)

	var tw: Tween = create_tween()
	tw.tween_property(fade_overlay, "color:a", 1.0, 0.4)
	await tw.finished

	var grew: int = GameState.advance_day_overnight()
	GameState.comeback_buff_timer = 30.0
	_load_zone(KINGDOM_HUB_SCENE, "default")
	_update_day_night_color()
	await get_tree().create_timer(0.25).timeout

	var tw_out: Tween = create_tween()
	tw_out.tween_property(fade_overlay, "color:a", 0.0, 0.4)
	await tw_out.finished

	GameState.is_sleeping = false
	_is_transitioning = false
	GameState.stats_changed.emit()
	GameState.show_toast("SECOND WIND! Full HP, +20%% Speed & Dmg (30s) • %d crop(s) grew!" % grew)


func _on_dialogue_requested(
	speaker_name: String,
	portrait_path: String,
	lines: PackedStringArray,
	follow_up_shop_id: String
) -> void:
	if dialogue_box.has_method("open_dialogue"):
		dialogue_box.open_dialogue(speaker_name, portrait_path, lines, follow_up_shop_id)


func _on_shop_requested(shop_id: String) -> void:
	if shop_ui.has_method("open_shop"):
		shop_ui.open_shop(shop_id)


func _on_start_new_game() -> void:
	GameState.show_toast("Tend the 3 starter plots & rebuild the Royal Farmstead first!")


func _on_boss_vanquished() -> void:
	await get_tree().create_timer(1.25).timeout
	if end_screen.has_method("show_victory"):
		end_screen.show_victory()


func _on_continue_after_victory() -> void:
	GameState.boss_hp_changed.emit(0, 350, false)
	GameState.request_zone_change("kingdom_hub", "default")


func _on_replay_requested() -> void:
	GameState.reset_state()
	GameState.skip_title_once = true
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_return_to_title() -> void:
	GameState.reset_state()
	GameState.skip_title_once = false
	get_tree().paused = false
	get_tree().reload_current_scene()
