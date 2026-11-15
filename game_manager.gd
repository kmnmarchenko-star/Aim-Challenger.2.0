
extends Node

@export var target_scene: PackedScene
@export var camera: Camera3D

@export var spawn_distance: float = 60.0
@export var screen_margin: float = 0.15
@export var wave_time: float = 20.0

@export var base_targets: int = 3
@export var target_growth_rate: float = 0.10
@export var max_waves: int = 30

var targets_remaining: int = 0
var wave_number: int = 0
var wave_transitioning: bool = false
var game_finished: bool = false

var moving_targets: Array[Dictionary] = []
var spawned_targets: Array[Node3D] = []


func _ready():
	randomize()

	print("WaveManager started. ID: ", get_instance_id())

	if camera == null:
		push_error("Camera is not assigned!")
		return

	if target_scene == null:
		push_error("Target Scene is not assigned!")
		return

	spawn_wave()


func spawn_wave():
	if camera == null or target_scene == null or game_finished:
		return

	if wave_number >= max_waves:
		game_finished = true
		print("GAME OVER! You completed all ", max_waves, " waves!")
		return

	wave_number += 1
	wave_transitioning = false
	targets_remaining = 0
	moving_targets.clear()
	spawned_targets.clear()

	# 10% compound growth every round
	var target_count = ceili(
		base_targets * pow(1.0 + target_growth_rate, wave_number - 1)
	)

	print("Starting wave ", wave_number)
	print("Attempting to create ", target_count, " targets")

	var viewport_size = camera.get_viewport().get_visible_rect().size
	var used_positions: Array[Vector2] = []

	for i in range(target_count):
		var screen_position = Vector2.ZERO
		var valid_position = false
		var attempts = 0

		while not valid_position and attempts < 200:
			attempts += 1

			screen_position = Vector2(
				randf_range(viewport_size.x * screen_margin, viewport_size.x * (1.0 - screen_margin)),
				randf_range(viewport_size.y * screen_margin, viewport_size.y * (1.0 - screen_margin))
			)

			valid_position = true

			for previous_position in used_positions:
				if screen_position.distance_to(previous_position) < 180:
					valid_position = false
					break

		used_positions.append(screen_position)

		var target = target_scene.instantiate() as Node3D

		if target == null:
			push_error("Target scene root must be a Node3D!")
			continue

		target.add_to_group("targets")
		add_child(target)

		var spawn_position = screen_to_world(screen_position)
		spawn_position.y = maxf(spawn_position.y, 0.0)

		target.global_position = spawn_position

		spawned_targets.append(target)
		targets_remaining = spawned_targets.size()

		print("Created target ", targets_remaining, " at ", spawn_position)

		if wave_number >= 5:
			var direction = Vector2(
				randf_range(-1.0, 1.0),
				randf_range(-1.0, 1.0)
			).normalized()

			var speed = 1.5 + (wave_number - 5) * 0.5

			moving_targets.append({
				"target": target,
				"center": spawn_position,
				"offset": Vector2.ZERO,
				"velocity": direction * speed,
				"right": camera.global_transform.basis.x,
				"up": camera.global_transform.basis.y
			})

	print("TOTAL TARGETS CREATED: ", targets_remaining)
	print("WaveManager ID: ", get_instance_id())

	if targets_remaining == 0:
		push_error("No targets were created!")
		return

	start_wave_timer(wave_number)


func start_wave_timer(current_wave: int):
	await get_tree().create_timer(wave_time).timeout

	if current_wave != wave_number or wave_transitioning:
		return

	_on_wave_timeout()


func _on_wave_timeout():
	if wave_transitioning or game_finished:
		return

	print("TIME UP!")

	wave_transitioning = true

	var missed_targets = spawned_targets.size()

	if missed_targets > 0:
		camera.change_coins(-missed_targets)

	print("Missed targets: ", missed_targets)
	print("Lost ", missed_targets, " coins!")

	remove_all_targets()

	if wave_number >= max_waves:
		game_finished = true
		print("GAME OVER! You reached round 30.")
		return

	await get_tree().create_timer(2.0).timeout
	spawn_wave()


func remove_all_targets():
	for target in spawned_targets:
		if is_instance_valid(target):
			target.queue_free()

	spawned_targets.clear()
	targets_remaining = 0
	moving_targets.clear()


func _process(delta):
	if wave_number < 5 or game_finished:
		return

	for data in moving_targets:
		var target = data["target"]

		if not is_instance_valid(target):
			continue

		var offset: Vector2 = data["offset"]
		var velocity: Vector2 = data["velocity"]

		offset += velocity * delta

		var movement_limit = 3.0

		if abs(offset.x) > movement_limit:
			velocity.x *= -1

		if abs(offset.y) > movement_limit:
			velocity.y *= -1

		offset.x = clamp(offset.x, -movement_limit, movement_limit)
		offset.y = clamp(offset.y, -movement_limit, movement_limit)

		var center: Vector3 = data["center"]
		var right: Vector3 = data["right"]
		var up: Vector3 = data["up"]

		var new_position = center + right * offset.x + up * offset.y

		if new_position.y < 0.0:
			new_position.y = 0.0
			offset.y = 0.0
			velocity.y = abs(velocity.y)

		data["offset"] = offset
		data["velocity"] = velocity

		target.global_position = new_position


func target_destroyed(target: Node):
	if wave_transitioning or game_finished:
		return

	if not spawned_targets.has(target):
		print("WARNING: This target was not spawned by this WaveManager!")
		return

	spawned_targets.erase(target)
	targets_remaining = spawned_targets.size()

	print("Targets remaining: ", targets_remaining)

	if targets_remaining == 0:
		wave_transitioning = true

		print("Wave ", wave_number, " complete!")

		if wave_number >= max_waves:
			game_finished = true
			print("CONGRATULATIONS! YOU BEAT ALL 30 WAVES!")
			return

		await get_tree().create_timer(2.0).timeout
		spawn_wave()


func screen_to_world(screen_position: Vector2) -> Vector3:
	var ray_origin = camera.project_ray_origin(screen_position)
	var direction = camera.project_ray_normal(screen_position)

	return ray_origin + direction * spawn_distance
	
func game_over():
	if game_finished:
		return

	game_finished = true
	wave_transitioning = true

	print("GAME OVER! You ran out of coins!")

	remove_all_targets()

	if camera != null:
		camera.show_game_over()

	get_tree().paused = true
