extends Control

## 100% Keyboard & Gamepad navigable villager shop menu (Pip, Gideon, Astrid).

signal shop_closed

@onready var title_icon: TextureRect = $CenterContainer/ShopPanel/VBox/Header/TitleIcon
@onready var title_label: Label = $CenterContainer/ShopPanel/VBox/Header/TitleLabel
@onready var wallet_label: Label = $CenterContainer/ShopPanel/VBox/Header/WalletLabel
@onready var subtitle_label: Label = $CenterContainer/ShopPanel/VBox/SubtitleLabel
@onready var items_vbox: VBoxContainer = $CenterContainer/ShopPanel/VBox/ItemsVBox

var _shop_id: String = ""
var _input_lock_timer: float = 0.0
var _buttons: Array[Button] = []
var _last_focus_idx: int = 0

var _style_normal: StyleBoxFlat
var _style_focus: StyleBoxFlat
var _style_pressed: StyleBoxFlat


func _ready() -> void:
	visible = false
	_init_button_styles()


func _process(delta: float) -> void:
	if visible and _input_lock_timer > 0.0:
		_input_lock_timer = maxf(0.0, _input_lock_timer - delta)


func _input(event: InputEvent) -> void:
	if not visible or _input_lock_timer > 0.0:
		return

	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close_shop()
		return

	if event.is_action_pressed("move_up") and not event.is_action_pressed("ui_up"):
		get_viewport().set_input_as_handled()
		_step_focus(-1)
		return

	if event.is_action_pressed("move_down") and not event.is_action_pressed("ui_down"):
		get_viewport().set_input_as_handled()
		_step_focus(1)
		return

	if event.is_action_pressed("interact") and not event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		var focused: Control = get_viewport().gui_get_focus_owner()
		if focused is Button and not (focused as Button).disabled:
			(focused as Button).emit_signal("pressed")


func open_shop(shop_id: String) -> void:
	_shop_id = shop_id
	_last_focus_idx = 0
	_input_lock_timer = 0.14
	GameState.is_ui_open = true
	visible = true
	AudioManager.play_ui_open()
	_rebuild_menu()


func _rebuild_menu() -> void:
	for child: Node in items_vbox.get_children():
		items_vbox.remove_child(child)
		child.queue_free()
	_buttons.clear()

	_refresh_header()

	match _shop_id:
		"pip":
			_populate_pip()
		"gideon":
			_populate_gideon()
		"astrid":
			_populate_astrid()

	_add_menu_button(
		"Close Menu",
		"",
		true,
		func() -> void: _close_shop()
	)

	_wire_focus_neighbors()
	var clamped_idx: int = clampi(_last_focus_idx, 0, max(0, _buttons.size() - 1))
	if not _buttons.is_empty():
		_buttons[clamped_idx].call_deferred("grab_focus")


func _refresh_header() -> void:
	wallet_label.text = "%dG  •  %d Crops  •  %d Shards" % [
		GameState.gold,
		GameState.get_total_crops(),
		GameState.monster_shards,
	]
	match _shop_id:
		"pip":
			title_icon.texture = load("res://assets/crops/tiny_town_tile_0094.png") as Texture2D
			title_label.text = "Old Pip's Seed Stall"
			subtitle_label.text = "Golden Seeds owned: %d (plant directly on tilled plots!)" % GameState.gold_seeds_count
		"gideon":
			title_icon.texture = load("res://assets/ui/tiny_dungeon_tile_0104.png") as Texture2D
			title_label.text = "Gideon's Royal Forge"
			var spin_txt: String = "Spin Slash [U/Q/Y] Ready!" if GameState.spin_slash_unlocked else "Forge Upgrades"
			subtitle_label.text = "%s  •  Sword Lv.%d (%d dmg)  •  Max HP %d" % [
				spin_txt,
				GameState.sword_level,
				GameState.get_sword_damage(),
				GameState.max_hp,
			]
		"astrid":
			title_icon.texture = load("res://assets/ui/tiny_dungeon_tile_0115.png") as Texture2D
			title_label.text = "Astrid's Apothecary"
			subtitle_label.text = "Flasks: %d  •  Apothecary +50%% Sell Bonus Active!" % GameState.flask_count


func _populate_pip() -> void:
	_add_menu_button(
		"Sunwheat Seeds  —  FREE (2 nights -> 12G / 18G)",
		"res://assets/tiles/tiny_town_tile_0027.png",
		true,
		func() -> void:
			AudioManager.play_ui_confirm()
			GameState.show_toast("Sunwheat seeds are free — press [E] on any empty soil plot!")
	)

	_add_menu_button(
		"Buy 1x Golden Wheat Seed  —  15G (1 night -> 35G / 52G)",
		"res://assets/crops/tiny_town_tile_0094.png",
		GameState.gold >= 15,
		func() -> void:
			if GameState.buy_golden_seeds(1):
				AudioManager.play_coins()
				GameState.show_toast("Bought 1 Golden Wheat Seed!")
				_rebuild_menu()
			else:
				AudioManager.play_ui_close()
				GameState.show_toast("Need 15G for Golden Wheat Seed!")
	)

	_add_menu_button(
		"Buy 3x Golden Wheat Seeds  —  45G",
		"res://assets/crops/tiny_town_tile_0094.png",
		GameState.gold >= 45,
		func() -> void:
			if GameState.buy_golden_seeds(3):
				AudioManager.play_coins()
				GameState.show_toast("Bought 3 Golden Wheat Seeds!")
				_rebuild_menu()
			else:
				AudioManager.play_ui_close()
				GameState.show_toast("Need 45G for 3x Golden Wheat Seeds!")
	)


func _populate_gideon() -> void:
	var lv2_label: String = "Sword Lv.2 (Iron Longsword)  —  OWNED"
	var lv2_ok: bool = false
	if GameState.sword_level < 2:
		lv2_label = "Upgrade Sword Lv.2 (15 -> 25 dmg)  —  50G + 3 Shards"
		lv2_ok = GameState.gold >= 50 and GameState.monster_shards >= 3
	_add_menu_button(
		lv2_label,
		"res://assets/ui/tiny_dungeon_tile_0104.png",
		lv2_ok,
		func() -> void:
			if GameState.upgrade_sword(2):
				AudioManager.play_rebuild()
				GameState.show_toast("Forged Iron Longsword (Lv.2)!")
				_rebuild_menu()
			else:
				AudioManager.play_ui_close()
				GameState.show_toast("Need 50G + 3 Monster Shards (or already owned).")
	)

	var lv3_label: String = "Sword Lv.3 (Royal Greatsword)  —  OWNED"
	var lv3_ok: bool = false
	if GameState.sword_level < 3:
		lv3_label = "Upgrade Sword Lv.3 (25 -> 38 dmg)  —  100G + 6 Shards"
		lv3_ok = GameState.sword_level == 2 and GameState.gold >= 100 and GameState.monster_shards >= 6
	_add_menu_button(
		lv3_label,
		"res://assets/ui/tiny_dungeon_tile_0107.png",
		lv3_ok,
		func() -> void:
			if GameState.upgrade_sword(3):
				AudioManager.play_rebuild()
				GameState.show_toast("Forged Royal Greatsword (Lv.3)!")
				_rebuild_menu()
			else:
				AudioManager.play_ui_close()
				GameState.show_toast("Requires Sword Lv.2, 100G & 6 Monster Shards!")
	)

	var armor_label: String = "Royal Armor (+25 Max HP)  —  MAXED (2/2)"
	var armor_ok: bool = false
	if GameState.armor_level < 2:
		armor_label = "Royal Armor (+25 Max HP) [%d/2]  —  60G + 4 Shards" % GameState.armor_level
		armor_ok = GameState.gold >= 60 and GameState.monster_shards >= 4
	_add_menu_button(
		armor_label,
		"res://assets/ui/tiny_dungeon_tile_0102.png",
		armor_ok,
		func() -> void:
			if GameState.upgrade_royal_armor():
				AudioManager.play_rebuild()
				GameState.show_toast("Royal Armor equipped! Max HP is now %d." % GameState.max_hp)
				_rebuild_menu()
			else:
				AudioManager.play_ui_close()
				GameState.show_toast("Need 60G + 4 Monster Shards (max 2 upgrades).")
	)


func _populate_astrid() -> void:
	_add_menu_button(
		"Brew Harvest Flask (+50 HP & 15s Buff)  —  2 Crops + 10G",
		"res://assets/ui/tiny_dungeon_tile_0115.png",
		GameState.get_total_crops() >= 2 and GameState.gold >= 10,
		func() -> void:
			if GameState.brew_harvest_flask():
				AudioManager.play_potion()
				GameState.show_toast("Brewed 1 Harvest Flask! (Now x%d)" % GameState.flask_count)
				_rebuild_menu()
			else:
				AudioManager.play_ui_close()
				GameState.show_toast("Need 2 Crops + 10G to brew a Harvest Flask!")
	)

	var crop_val: int = GameState.get_pending_crop_sale_value()
	_add_menu_button(
		"Sell All Crops (+50%% Bonus)  —  +%dG" % crop_val,
		"res://assets/crops/tiny_town_tile_0093.png",
		crop_val > 0,
		func() -> void:
			var earned: int = GameState.sell_crops_only()
			if earned > 0:
				AudioManager.play_coins()
				GameState.show_toast("Sold all crops at +50%% bonus for +%dG!" % earned)
				_rebuild_menu()
			else:
				AudioManager.play_ui_close()
				GameState.show_toast("No crops to sell!")
	)

	var shard_val: int = GameState.get_pending_shard_sale_value()
	_add_menu_button(
		"Sell All Shards (+50%% Bonus)  —  +%dG" % shard_val,
		"res://assets/ui/tiny_dungeon_tile_0130.png",
		shard_val > 0,
		func() -> void:
			var earned: int = GameState.sell_shards_only()
			if earned > 0:
				AudioManager.play_coins()
				GameState.show_toast("Sold all shards at +50%% bonus for +%dG!" % earned)
				_rebuild_menu()
			else:
				AudioManager.play_ui_close()
				GameState.show_toast("No shards to sell!")
	)


func _add_menu_button(label_text: String, icon_path: String, affordable: bool, callback: Callable) -> void:
	var btn := Button.new()
	var idx: int = _buttons.size()
	btn.text = label_text
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size = Vector2(0, 22)
	btn.focus_mode = Control.FOCUS_ALL
	btn.add_theme_font_size_override("font_size", 7)
	btn.add_theme_stylebox_override("normal", _style_normal)
	btn.add_theme_stylebox_override("hover", _style_focus)
	btn.add_theme_stylebox_override("focus", _style_focus)
	btn.add_theme_stylebox_override("pressed", _style_pressed)

	if affordable:
		btn.add_theme_color_override("font_color", Color(0.96, 0.95, 0.9, 1.0))
	else:
		btn.add_theme_color_override("font_color", Color(0.62, 0.58, 0.58, 0.85))
	btn.add_theme_color_override("font_focus_color", Color(1.0, 0.92, 0.45, 1.0))

	if not icon_path.is_empty():
		btn.icon = load(icon_path) as Texture2D
		btn.expand_icon = true

	btn.focus_entered.connect(func() -> void:
		_last_focus_idx = idx
		AudioManager.play_ui_move()
	)
	btn.pressed.connect(func() -> void:
		_last_focus_idx = idx
		callback.call()
	)

	items_vbox.add_child(btn)
	_buttons.append(btn)


func _wire_focus_neighbors() -> void:
	var count: int = _buttons.size()
	if count == 0:
		return
	for i: int in range(count):
		var prev_btn: Button = _buttons[(i - 1 + count) % count]
		var next_btn: Button = _buttons[(i + 1) % count]
		_buttons[i].focus_neighbor_top = _buttons[i].get_path_to(prev_btn)
		_buttons[i].focus_neighbor_bottom = _buttons[i].get_path_to(next_btn)


func _step_focus(dir: int) -> void:
	if _buttons.is_empty():
		return
	var next_idx: int = (_last_focus_idx + dir + _buttons.size()) % _buttons.size()
	_buttons[next_idx].grab_focus()


func _close_shop() -> void:
	if not visible:
		return
	visible = false
	AudioManager.play_ui_close()
	shop_closed.emit()
	await get_tree().process_frame
	GameState.is_ui_open = false


func _init_button_styles() -> void:
	_style_normal = StyleBoxFlat.new()
	_style_normal.bg_color = Color(0.14, 0.12, 0.19, 1.0)
	_style_normal.border_width_left = 1
	_style_normal.border_width_top = 1
	_style_normal.border_width_right = 1
	_style_normal.border_width_bottom = 1
	_style_normal.border_color = Color(0.32, 0.28, 0.38, 1.0)
	_style_normal.content_margin_left = 6.0
	_style_normal.content_margin_right = 6.0

	_style_focus = _style_normal.duplicate() as StyleBoxFlat
	_style_focus.bg_color = Color(0.24, 0.20, 0.31, 1.0)
	_style_focus.border_color = Color(1.0, 0.85, 0.35, 1.0)

	_style_pressed = _style_focus.duplicate() as StyleBoxFlat
	_style_pressed.bg_color = Color(0.32, 0.26, 0.38, 1.0)
