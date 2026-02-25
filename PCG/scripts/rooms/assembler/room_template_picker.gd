# ============================================================================
# RoomTemplatePicker
# ============================================================================
## Modulo responsabile della selezione di un template stanza dal catalogo tramite
## scoring pesato.
##
## Responsabilità:
## - Iterare i template disponibili nel catalogo.
## - Applicare filtri hard tramite RoomTemplateRules:
##   - Compatibilità semantica: match per kind, oppure fallback per tag/ruoli ammessi.
##   - Ability gating: il template deve essere fattibile con le abilità correnti.
##   - Vincoli sui connettori: rispetto dei requisiti N/E/S/W del nodo.
## - Calcolare uno score pesato sui candidati validi (vincoli soft):
##   - Difficulty match (gaussiana).
##   - Skill bonus (sinergia “abilità”).
##   - Diversità (evita ripetizioni ravvicinate dello stesso ruolo).
##   - Coverage connettori (quanto bene il template copre ciò che serve).
## - Eseguire una weighted random pick.
##
## Nota di design:
## - Usa RoomTemplateInfo (DTO tipizzato), non Dictionary di meta.
## - Usa SOLO RoomAssemblerContext come input condiviso.
## - Fail-first: scarta un candidato non appena un vincolo hard fallisce.
##
## Nota su “ruolo”:
## - Il ruolo primario usato per la diversità è il kind del template (info.kind).
## - La logica di eleggibilità semantica è: prova match kind; se non combacia,
##   verifica se il template può “assumere” quel ruolo tramite tag/bitmask (rules).
# ============================================================================

extends RefCounted
class_name RoomTemplatePicker


# ---------------------------------------------------------------------------
# Tuning constants (no magic numbers)
# ---------------------------------------------------------------------------

## Numero di scelte recenti da considerare per la diversità.
const DIVERSITY_WINDOW: int = 6

## Penalità applicata per ogni ripetizione del ruolo (kind) nella window.
const DIVERSITY_PENALTY: float = 0.25

## Fattore minimo di diversità (clamp) per evitare annullamenti totali.
const DIVERSITY_MIN_FACTOR: float = 0.6

## Sigma della gaussiana per il matching di difficoltà (più alto = più permissivo).
const DIFF_SIGMA: float = 1.6

## Bonus se sia nodo che template sono “abilità-centrici”.
const SKILL_BONUS: float = 1.15

## Peso minimo per evitare zeri assoluti nel picker.
const MIN_WEIGHT: float = 0.0001

## Peso uniforme nel fallback minimo (solo ability gating).
const FALLBACK_MIN_WEIGHT: float = 0.5

## Difficoltà di default del nodo se non specificata.
const DEFAULT_NODE_DIFF: int = 1

## Coverage: valore usato quando non ho direzioni richieste (copertura perfetta).
const DEFAULT_COVERAGE: float = 1.0

## Coverage shaping: clamp per evitare pow(0,0) e degenerazioni numeriche.
const COVERAGE_EPS: float = 0.0001
const COVERAGE_MAX: float = 1.0

## Weighted pick: fallback index sicuro.
const FALLBACK_PICK_INDEX: int = 0

## Safety loop per picker/spawner (anti infinite loop).
const SAFETY_MAX_ITERS: int = 10_000

## Difficoltà: costante 2 per gaussiana (2*sigma^2).
const GAUSS_DENOM_FACTOR: float = 2.0

## Skill bonus: default quando non applicabile.
const NO_BONUS: float = 1.0


# ---------------------------------------------------------------------------
# State (diversity tracking)
# ---------------------------------------------------------------------------

## Sliding window dei ruoli scelti di recente.
## Qui “ruolo” = kind (ruolo primario), non tag secondari.
var _last_roles: Array[int] = []

## Conteggio scelte per ruolo (debug / telemetry).
var _used_counts: Dictionary[int, int] = {}


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Sceglie un template compatibile per un nodo del grafo.
##
## Pipeline:
## 1) Recupera keys dal catalogo e nodo logico dal context.
## 2) Pass 1: filtra (hard) + calcola score (soft) per ogni template candidato.
## 3) Pass 2: fallback minimo se nessun candidato supera i vincoli soft/hard.
## 4) Weighted pick e aggiornamento tracking diversità.
##
## [param context] RoomAssemblerContext condiviso.
## [param node_id] Id del nodo logico.
## [return] PackedScene scelto o null.
func pick(
	context: RoomAssemblerContext,
	node_id: String
) -> PackedScene:

	var keys: Array[String] = _catalog_keys_or_fail(context.catalog)
	if keys.is_empty():
		return null

	var node: MissionNode = context.node(node_id)
	if node == null:
		return null

	## Kind/ruolo logico del nodo corrente.
	var node_kind: int = int(node.kind)

	## Difficoltà logica del nodo (con fallback).
	var node_diff: int = _node_diff(node)

	# ------------------------------------------------------------
	# Pass 1: filtro hard + scoring completo
	# ------------------------------------------------------------
	var weights: Dictionary[String, float] = {}

	for key: String in keys:
		## Fail-first: se un template fallisce un vincolo hard, viene scartato subito.
		var info: RoomTemplateInfo = _eligible_info_or_null(
			context,
			key,
			node,
			node_kind
		)
		if info == null:
			continue

		## Score soft: se 0 o negativo, non entra nella competizione.
		var w: float = _score_candidate(context, info, node, node_diff)
		if w <= 0.0:
			continue

		## Clamp minimo per garantire la pick (evita pesi a 0).
		weights[key] = maxf(MIN_WEIGHT, w)

	# ------------------------------------------------------------
	# Pass 2: fallback minimo (solo ability gating)
	# ------------------------------------------------------------
	## Usato quando i vincoli semantici/connector/diff rendono vuoto il set.
	## Evita hard-fail del PCG: meglio una stanza “meno ideale” che null.
	if weights.is_empty():
		weights = _build_fallback_weights_ability_only(context, keys, node)

	## Fail-safe estremo: se ancora vuoto, prova a restituire la prima scena.
	if weights.is_empty():
		return context.catalog.get_scene(keys[FALLBACK_PICK_INDEX])

	return _pick_and_bookkeep(context, weights)


# ---------------------------------------------------------------------------
# Pipeline helpers
# ---------------------------------------------------------------------------

## Restituisce le keys del catalogo o [] con error logging se catalog nullo/vuoto.
func _catalog_keys_or_fail(catalog: RoomTemplateCatalog) -> Array[String]:
	if catalog == null:
		push_error("RoomTemplatePicker: catalog nullo")
		return []

	var keys := catalog.keys()
	if keys.is_empty():
		push_error("RoomTemplatePicker: catalog vuoto")
		return []

	return keys


## Estrae la difficoltà dal nodo logico.
## Nota: se il nodo non espone diff, usa DEFAULT_NODE_DIFF.
func _node_diff(node: MissionNode) -> int:
	var out: int = DEFAULT_NODE_DIFF
	if "diff" in node and typeof(node.diff) == TYPE_INT:
		out = int(node.diff)
	return out


## Verifica se un template è eleggibile per il nodo corrente.
##
## Vincoli hard (fail-first):
## 1) Catalog bans (cooldown/ban-list).
## 2) Compatibilità semantica (kind match o ruolo ammesso via tag/bitmask).
## 3) Ability gating.
## 4) Vincoli espliciti sui connettori.
##
## [return] RoomTemplateInfo se eleggibile, altrimenti null.
func _eligible_info_or_null(
	context: RoomAssemblerContext,
	key: String,
	node: MissionNode,
	node_kind: int
) -> RoomTemplateInfo:

	## Esclusione hard per ban-list (es. template già usato troppo di recente).
	if context.catalog.is_banned(key):
		return null

	var info: RoomTemplateInfo = context.catalog.info_of_key(key)
	if info == null:
		return null

	## 1) Compatibilità semantica.
	if not RoomTemplateRules.kind_match(info, node_kind):
		return null

	## 2) Ability gating.
	if not RoomTemplateRules.abilities_match(
		info,
		node.requires,
		node.logical_abilities_before
	):
		return null

	## 3) Requisiti espliciti sui connettori.
	if not RoomTemplateRules.satisfies_req(
		info,
		context.connector_req
	):
		return null

	return info


## Calcola lo score pesato di un candidato.
##
## Componenti soft:
## - cover: qualità del match dei connettori richiesti (0..1).
## - w_base: bias manuale del template.
## - w_diff: match di difficoltà con gaussiana.
## - w_skill: bonus se sia nodo che template sono “abilità-centrici”.
## - w_div: penalità per ripetizione ravvicinata dello stesso ruolo (kind).
func _score_candidate(
	context: RoomAssemblerContext,
	info: RoomTemplateInfo,
	node: MissionNode,
	node_diff: int
) -> float:
	var cover: float = _coverage_or_default(info, node, context.positions)
	cover = clamp(cover, COVERAGE_EPS, COVERAGE_MAX)

	var w_base: float = info.base_weight
	var w_diff: float = _difficulty_weight(info.difficulty, node_diff)
	var w_skill: float = _skill_bonus(node, info)

	## Ruolo primario per diversità: kind del template.
	var primary_role: int = int(info.kind)
	var w_div: float = _diversity_factor(primary_role)

	## Nota: shaping non lineare (pow) per amplificare differenze.
	return w_base * pow(cover, cover) * w_diff * w_skill * w_div


## Calcola coverage connettori richiesti dal nodo, derivati dalla posizione
## nel grafo (topologia).
func _coverage_or_default(
	info: RoomTemplateInfo,
	node: MissionNode,
	positions: Dictionary[String, Vector2i]
) -> float:
	var need_dirs: Array[String] = RoomTemplateRules.needed_connectors(node.id, positions)
	if need_dirs.is_empty():
		return DEFAULT_COVERAGE
	return RoomTemplateRules.connectors_coverage(info, need_dirs)


## Bonus sinergico: se nodo e template hanno entrambi requisiti di abilità.
func _skill_bonus(node: MissionNode, info: RoomTemplateInfo) -> float:
	if node.requires.is_empty():
		return NO_BONUS
	if info.requires.is_empty():
		return NO_BONUS
	return SKILL_BONUS


## Fallback: costruisce pesi uniformi considerando solo l’ability gating.
## Ignora compatibilità semantica e connettori (modalità “non bloccare il PCG”).
func _build_fallback_weights_ability_only(
	context: RoomAssemblerContext,
	keys: Array[String],
	node: MissionNode
) -> Dictionary[String, float]:

	var weights: Dictionary[String, float] = {}

	for key: String in keys:
		if context.catalog.is_banned(key):
			continue

		var info: RoomTemplateInfo = context.catalog.info_of_key(key)
		if info == null:
			continue

		if not RoomTemplateRules.abilities_match(
			info,
			node.requires,
			context.abilities
		):
			continue

		weights[key] = FALLBACK_MIN_WEIGHT

	return weights


## Esegue la pick pesata, restituisce la scena e aggiorna la diversità.
func _pick_and_bookkeep(
	context: RoomAssemblerContext,
	weights: Dictionary[String, float]
) -> PackedScene:

	var chosen_key: String = _weighted_pick(weights, context.rng)
	var chosen_scene: PackedScene = context.catalog.get_scene(chosen_key)
	if chosen_scene == null:
		return null

	var info: RoomTemplateInfo = context.catalog.info_of_key(chosen_key)
	if info != null:
		_bookkeep(info)

	return chosen_scene


# ---------------------------------------------------------------------------
# Scoring helpers
# ---------------------------------------------------------------------------

## Peso gaussiano sulla distanza di difficoltà.
##
## [param template_diff] Difficoltà del template.
## [param node_diff] Difficoltà del nodo.
## [return] Fattore (0..1].
func _difficulty_weight(template_diff: int, node_diff: int) -> float:
	var delta: float = abs(float(template_diff - node_diff))
	var sigma2: float = DIFF_SIGMA * DIFF_SIGMA
	return exp(-(delta * delta) / (GAUSS_DENOM_FACTOR * sigma2))


## Penalizza la ripetizione dei ruoli (kind) recenti.
##
## [param role] Kind del template (ruolo primario).
## [return] Fattore moltiplicativo clampato.
func _diversity_factor(role: int) -> float:
	var repeats: int = 0
	for r: int in _last_roles:
		if r == role:
			repeats += 1

	return maxf(
		DIVERSITY_MIN_FACTOR,
		NO_BONUS - DIVERSITY_PENALTY * float(repeats)
	)


## Weighted random pick su dict key->peso.
##
## Nota: l'ordine di iterazione di Dictionary non è garantito; qui si assume
## che l'uso sia deterministico “abbastanza” per PCG non-critical.
##
## [param weights] Dict key->peso.
## [param rng] RNG.
## [return] Key scelta.
func _weighted_pick(
	weights: Dictionary,
	rng: RandomNumberGenerator
) -> String:
	var sum: float = 0.0
	for k in weights.keys():
		sum += float(weights[k])

	var r: float = rng.randf() * sum
	for k in weights.keys():
		r -= float(weights[k])
		if r <= 0.0:
			return String(k)

	return String(weights.keys()[FALLBACK_PICK_INDEX])


# ---------------------------------------------------------------------------
# Book-keeping
# ---------------------------------------------------------------------------

## Aggiorna tracking diversità e contatori di utilizzo.
##
## [param info] Template scelto.
func _bookkeep(info: RoomTemplateInfo) -> void:
	## Ruolo primario = kind.
	var role: int = int(info.kind)

	_used_counts[role] = int(_used_counts.get(role, 0)) + 1

	_last_roles.append(role)
	if _last_roles.size() > DIVERSITY_WINDOW:
		_last_roles.pop_front()
