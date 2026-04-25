extends CharacterBody3D

@export var grid_step: float = 3.0
@export var hop_duration: float = 0.16
@export var jump_height: float = 0.58
@export var turn_speed: float = 14.0
@export var start_position: Vector3 = Vector3(0, 0, 8)
@export var min_x: float = -6.0
@export var max_x: float = 6.0
@export var max_back_z: float = 11.0
@export var play_imported_animation: bool = false

var animation_player: AnimationPlayer = null
var is_hopping: bool = false
var hop_timer: float = 0.0
var hop_from: Vector3 = Vector3.ZERO
var hop_to: Vector3 = Vector3.ZERO
var queued_direction: Vector3 = Vector3.ZERO

@onready var visual: Node3D = $Visual

func _ready() -> void:
	add_to_group("player")
	global_position = start_position
	hop_from = start_position
	hop_to = start_position
	animation_player = _find_animation_player(self)

	if play_imported_animation:
		_play_available_animation()
	elif animation_player != null:
		animation_player.stop()

func _physics_process(delta: float) -> void:
	if is_hopping:
		_update_hop(delta)
		return

	var direction: Vector3 = _read_discrete_input()
	if direction != Vector3.ZERO:
		_start_hop(direction)

func _read_discrete_input() -> Vector3:
	if Input.is_action_just_pressed("move_forward"):
		return Vector3(0, 0, -1)
	if Input.is_action_just_pressed("move_back"):
		return Vector3(0, 0, 1)
	if Input.is_action_just_pressed("move_left"):
		return Vector3(-1, 0, 0)
	if Input.is_action_just_pressed("move_right"):
		return Vector3(1, 0, 0)
	return Vector3.ZERO

func _start_hop(direction: Vector3) -> void:
	var target: Vector3 = global_position + direction * grid_step
	target.x = clamp(target.x, min_x, max_x)
	target.z = min(target.z, max_back_z)
	target.y = 0.0

	if target.distance_to(global_position) < 0.05:
		return

	hop_from = global_position
	hop_to = target
	hop_timer = 0.0
	is_hopping = true

	_face_direction(direction)

func _update_hop(delta: float) -> void:
	hop_timer += delta
	var t: float = clamp(hop_timer / hop_duration, 0.0, 1.0)
	var smooth_t: float = t * t * (3.0 - 2.0 * t)

	var new_position: Vector3 = hop_from.lerp(hop_to, smooth_t)
	new_position.y = 0.0
	global_position = new_position

	visual.position.y = sin(t * PI) * jump_height

	if t >= 1.0:
		global_position = hop_to
		visual.position = Vector3.ZERO
		is_hopping = false

func _face_direction(direction: Vector3) -> void:
	rotation.y = atan2(-direction.x, -direction.z)

func reset_to_start() -> void:
	velocity = Vector3.ZERO
	global_position = start_position
	visual.position = Vector3.ZERO
	rotation.y = 0.0
	is_hopping = false
	hop_timer = 0.0
	hop_from = start_position
	hop_to = start_position

func _play_available_animation() -> void:
	if animation_player == null:
		return
	var animation_names: PackedStringArray = animation_player.get_animation_list()
	if animation_names.size() == 0:
		return
	animation_player.play(animation_names[0])

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var result: AnimationPlayer = _find_animation_player(child)
		if result != null:
			return result
	return null
