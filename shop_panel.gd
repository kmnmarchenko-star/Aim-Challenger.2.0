
extends Panel

func _ready():
	# Set the shop panel's size and position
	size = Vector2(500, 400)
	position = Vector2(200, 100)

	# Make sure the panel appears above other UI
	z_index = 100

	# Start with the shop closed
	visible = false

	print("SHOP PANEL READY!")


func open_shop():
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	print("SHOP OPENED!")


func close_shop():
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	print("SHOP CLOSED!")
