extends Control

## Pixel-art HUD displaying player vitals, resources, day/time, kingdom progress, and toasts.

@onready var hp_bar: ProgressBar = $TopLeftPanel/VBox/HPRow/HPBar
@onready var hp_value_label: Label = $TopLeftPanel/VBox/HPRow/HPBar/HPValueLabel
@onready var royal_bar: ProgressBar = $TopLeftPanel/VBox/RoyalBar
@onready var flask_label: Label = $TopLeftPanel/VBox/HPRow/FlaskCountLabel

@onready var day_time_label: Label = $TopRightPanel/VBox/DayTimeLabel
@onready var kingdom_label: Label = $TopRightPanel/VBox/KingdomLabel

@onready var gold_label: Label = $BottomLeftPanel/HBox/GoldLabel
@onready var crops_label: Label = $BottomLeftPanel/HBox/CropsLabel
@onready var monster_shard_label: Label = $BottomLeftPanel/HBox/MonsterShardLabel
@onready var blight_shard_label: Label = $BottomLeftPanel/HBox/BlightShardLabel

@onready var toast_panel: PanelContainer = $ToastPanel
@onready var toast_label: Label = $ToastPanel/ToastLabel
@onready var buff_label: Label = $BuffLabel
@onready var controls_hint: Label = $ControlsHint
@onready var boss_bar_panel: PanelContainer = $BossBarPanel
@onready var boss_hp_bar: ProgressBar = $BossBarPanel/VBox/BossHPBar
@onready var boss_hp_label: Label = $BossBarPanel/VBox/BossHPBar/BossHPLabel

var _toast_tween: Tween = null


func _ready() -> void:
	toast_panel.visible = false
	toast_panel.modulate.a = 0.0
	boss_bar_panel.visible = false

	GameState.stats_changed.connect(_refresh_vitals)
	GameState.resources_changed.connect(_refresh_resources)
	GameState.day_advanced.connect(_on_day_or_time_changed)
	GameState.time_changed.connect(_on_time_changed)
	GameState.building_rebuilt.connect(_on_building_rebuilt)
	GameState.toast_requested.connect(_show_toast)
	GameState.boss_hp_changed.connect(_on_boss_hp_changed)

	_refresh_all()


func _refresh_all() -> void:
	_refresh_vitals()
	_refresh_resources()
	_refresh_day_time()
	_refresh_kingdom()


func _refresh_vitals() -> void:
	hp_bar.max_value = float(GameState.max_hp)
	hp_bar.value = float(GameState.hp)
	hp_value_label.text = "%d / %d" % [GameState.hp, GameState.max_hp]

	royal_bar.max_value = GameState.max_royal_gauge
	royal_bar.value = GameState.royal_gauge

	flask_label.text = "x%d" % GameState.flask_count

	if GameState.comeback_buff_timer > 0.0:
		buff_label.visible = true
		buff_label.text = "SECOND WIND %ds" % int(ceilf(GameState.comeback_buff_timer))
		buff_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35, 1.0))
	elif GameState.flask_buff_timer > 0.0:
		buff_label.visible = true
		buff_label.text = "FLASK BUFF %ds" % int(ceilf(GameState.flask_buff_timer))
		buff_label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.62, 1.0))
	else:
		buff_label.visible = false

	if GameState.is_safe_zone:
		controls_hint.text = "WASD/Stick: Move  •  E/A: Interact"
	else:
		controls_hint.text = "J/X: Slash • K/B: Parry • L/RB: Roll • U/Y: Spin • I/RT: Flask"


func _refresh_resources() -> void:
	gold_label.text = "%d" % GameState.gold
	crops_label.text = "%d" % GameState.get_total_crops()
	monster_shard_label.text = "%d" % GameState.monster_shards
	blight_shard_label.text = "%d" % GameState.blight_shards


func _on_day_or_time_changed(_new_day: int) -> void:
	_refresh_day_time()


func _on_time_changed(_new_time: float) -> void:
	_refresh_day_time()


func _refresh_day_time() -> void:
	day_time_label.text = "Day %d • %s" % [GameState.day_number, GameState.get_time_phase_name()]


func _on_building_rebuilt(_building_id: String, _new_level: int) -> void:
	_refresh_kingdom()


func _refresh_kingdom() -> void:
	kingdom_label.text = "Kingdom: %d/4" % GameState.kingdom_level


func _show_toast(message: String) -> void:
	toast_label.text = message
	toast_panel.visible = true
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()

	toast_panel.modulate.a = 0.0
	_toast_tween = create_tween()
	_toast_tween.tween_property(toast_panel, "modulate:a", 1.0, 0.16)
	_toast_tween.tween_interval(2.4)
	_toast_tween.tween_property(toast_panel, "modulate:a", 0.0, 0.35)
	_toast_tween.tween_callback(func() -> void: toast_panel.visible = false)


func _on_boss_hp_changed(current: int, maximum: int, show_bar: bool) -> void:
	boss_bar_panel.visible = show_bar
	if show_bar:
		boss_hp_bar.max_value = float(max(1, maximum))
		boss_hp_bar.value = float(clampi(current, 0, maximum))
		boss_hp_label.text = "%d / %d" % [current, maximum]
