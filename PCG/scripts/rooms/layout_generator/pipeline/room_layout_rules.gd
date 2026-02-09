# ============================================================================
# RoomLayoutRules
# ============================================================================
## Contiene le regole della shape grammar.
## Ogni funzione modifica una RoomLayoutMask.
# ============================================================================

class_name RoomLayoutRules
extends RefCounted

var room_mask: RoomLayoutMask
var rng: RandomNumberGenerator
var opening_policy: OpeningPolicy


func _init(_room_mask: RoomLayoutMask, _rng: RandomNumberGenerator, _opening_policy: OpeningPolicy) -> void:
	room_mask = _room_mask
	rng = _rng
	opening_policy = _opening_policy


# ---------------------------------------------------------------------------
# SeedRule
# ---------------------------------------------------------------------------

## Crea una stanza base sempre valida:
## - perimetro solido
## - interno vuoto
func apply_seed() -> void:
	var w: int = room_mask.size.x
	var h: int = room_mask.size.y

	for y in range(h):
		for x in range(w):
			var is_border: bool = (
				x < room_mask.wall_thickness or
				y < room_mask.wall_thickness or
				x >= w - room_mask.wall_thickness or
				y >= h - room_mask.wall_thickness
			)

			if is_border:
				room_mask.set_solid(x, y)
			else:
				room_mask.set_empty(x, y)


# ---------------------------------------------------------------------------
# Rientranza dal perimetro (base)
# ---------------------------------------------------------------------------

func apply_indent(side: int, width: int, depth: int) -> bool:
	var w: int = room_mask.size.x
	var h: int = room_mask.size.y
	var t: int = room_mask.wall_thickness

	# Vincolo minimo
	if width < t or depth < t:
		return false

	match side:
		Dir4.D.N:
			var x0: int = rng.randi_range(t, w - t - width)
			_set_solid_rect(x0, t, width, depth, [])

		Dir4.D.S:
			var x0: int = rng.randi_range(t, w - t - width)
			_set_solid_rect(x0, h - t - depth, width, depth, [])

		Dir4.D.W:
			var y0: int = rng.randi_range(t, h - t - width)
			_set_solid_rect(t, y0, depth, width, [])

		Dir4.D.E:
			var y0: int = rng.randi_range(t, h - t - width)
			_set_solid_rect(w - t - depth, y0, depth, width, [])

		_:
			return false

	return true


# ---------------------------------------------------------------------------
# Rientranza vincolata (no pocket, no strozzature, no collisione con connettori)
# ---------------------------------------------------------------------------

func apply_indent_constrained(
	side: int,
	width: int,
	depth: int,
	attempts: int = 20,
	min_passage_tiles: int = 4,
	connector_guard: int = 4
) -> bool:
	var plan: ConnectorPlan = room_mask.connector_plan
	if plan == null:
		return apply_indent(side, width, depth)

	var w: int = room_mask.size.x
	var h: int = room_mask.size.y
	var t: int = room_mask.wall_thickness

	if width < t or depth < t:
		return false

	for _i in range(attempts):
		var origin: int = _pick_indent_origin_avoiding_connectors(side, width, plan, connector_guard)
		if origin < 0:
			continue

		# 1) applico indent tracciando celle cambiate per rollback
		var changed: Array[int] = []
		_apply_indent_at(side, origin, width, depth, changed)

		# 2) vincoli
		var ok := true
		if not _is_layout_connected():
			ok = false
		elif not _passes_min_thickness(min_passage_tiles):
			ok = false
		elif not _connectors_have_landing(min_passage_tiles):
			ok = false

		if ok:
			return true

		# 3) rollback
		_rollback_cells(changed)

	return false


# ---------------------------------------------------------------------------
# Connector plan (fase 4)
# ---------------------------------------------------------------------------

func build_connector_plan(required_dirs: PackedInt32Array) -> ConnectorPlan:
	var plan: ConnectorPlan = ConnectorPlan.new()

	for d in required_dirs:
		var w_open: int = opening_policy.pick_width(rng, room_mask.size, room_mask.wall_thickness, d)
		var coord: int = opening_policy.pick_coord(rng, room_mask.size, room_mask.wall_thickness, d, w_open)
		plan.set_opening(d, coord, w_open)

	return plan


# ---------------------------------------------------------------------------
# Helpers: rect fill + rollback
# ---------------------------------------------------------------------------

func _set_solid_rect(x0: int, y0: int, rw: int, rh: int, changed: Array[int]) -> void:
	for y in range(y0, y0 + rh):
		for x in range(x0, x0 + rw):
			if not room_mask.in_bounds(x, y):
				continue
			if room_mask.is_empty(x, y):
				if not changed.is_empty():
					changed.append(room_mask._idx(x, y))
				room_mask.set_solid(x, y)


func _rollback_cells(changed: Array[int]) -> void:
	for idx in changed:
		room_mask.solid[idx] = 0


# ---------------------------------------------------------------------------
# Helpers: indent positioning (avoid connectors)
# ---------------------------------------------------------------------------

func _pick_indent_origin_avoiding_connectors(
	side: int,
	indent_width: int,
	plan: ConnectorPlan,
	connector_guard: int
) -> int:
	var w: int = room_mask.size.x
	var h: int = room_mask.size.y
	var t: int = room_mask.wall_thickness

	var minv: int = t
	var maxv: int

	# N/S => origin è x0; E/W => origin è y0
	if side == Dir4.D.N or side == Dir4.D.S:
		maxv = w - t - indent_width
	else:
		maxv = h - t - indent_width

	if maxv < minv:
		return -1

	var prot: Vector2i = _protected_interval_on_side(side, plan, connector_guard) # può essere null-like
	var has_prot: bool = (prot != Vector2i.ZERO) or plan.is_enabled(side)

	# reject sampling
	for _i in range(40):
		var v: int = rng.randi_range(minv, maxv)

		if has_prot and plan.is_enabled(side):
			var a: int = prot.x
			var b: int = prot.y
			var iv_a := v
			var iv_b := v + indent_width - 1
			# se interseca intervallo protetto => scarta
			if not (iv_b < a or iv_a > b):
				continue

		return v

	return -1


func _protected_interval_on_side(side: int, plan: ConnectorPlan, guard: int) -> Vector2i:
	if not plan.is_enabled(side):
		return Vector2i.ZERO

	var c: int = plan.get_coord(side)
	var w_open: int = plan.get_width(side)

	var neg: int = w_open / 2
	var pos: int = w_open - neg

	var a: int = c - neg - guard
	var b: int = c + pos - 1 + guard
	return Vector2i(a, b)


func _apply_indent_at(
	side: int,
	origin: int,
	width: int,
	depth: int,
	changed: Array[int]
) -> void:
	var w: int = room_mask.size.x
	var h: int = room_mask.size.y
	var t: int = room_mask.wall_thickness

	match side:
		Dir4.D.N:
			_set_solid_rect(origin, t, width, depth, changed)

		Dir4.D.S:
			_set_solid_rect(origin, h - t - depth, width, depth, changed)

		Dir4.D.W:
			_set_solid_rect(t, origin, depth, width, changed)

		Dir4.D.E:
			_set_solid_rect(w - t - depth, origin, depth, width, changed)


# ---------------------------------------------------------------------------
# Vincoli: connettività
# ---------------------------------------------------------------------------

func _is_layout_connected() -> bool:
	var w: int = room_mask.size.x
	var h: int = room_mask.size.y

	var seed: Vector2i = _find_nearest_empty(Vector2i(w / 2, h / 2))
	if seed == Vector2i(-1, -1):
		return false

	var visited := PackedByteArray()
	visited.resize(w * h)
	visited.fill(0)

	var q: Array[Vector2i] = [seed]
	visited[room_mask._idx(seed.x, seed.y)] = 1

	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		for step in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var n: Vector2i = c + step
			if not room_mask.in_bounds(n.x, n.y):
				continue
			if room_mask.is_solid(n.x, n.y):
				continue

			var ni: int = room_mask._idx(n.x, n.y)
			if visited[ni] != 0:
				continue

			visited[ni] = 1
			q.append(n)

	# se esiste una cella vuota non visitata -> pocket
	for y in range(h):
		for x in range(w):
			if room_mask.is_empty(x, y) and visited[room_mask._idx(x, y)] == 0:
				return false

	return true


func _find_nearest_empty(p: Vector2i) -> Vector2i:
	if room_mask.in_bounds(p.x, p.y) and room_mask.is_empty(p.x, p.y):
		return p

	var w: int = room_mask.size.x
	var h: int = room_mask.size.y
	var rmax: int = max(w, h)

	for r in range(1, rmax):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var q := p + Vector2i(dx, dy)
				if not room_mask.in_bounds(q.x, q.y):
					continue
				if room_mask.is_empty(q.x, q.y):
					return q

	return Vector2i(-1, -1)


# ---------------------------------------------------------------------------
# Vincoli: spessore minimo “giocabile”
# ---------------------------------------------------------------------------

func _passes_min_thickness(min_span: int) -> bool:
	var w: int = room_mask.size.x
	var h: int = room_mask.size.y

	for y in range(h):
		for x in range(w):
			if room_mask.is_solid(x, y):
				continue

			var sx: int = _span_empty_x(x, y)
			var sy: int = _span_empty_y(x, y)
			var thickness: int = min(sx, sy)

			if thickness < min_span:
				return false

	return true


func _span_empty_x(x: int, y: int) -> int:
	var a := x
	while a - 1 >= 0 and room_mask.is_empty(a - 1, y):
		a -= 1
	var b := x
	while b + 1 < room_mask.size.x and room_mask.is_empty(b + 1, y):
		b += 1
	return b - a + 1


func _span_empty_y(x: int, y: int) -> int:
	var a := y
	while a - 1 >= 0 and room_mask.is_empty(x, a - 1):
		a -= 1
	var b := y
	while b + 1 < room_mask.size.y and room_mask.is_empty(x, b + 1):
		b += 1
	return b - a + 1


# ---------------------------------------------------------------------------
# Vincoli: landing connettori (riga/colonna interna libera)
# ---------------------------------------------------------------------------

func _connectors_have_landing(min_span: int) -> bool:
	var plan: ConnectorPlan = room_mask.connector_plan
	if plan == null:
		return true

	var t: int = room_mask.wall_thickness
	var w_room: int = room_mask.size.x
	var h_room: int = room_mask.size.y

	for d in Dir4.ORDER:
		if not plan.is_enabled(d):
			continue

		var c: int = plan.get_coord(d)
		var w_open: int = plan.get_width(d)
		var neg: int = w_open / 2
		var pos: int = w_open - neg

		match d:
			Dir4.D.N:
				var y := t
				for dx in range(-neg, pos):
					var x := clampi(c + dx, 0, w_room - 1)
					if room_mask.is_solid(x, y): return false

			Dir4.D.S:
				var y := h_room - 1 - t
				for dx in range(-neg, pos):
					var x := clampi(c + dx, 0, w_room - 1)
					if room_mask.is_solid(x, y): return false

			Dir4.D.W:
				var x := t
				for dy in range(-neg, pos):
					var y := clampi(c + dy, 0, h_room - 1)
					if room_mask.is_solid(x, y): return false

			Dir4.D.E:
				var x := w_room - 1 - t
				for dy in range(-neg, pos):
					var y := clampi(c + dy, 0, h_room - 1)
					if room_mask.is_solid(x, y): return false

	return true
