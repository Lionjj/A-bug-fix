# ============================================================================
# RoomTemplateSelectorBuckets
# ============================================================================
## Selettore template basato su bucket e requisiti connettori.[br]
##
## Strategia IDENTICA al vecchio RoomAssembler:[br]
## 1) filtra per ban + kind rules + abilità[br]
## 2) bucket exact (satisfies)[br]
## 3) bucket relaxed (relaxed_satisfies)[br]
## 4) fallback random tra candidati rimasti[br]
# ============================================================================

extends RefCounted
class_name RoomTemplateSelectorBuckets

const KIND_RULES: Dictionary = {
	"HUB":       {"require_tags_any": ["hub"],       "allow_kinds": ["ARENA"]},
	"CHALLENGE": {"require_tags_any": ["challenge","gap","shaft"]},
	"KEY_ROOM":  {"require_tags_any": ["key","ability","upgrade"]},
	"SAVE":      {"require_tags_any": ["save"]},
	"SIDE":      {"require_tags_any": ["side","optional"]},
}

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func pick(
	catalog: RoomTemplateCatalog,
	node: MissionNode,
	abilities: Array[Abilities.Ability],
	req: Dictionary[String, bool],
	rng: RandomNumberGenerator
) -> PackedScene:
	if catalog == null or node == null or rng == null:
		return null

	var node_kind: String = String(node.kind)
	var allow_kinds: Array = _allow_kinds_for(node_kind)

	# 1) candidati compatibili (ban + kind rules + abilità)
	var candidates: Array[String] = [] # keys
	for key in catalog.all_keys():
		if catalog.is_banned(key):
			continue

		var info: RoomTemplateInfo = catalog.info_of_key(key)
		if info == null:
			continue

		if not _kind_ok(info, node_kind):
			continue

		if not _abilities_ok(info.requires, node.requires, abilities):
			continue

		candidates.append(key)

	if candidates.is_empty():
		return null

	# 2) Exact match
	var buckets_exact := _bucketize(catalog, candidates, req, false, node_kind, allow_kinds)
	var chosen_key := _pick_from_buckets(buckets_exact, rng)
	if chosen_key != "":
		return catalog.scene_of(chosen_key)

	# 3) Relaxed match
	var buckets_relaxed := _bucketize(catalog, candidates, req, true, node_kind, allow_kinds)
	chosen_key = _pick_from_buckets(buckets_relaxed, rng)
	if chosen_key != "":
		return catalog.scene_of(chosen_key)

	# 4) Fallback random (identico al tuo)
	var fallback_key := candidates[rng.randi_range(0, candidates.size() - 1)]
	return catalog.scene_of(fallback_key)

# ---------------------------------------------------------------------------
# Bucketization
# ---------------------------------------------------------------------------

func _bucketize(
	catalog: RoomTemplateCatalog,
	candidate_keys: Array[String],
	req: Dictionary[String, bool],
	relaxed: bool,
	node_kind: String,
	allow_kinds: Array
) -> Dictionary:
	var out := {
		"kind": [] as Array[String],
		"tags": [] as Array[String],
		"any":  [] as Array[String],
	}

	for key in candidate_keys:
		var info: RoomTemplateInfo = catalog.info_of_key(key)
		if info == null:
			continue

		var ok := _relaxed_satisfies(info.connectors, req) if relaxed else _satisfies(info.connectors, req)
		if not ok:
			continue

		var strong_match := (info.kind == node_kind) or allow_kinds.has(info.kind)
		var tag_match := _tags_match(node_kind, info.tags)

		if strong_match:
			out["kind"].append(key)
		elif tag_match:
			out["tags"].append(key)
		else:
			out["any"].append(key)

	return out

func _pick_from_buckets(buckets: Dictionary, rng: RandomNumberGenerator) -> String:
	var a: Array[String] = buckets.get("kind", [])
	if not a.is_empty():
		return a[rng.randi_range(0, a.size() - 1)]

	a = buckets.get("tags", [])
	if not a.is_empty():
		return a[rng.randi_range(0, a.size() - 1)]

	a = buckets.get("any", [])
	if not a.is_empty():
		return a[rng.randi_range(0, a.size() - 1)]

	return ""

# ---------------------------------------------------------------------------
# Connectors constraints (IDENTICI)
# ---------------------------------------------------------------------------

# IDENTICO: req["N"] -> serve connectors["N"]
func _satisfies(conn: Dictionary[String, bool], req: Dictionary[String, bool]) -> bool:
	for d in ["N","E","S","W"]:
		if bool(req.get(d, false)) and not bool(conn.get(d, false)):
			return false
	return true

# IDENTICO: relaxed per asse
func _relaxed_satisfies(conn: Dictionary[String, bool], req: Dictionary[String, bool]) -> bool:
	var need_h := bool(req.get("E", false)) or bool(req.get("W", false))
	var need_v := bool(req.get("N", false)) or bool(req.get("S", false))

	if need_h and not (bool(conn.get("E", false)) or bool(conn.get("W", false))):
		return false
	if need_v and not (bool(conn.get("N", false)) or bool(conn.get("S", false))):
		return false

	return true

# ---------------------------------------------------------------------------
# Rules (IDENTICHE)
# ---------------------------------------------------------------------------

func _allow_kinds_for(node_kind: String) -> Array:
	var rule: Dictionary = KIND_RULES.get(node_kind, {})
	return rule.get("allow_kinds", [])

func _abilities_ok(
	template_requires: Array[Abilities.Ability],
	node_requires: Array,
	abilities: Array[Abilities.Ability]
) -> bool:
	for a in template_requires:
		if not abilities.has(a):
			return false
	for a in node_requires:
		if not abilities.has(a):
			return false
	return true

func _kind_ok(info: RoomTemplateInfo, node_kind: String) -> bool:
	if not KIND_RULES.has(node_kind):
		return true

	var rule: Dictionary = KIND_RULES[node_kind]
	if rule.has("require_tags_any"):
		for t in rule["require_tags_any"]:
			if info.tags.has(String(t)):
				return true
		return false

	return true

func _tags_match(node_kind: String, tags: Array[String]) -> bool:
	if not KIND_RULES.has(node_kind):
		return false

	var rule: Dictionary = KIND_RULES[node_kind]
	if not rule.has("require_tags_any"):
		return false

	for t in rule["require_tags_any"]:
		if tags.has(String(t)):
			return true

	return false
