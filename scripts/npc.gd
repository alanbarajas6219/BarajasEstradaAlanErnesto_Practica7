extends CharacterBody3D

signal player_hit

@export var speed: float = 5.0
@export var direction: Vector3 = Vector3.RIGHT
@export var travel_distance: float = 28.0
@export var despawn_x: float = 14.5
@export var main_color: Color = Color(1.0, 0.1, 0.05, 1.0)
@export var cabin_color: Color = Color(0.65, 0.9, 1.0, 1.0)
@export var wheel_rotation_speed: float = 10.0

var hit_enabled: bool = true

@onready var car_body: MeshInstance3D = $Visual/CarBody
@onready var cabin: MeshInstance3D = $Visual/Cabin
@onready var wheel_fl: MeshInstance3D = $Visual/WheelFL
@onready var wheel_fr: MeshInstance3D = $Visual/WheelFR
@onready var wheel_bl: MeshInstance3D = $Visual/WheelBL
@onready var wheel_br: MeshInstance3D = $Visual/WheelBR

func _ready() -> void:
	add_to_group("npc")
	if direction == Vector3.ZERO:
		direction = Vector3.RIGHT
	direction = direction.normalized()
	_apply_vehicle_colors()
	_face_current_direction()

func _physics_process(delta: float) -> void:
	velocity = direction * speed
	move_and_slide()
	_spin_wheels(delta)

	if _is_outside_map():
		queue_free()

func _is_outside_map() -> bool:
	if direction.x > 0.0 and global_position.x > despawn_x:
		return true
	if direction.x < 0.0 and global_position.x < -despawn_x:
		return true
	return false

func _face_current_direction() -> void:
	rotation.y = atan2(direction.z, direction.x)

func _spin_wheels(delta: float) -> void:
	var amount: float = wheel_rotation_speed * delta * float(sign(direction.x))
	for wheel in [wheel_fl, wheel_fr, wheel_bl, wheel_br]:
		wheel.rotate_z(amount)

func _apply_vehicle_colors() -> void:
	var body_material: StandardMaterial3D = StandardMaterial3D.new()
	body_material.albedo_color = main_color
	body_material.roughness = 0.55
	car_body.material_override = body_material

	var cabin_material: StandardMaterial3D = StandardMaterial3D.new()
	cabin_material.albedo_color = cabin_color
	cabin_material.roughness = 0.35
	cabin.material_override = cabin_material

func _on_hitbox_body_entered(body: Node3D) -> void:
	if not hit_enabled:
		return

	if body.is_in_group("player"):
		hit_enabled = false
		player_hit.emit()
		get_tree().call_group("game", "player_hit_npc")
		await get_tree().create_timer(0.35).timeout
		hit_enabled = true
