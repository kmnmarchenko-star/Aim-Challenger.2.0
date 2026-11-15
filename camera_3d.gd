
extends Camera3D

@onready var wave_manager = get_node_or_null("../../WaveManager")

@export var sensitivity: float = 0.002
@export var ray_length: float = 100.0
@export var shot_cooldown: float = 2.0

var pitch: float = 0.0
var coins: int = 0
var can_shoot: bool = true
var gun_level: int = 0
var bounce_back_owned: bool = false

# SHOP NODES
@onready var shop_button = get_node_or_null("CanvasLayer/ShopButton")
@onready var shop_panel = get_node_or_null("CanvasLayer/ShopPanel")

@onready var close_button = get_node_or_null("CanvasLayer/ShopPanel/CloseButton")
@onready var rapid_button = get_node_or_null("CanvasLayer/ShopPanel/RapidGunButton")
@onready var laser_button = get_node_or_null("CanvasLayer/ShopPanel/LaserGunButton")
@onready var minigun_button = get_node_or_null("CanvasLayer/ShopPanel/MinigunButton")
@onready var shotgun_button = get_node_or_null("CanvasLayer/ShopPanel/ShotgunButton")
@onready var blaster_button = get_node_or_null("CanvasLayer/ShopPanel/BlasterButton")
@onready var bounce_back_button = get_node_or_null("CanvasLayer/ShopPanel/BounceBackUpgrade")


func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	current = true

	print("CAMERA SCRIPT RUNNING!")

	if wave_manager == null:
		push_error("WaveManager NOT FOUND!")

	if shop_button != null:
		shop_button.pressed.connect(toggle_shop)

	if shop_panel != null:
		shop_panel.visible = false
	else:
		push_error("ShopPanel NOT FOUND!")

	if close_button != null:
		close_button.pressed.connect(close_shop)

	if rapid_button != null:
		rapid_button.pressed.connect(buy_rapid_gun)

	if laser_button != null:
		laser_button.pressed.connect(buy_laser_gun)

	if minigun_button != null:
		minigun_button.pressed.connect(buy_minigun)

	if shotgun_button != null:
		shotgun_button.pressed.connect(buy_shotgun)

	if blaster_button != null:
		blaster_button.pressed.connect(buy_blaster)

	if bounce_back_button != null:
		bounce_back_button.pressed.connect(buy_bounce_back)
	else:
		push_error("BounceBackUpgrade button NOT FOUND!")

	update_coins()


# INPUT
func _input(event):
	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			get_parent().rotate_y(-event.relative.x * sensitivity)
			pitch -= event.relative.y * sensitivity
			pitch = clamp(pitch, deg_to_rad(-89), deg_to_rad(89))
			rotation.x = pitch

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_B:
			toggle_shop()

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				shoot()


# SHOOTING
func shoot():
	if not can_shoot:
		print("WAIT FOR SHOOTING COOLDOWN!")
		return

	can_shoot = false

	print("SHOOTING! COOLDOWN: ", shot_cooldown)

	var space_state = get_world_3d().direct_space_state
	var origin = global_position
	var direction = -global_transform.basis.z
	var ray_end = origin + direction * ray_length

	var query = PhysicsRayQueryParameters3D.create(origin, ray_end)
	query.collide_with_bodies = true
	query.collide_with_areas = true

	var result = space_state.intersect_ray(query)
	var result_label = get_node_or_null("CanvasLayer/Crosshair/Result")

	if result.is_empty():
		if result_label != null:
			result_label.text = "MISS"
	else:
		var target = result.collider as Node

		while target != null and not target.is_in_group("targets"):
			target = target.get_parent()

		if target != null:
			var second_target = null

			if bounce_back_owned:
				second_target = find_bounce_target(target)

			destroy_target(target)

			if second_target != null and is_instance_valid(second_target):
				destroy_target(second_target)
				show_result(result_label, "BOUNCE HIT! +2")
			else:
				show_result(result_label, "TARGET HIT! +1")
		else:
			if result_label != null:
				result_label.text = "MISS"

	if shot_cooldown > 0.0:
		await get_tree().create_timer(shot_cooldown).timeout

	can_shoot = true


# FIND SECOND TARGET
func find_bounce_target(original_target: Node) -> Node:
	var nearest_target: Node = null
	var nearest_distance: float = INF

	for target in get_tree().get_nodes_in_group("targets"):
		if target == original_target:
			continue

		if not is_instance_valid(target):
			continue

		var distance = original_target.global_position.distance_to(
			target.global_position
		)

		if distance < nearest_distance:
			nearest_distance = distance
			nearest_target = target

	return nearest_target


# DESTROY TARGET
func destroy_target(target: Node):
	if not is_instance_valid(target):
		return

	if wave_manager != null:
		wave_manager.target_destroyed(target)

	target.queue_free()
	coins += 1
	update_coins()


func show_result(label: Label, message: String):
	if label == null:
		return

	label.text = message
	await get_tree().create_timer(1.5).timeout

	if label.text == message:
		label.text = ""


# COINS
func update_coins():
	var coins_label = get_node_or_null("CanvasLayer/Coins")

	if coins_label != null:
		coins_label.text = "Coins: " + str(coins)

	update_shop_buttons()


func change_coins(amount: int):
	coins += amount
	update_coins()

	print("Coins: ", coins)

	if coins < 0 and wave_manager != null:
		wave_manager.game_over()


func show_game_over():
	var game_over_label = get_node_or_null("CanvasLayer/GameOver")

	if game_over_label != null:
		game_over_label.visible = true
		game_over_label.text = "GAME OVER"

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# SHOP
func toggle_shop():
	if shop_panel == null:
		print("ERROR: SHOP PANEL NOT FOUND!")
		return

	if shop_panel.visible:
		close_shop()
	else:
		shop_panel.open_shop()


func close_shop():
	if shop_panel != null:
		shop_panel.close_shop()


# GUN PURCHASES
func buy_rapid_gun():
	buy_gun(1, 5, 1.5, "Auto Pistol")


func buy_laser_gun():
	buy_gun(2, 10, 1.0, "P90")


func buy_minigun():
	buy_gun(3, 20, 0.5, "M4A1-S")


func buy_shotgun():
	buy_gun(4, 30, 0.35, "AK-47")


func buy_blaster():
	buy_gun(5, 50, 0.0, "NEGEV")


# BOUNCE BACK PURCHASE
func buy_bounce_back():
	if bounce_back_owned:
		print("BOUNCE BACK ALREADY OWNED!")
		return

	if coins < 60:
		print("NOT ENOUGH COINS FOR BOUNCE BACK!")
		return

	coins -= 60
	bounce_back_owned = true

	print("BOUNCE BACK PURCHASED!")

	update_coins()


# PURCHASE SYSTEM
func buy_gun(level: int, price: int, cooldown: float, gun_name: String):
	print("ATTEMPTING TO BUY: ", gun_name)
	print("COINS: ", coins)
	print("CURRENT LEVEL: ", gun_level)

	if level != gun_level + 1:
		print("LOCKED: BUY THE PREVIOUS GUN FIRST!")
		return

	if coins < price:
		print("LOCKED: NOT ENOUGH COINS! Need ", price)
		update_shop_buttons()
		return

	coins -= price
	gun_level = level
	shot_cooldown = cooldown

	update_coins()

	print("PURCHASE SUCCESSFUL: ", gun_name)
	print("GUN LEVEL: ", gun_level)
	print("COINS LEFT: ", coins)
	print("NEW COOLDOWN: ", shot_cooldown)


# BUTTON UNLOCKING
func update_shop_buttons():

	if rapid_button != null:
		rapid_button.disabled = gun_level != 0 or coins < 5
		rapid_button.text = "Auto Pistol - 5 Coins"

	if laser_button != null:
		laser_button.disabled = gun_level != 1 or coins < 10
		laser_button.text = "P90 - 10 Coins"

	if minigun_button != null:
		minigun_button.disabled = gun_level != 2 or coins < 20
		minigun_button.text = "M4A1-S - 20 Coins"

	if shotgun_button != null:
		shotgun_button.disabled = gun_level != 3 or coins < 30
		shotgun_button.text = "AK-47 - 30 Coins"

	if blaster_button != null:
		blaster_button.disabled = gun_level != 4 or coins < 50
		blaster_button.text = "NEGEV - 50 Coins"

	if bounce_back_button != null:
		bounce_back_button.disabled = bounce_back_owned or coins < 60

		if bounce_back_owned:
			bounce_back_button.text = "BOUNCE BACK - OWNED"
		else:
			bounce_back_button.text = "BOUNCE BACK - 60 Coins"

	print("SHOP UPDATED")
	print("CURRENT GUN LEVEL: ", gun_level)
	print("CURRENT COINS: ", coins)
