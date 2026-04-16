# ============================================================================
# LayoutGenomeMutator
# ============================================================================
## Applica mutazioni controllate a un LayoutGenome.
##
## RESPONSABILITÀ:
## - Mutare parametri di un gene esistente.
## - Aggiungere un operatore secondario.
## - Rimuovere un operatore secondario.
## - Riordinare operatori secondari.
##
## VINCOLI STRUTTURALI:
## - CONNECTOR e BACKBONE non possono essere rimossi.
## - Le mutazioni non devono rompere la struttura minima del genome.
# ============================================================================

class_name LayoutGenomeMutator
extends GenomeMutator


# ----------------------------------------------------------------------------
# COSTANTI DI CONTROLLO
# ----------------------------------------------------------------------------

## Indice da cui iniziano gli operatori modificabili.
## 0 = CONNECTOR
## 1 = BACKBONE
const FIRST_MUTABLE_INDEX: int = 2

## Numero massimo di operatori secondari consentiti.
const MAX_SECONDARY_OPERATORS: int = 4

## Numero di possibili operazioni di mutazione.
const MUTATION_CASES: int = 4


# ----------------------------------------------------------------------------
# ATTRIBUTI
# ----------------------------------------------------------------------------

var profile: RoomSizeProfile
var registry: OperatorRegistry
var rng: RandomNumberGenerator
var size: Vector2i


# ----------------------------------------------------------------------------
# COSTRUZIONE
# ----------------------------------------------------------------------------

func _init(_context: LayoutGenomaContext):
	profile = _context.size_profile
	registry = _context.operator_registry
	rng = _context.rng
	size = _context.size


# ----------------------------------------------------------------------------
# API PUBBLICA
# ----------------------------------------------------------------------------

func mutate(genome: Genome) -> Genome:
	
	var g: LayoutGenome = genome as LayoutGenome
	if g == null:
		return genome

	var clone: LayoutGenome = g.clone()
	
	match rng.randi_range(0, MUTATION_CASES - 1):
		0:
			_mutate_param(clone)
		1:
			_add_gene(clone)
		2:
			_remove_gene(clone)
		3:
			_swap_genes(clone)

	return clone


# ----------------------------------------------------------------------------
# MUTAZIONI
# ----------------------------------------------------------------------------

## Mutazione dei parametri di un gene secondario
func _mutate_param(g: LayoutGenome) -> void:
	
	if g.genes.is_empty():
		return
	
	var idx: int = rng.randi_range(0, g.genes.size() - 1)
	
	var gene: LayoutGene = g.genes[idx]
	
	# Istanza temporanea SOLO per generare parametri
	var dummy_context := OperatorContext.new(profile, rng, size) # mask non serve
	var op: LayoutOperator = registry.instantiate(gene.type, dummy_context, gene.params)
	
	if op == null:
		return
	
	op.mutate_params()
	# Mutazione statica dei parametri
	gene.params = op.params


## Aggiunta di un operatore secondario
func _add_gene(g: LayoutGenome) -> void:
	
	if g.genes.size() - FIRST_MUTABLE_INDEX >= MAX_SECONDARY_OPERATORS:
		return
	
	var secondary_types := registry.get_secondary_types()
	
	if secondary_types.is_empty():
		return
	
	var type: LayoutOperator.Type = secondary_types[
		rng.randi_range(0, secondary_types.size() - 1)
	]
	
	# Istanza temporanea SOLO per generare parametri
	var dummy_context := OperatorContext.new(profile, rng, size) # mask non serve
	var op: LayoutOperator = registry.instantiate(type, dummy_context, {})
	
	if op == null:
		return
	
	var params: Dictionary = op.create_random_params()
	
	g.genes.append(LayoutGene.new(type, params))


## Rimozione di un operatore secondario
func _remove_gene(g: LayoutGenome) -> void:
	
	if g.genes.size() <= FIRST_MUTABLE_INDEX:
		return
	
	var idx: int = rng.randi_range(
		FIRST_MUTABLE_INDEX,
		g.genes.size() - 1
	)
	
	g.genes.remove_at(idx)


## Riordino di due operatori secondari
func _swap_genes(g: LayoutGenome) -> void:
	
	if g.genes.size() <= FIRST_MUTABLE_INDEX + 1:
		return
	
	var a: int = rng.randi_range(
		FIRST_MUTABLE_INDEX,
		g.genes.size() - 1
	)
	
	var b: int = rng.randi_range(
		FIRST_MUTABLE_INDEX,
		g.genes.size() - 1
	)
	
	if a == b:
		return
	
	var tmp: LayoutGene = g.genes[a]
	g.genes[a] = g.genes[b]
	g.genes[b] = tmp
