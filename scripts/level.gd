extends Node3D

# Nivel procedural estilo Crossy Road:
# genera carriles, pasto y vehículos conforme el jugador avanza.
# La partida continúa hasta que el jugador choca con un vehículo.

@export var npc_scene: PackedScene
@export var lane_width: float = 18.0
@export var lane_spacing: float = 3.0
@export var start_z: float = 8.0
@export var initial_rows: int = 14
@export var generation_ahead: float = 48.0
@export var cleanup_behind: float = 18.0
@export var vehicle_spawn_margin: float = 3.6

var attempts: int = 0
var score: int = 0
var best_score: int = 0
var can_receive_hit: bool = true
var generated_until_z: float = 8.0
var rows: Dictionary = {}
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var mat_grass: StandardMaterial3D
var mat_dark_grass: StandardMaterial3D
var mat_road: StandardMaterial3D
var mat_line: StandardMaterial3D
var mat_tree: StandardMaterial3D
var mat_trunk: StandardMaterial3D
var mat_rock: StandardMaterial3D

@onready var player: CharacterBody3D = $Player
@onready var generated_world: Node3D = $GeneratedWorld
@onready var message_label: Label = $UI/Panel/MessageLabel
@onready var score_label: Label = $UI/Panel/ScoreLabel
@onready var attempts_label: Label = $UI/Panel/AttemptsLabel
@onready var message_timer: Timer = $MessageTimer

func _ready() -> void:
	add_to_group("game")
	rng.randomize()
	message_timer.timeout.connect(_clear_message)
	_create_materials()
	_reset_generated_world()
	_show_message("Muévete por casillas. Evita los vehículos.")
	_update_ui()

func _process(_delta: float) -> void:
	_generate_more_if_needed()
	_cleanup_old_rows()
	_update_score()
	_update_ui()

func player_hit_npc() -> void:
	if not can_receive_hit:
		return

	can_receive_hit = false
	attempts += 1
	best_score = max(best_score, score)

	player.reset_to_start()
	_reset_generated_world()
	_show_message("¡Golpeaste un vehiculo! Regresas al inicio.")

	await get_tree().create_timer(0.7).timeout
	can_receive_hit = true

func _reset_generated_world() -> void:
	for child in generated_world.get_children():
		child.queue_free()

	rows.clear()
	score = 0
	generated_until_z = start_z

	for i in range(initial_rows):
		var z: float = start_z - float(i) * lane_spacing
		_create_lane(z, i)
		generated_until_z = z

func _generate_more_if_needed() -> void:
	var ahead_limit: float = player.global_position.z - generation_ahead
	while generated_until_z > ahead_limit:
		var row_index: int = int(round((start_z - generated_until_z) / lane_spacing)) + 1
		generated_until_z -= lane_spacing
		_create_lane(generated_until_z, row_index)

func _cleanup_old_rows() -> void:
	var keys: Array = rows.keys()
	for key in keys:
		var z: float = float(key)
		if z > player.global_position.z + cleanup_behind:
			var row_node: Node = rows[key]
			if is_instance_valid(row_node):
				row_node.queue_free()
			rows.erase(key)

func _update_score() -> void:
	var advanced: float = max(0.0, start_z - player.global_position.z)
	score = int(floor(advanced / lane_spacing))

func _update_ui() -> void:
	score_label.visible = false
	score_label.text = ""
	attempts_label.text = "Intentos: %d" % attempts

func _show_message(text: String) -> void:
	message_label.text = text
	message_timer.start(2.8)

func _clear_message() -> void:
	message_label.text = ""

func _create_lane(z: float, row_index: int) -> void:
	var row_root: Node3D = Node3D.new()
	row_root.name = "Lane_%03d" % row_index
	generated_world.add_child(row_root)
	rows[z] = row_root

	var is_safe_start: bool = row_index < 2
	var is_road: bool = false

	if not is_safe_start:
		is_road = (row_index % 2 == 0) or rng.randf() < 0.45

	if is_road:
		_create_ground_piece(row_root, z, mat_road, "Road", 0.08)
		_create_lane_lines(row_root, z)
		_create_vehicles_for_lane(row_root, z, row_index)
	else:
		var material: StandardMaterial3D = mat_grass
		if row_index % 3 == 0:
			material = mat_dark_grass
		_create_ground_piece(row_root, z, material, "Grass", 0.1)
		_create_decorations(row_root, z, row_index)

func _create_ground_piece(parent: Node3D, z: float, material: StandardMaterial3D, node_name: String, height: float) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = node_name
	body.collision_layer = 16
	body.collision_mask = 0
	body.position = Vector3(0, -height * 0.5, z)
	parent.add_child(body)

	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(lane_width, height, lane_spacing * 0.96)
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	body.add_child(mesh_instance)

	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = mesh.size
	collision.shape = shape
	body.add_child(collision)

func _create_lane_lines(parent: Node3D, z: float) -> void:
	# La línea amarilla va en la división entre carriles, no en el centro.
	# Así el jugador y los vehículos se mueven por el centro real del carril.
	var boundary_z: float = z - lane_spacing * 0.5
	for x in [-7.0, -3.5, 0.0, 3.5, 7.0]:
		var line: MeshInstance3D = MeshInstance3D.new()
		line.name = "YellowLaneDivision"
		line.position = Vector3(x, 0.085, boundary_z)
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = Vector3(1.25, 0.03, 0.10)
		line.mesh = mesh
		line.material_override = mat_line
		parent.add_child(line)

func _create_vehicles_for_lane(parent: Node3D, z: float, row_index: int) -> void:
	if npc_scene == null:
		return

	var dir_value: float = 1.0
	if row_index % 2 != 0:
		dir_value = -1.0

	var max_vehicles: int = rng.randi_range(1, 3)
	parent.set_meta("max_vehicles", max_vehicles)
	parent.set_meta("vehicle_speed", 4.4 + min(float(row_index) * 0.08, 4.8) + rng.randf_range(0.0, 1.8))

	# Vehículos iniciales repartidos sobre el carril para que el nivel no se vea vacío.
	for i in range(max_vehicles):
		var initial_x: float = rng.randf_range(-lane_width * 0.45, lane_width * 0.45)
		_spawn_vehicle_for_lane(parent, z, row_index, dir_value, initial_x)

	# Después se generan vehículos nuevos desde el borde del mapa.
	var spawn_timer: Timer = Timer.new()
	spawn_timer.name = "VehicleSpawnTimer"
	spawn_timer.one_shot = false
	spawn_timer.wait_time = rng.randf_range(1.6, 3.0)
	parent.add_child(spawn_timer)
	spawn_timer.timeout.connect(_spawn_vehicle_for_lane.bind(parent, z, row_index, dir_value, 999999.0))
	spawn_timer.start()

func _spawn_vehicle_for_lane(parent: Node3D, z: float, row_index: int, dir_value: float, spawn_x: float = 999999.0) -> void:
	if npc_scene == null:
		return
	if not is_instance_valid(parent):
		return

	var max_vehicles: int = int(parent.get_meta("max_vehicles", 2))
	if _count_vehicles_in_lane(parent) >= max_vehicles:
		return

	var despawn_limit: float = (lane_width * 0.5) + vehicle_spawn_margin
	var start_x: float = -despawn_limit
	if dir_value < 0.0:
		start_x = despawn_limit

	var x_position: float = start_x
	if spawn_x < 900000.0:
		x_position = spawn_x

	var colors: Array[Color] = [
		Color(1.0, 0.08, 0.04, 1.0),
		Color(1.0, 0.75, 0.05, 1.0),
		Color(0.12, 0.35, 1.0, 1.0),
		Color(0.55, 0.12, 0.85, 1.0),
		Color(0.05, 0.75, 0.35, 1.0)
	]

	var vehicle: Node3D = npc_scene.instantiate() as Node3D
	vehicle.name = "Vehicle_%03d" % row_index
	vehicle.position = Vector3(x_position, 0.0, z)

	vehicle.set("direction", Vector3(dir_value, 0.0, 0.0))
	vehicle.set("despawn_x", despawn_limit)
	vehicle.set("speed", float(parent.get_meta("vehicle_speed", 5.0)))
	vehicle.set("main_color", colors[rng.randi_range(0, colors.size() - 1)])
	vehicle.set("cabin_color", Color(0.75, 0.92, 1.0, 1.0))

	parent.add_child(vehicle)

func _count_vehicles_in_lane(parent: Node3D) -> int:
	var total: int = 0
	for child in parent.get_children():
		if child.is_in_group("npc"):
			total += 1
	return total

func _create_decorations(parent: Node3D, z: float, row_index: int) -> void:
	if row_index < 2:
		return

	if rng.randf() < 0.55:
		var side: float = -1.0
		if rng.randf() < 0.5:
			side = 1.0
		_create_tree(parent, Vector3(side * rng.randf_range(6.8, 8.0), 0.0, z + rng.randf_range(-0.9, 0.9)))

	if rng.randf() < 0.35:
		var side_rock: float = -1.0
		if rng.randf() < 0.5:
			side_rock = 1.0
		_create_rock(parent, Vector3(side_rock * rng.randf_range(6.4, 7.9), 0.0, z + rng.randf_range(-0.9, 0.9)))

func _create_tree(parent: Node3D, position: Vector3) -> void:
	var tree: Node3D = Node3D.new()
	tree.name = "Tree"
	tree.position = position
	parent.add_child(tree)

	var trunk: MeshInstance3D = MeshInstance3D.new()
	trunk.position = Vector3(0, 0.45, 0)
	var trunk_mesh: BoxMesh = BoxMesh.new()
	trunk_mesh.size = Vector3(0.45, 0.9, 0.45)
	trunk.mesh = trunk_mesh
	trunk.material_override = mat_trunk
	tree.add_child(trunk)

	var top: MeshInstance3D = MeshInstance3D.new()
	top.position = Vector3(0, 1.15, 0)
	var top_mesh: BoxMesh = BoxMesh.new()
	top_mesh.size = Vector3(1.15, 1.0, 1.15)
	top.mesh = top_mesh
	top.material_override = mat_tree
	tree.add_child(top)

func _create_rock(parent: Node3D, position: Vector3) -> void:
	var rock: MeshInstance3D = MeshInstance3D.new()
	rock.name = "Rock"
	rock.position = Vector3(position.x, 0.28, position.z)
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(0.9, 0.55, 0.9)
	rock.mesh = mesh
	rock.material_override = mat_rock
	parent.add_child(rock)

func _create_materials() -> void:
	mat_grass = _make_material(Color(0.28, 0.78, 0.36, 1.0), 0.85)
	mat_dark_grass = _make_material(Color(0.17, 0.58, 0.25, 1.0), 0.9)
	mat_road = _make_material(Color(0.11, 0.12, 0.14, 1.0), 0.75)
	mat_line = _make_material(Color(1.0, 0.86, 0.15, 1.0), 0.6)
	mat_tree = _make_material(Color(0.08, 0.45, 0.18, 1.0), 0.9)
	mat_trunk = _make_material(Color(0.45, 0.25, 0.12, 1.0), 0.85)
	mat_rock = _make_material(Color(0.42, 0.45, 0.46, 1.0), 0.95)

func _make_material(color: Color, roughness: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material
