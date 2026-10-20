class_name PageFlipMesh
extends Polygon2D

signal flip_finished

@export_range(4, 64, 1) var subdivisions_x: int = 24
@export_range(2, 32, 1) var subdivisions_y: int = 12
@export var fold_lift: float = 45.0

var _base_vertices := PackedVector2Array()
var _base_uv := PackedVector2Array()
var _base_colors := PackedColorArray()
var _grid_polygons: Array[PackedInt32Array] = []
var _book_size := Vector2.ZERO
var _page_width := 0.0
var _is_flipping := false
var _active_side: float = 1.0
var _progress := 0.0
var _direction := 1.0

func setup(book_size: Vector2, page_texture: Texture2D, page_width: float = 0.0) -> void:
	_book_size = book_size
	_page_width = book_size.x if page_width <= 0.0 else minf(page_width, book_size.x * 0.5)
	texture = page_texture
	_build_mesh()
	set_progress(0.0, _direction)

func begin_flip(direction: float) -> void:
	if _is_flipping or _book_size == Vector2.ZERO:
		return

	_is_flipping = true
	_direction = 1.0 if direction >= 0.0 else -1.0
	_active_side = _direction
	_build_mesh()
	set_progress(0.0, _direction)

func set_progress(progress: float, direction: float = 0.0) -> void:
	if _book_size == Vector2.ZERO:
		return

	if direction != 0.0:
		_direction = 1.0 if direction >= 0.0 else -1.0
	_active_side = _direction

	_progress = clampf(progress, 0.0, 1.0)
	var vertices := PackedVector2Array()
	var spine_x := _book_size.x * 0.5
	var angle := _progress * PI

	for base_vertex in _base_vertices:
		vertices.append(_deform_vertex(base_vertex, spine_x, angle))

	polygon = vertices

func finish_flip() -> void:
	_is_flipping = false
	set_progress(1.0, _direction)
	flip_finished.emit()

func _build_mesh() -> void:
	_base_vertices.clear()
	_base_uv.clear()
	_base_colors.clear()
	_grid_polygons.clear()

	var step_x := _book_size.x / subdivisions_x
	var step_y := _book_size.y / subdivisions_y
	var texture_size := texture.get_size() if texture else _book_size
	var spine_x := _book_size.x * 0.5

	for y in range(subdivisions_y + 1):
		for x in range(subdivisions_x + 1):
			var vertex := Vector2(x * step_x, y * step_y)
			_base_vertices.append(vertex)
			_base_uv.append(_get_uv(vertex, spine_x, texture_size))
			_base_colors.append(_get_color(vertex, spine_x))

	var row_width := subdivisions_x + 1
	for y in range(subdivisions_y):
		for x in range(subdivisions_x):
			var index := y * row_width + x
			_grid_polygons.append(PackedInt32Array([
				index,
				index + 1,
				index + row_width + 1,
				index + row_width
			]))

	polygon = _base_vertices
	uv = _base_uv
	vertex_colors = _base_colors
	polygons = _grid_polygons

func _get_color(vertex: Vector2, spine_x: float) -> Color:
	if _page_width >= _book_size.x:
		return Color.WHITE

	var distance := (vertex.x - spine_x) * _active_side
	return Color.WHITE if distance >= 0.0 and distance <= _page_width else Color.TRANSPARENT

func _get_uv(vertex: Vector2, spine_x: float, texture_size: Vector2) -> Vector2:
	if _page_width >= _book_size.x:
		return Vector2(
			vertex.x / _book_size.x * texture_size.x,
			vertex.y / _book_size.y * texture_size.y
		)

	var distance := absf(vertex.x - spine_x)
	var page_u := clampf(distance / _page_width, 0.0, 1.0)
	return Vector2(
		page_u * texture_size.x,
		vertex.y / _book_size.y * texture_size.y
	)

func _deform_vertex(base_vertex: Vector2, spine_x: float, angle: float) -> Vector2:
	var distance := (base_vertex.x - spine_x) * _active_side
	var on_turning_page := distance >= 0.0 and distance <= _page_width
	if not on_turning_page:
		return base_vertex

	var normalized_distance := distance / _page_width
	var projected_x := spine_x + distance * cos(angle) * _active_side
	var lift := sin(angle) * sin(normalized_distance * PI) * fold_lift
	var edge_factor := sin(normalized_distance * PI)
	var vertical_direction := -1.0 if base_vertex.y < _book_size.y * 0.5 else 1.0

	return Vector2(
		projected_x,
		base_vertex.y + lift * edge_factor * vertical_direction
	)
