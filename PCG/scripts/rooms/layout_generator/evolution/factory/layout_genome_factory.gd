# ============================================================================
# LayoutGenomeFactory
# ============================================================================
## Factory responsabile della creazione e mutazione dei genomi.
##
## RESPONSABILITÀ:
## - Generare genomi iniziali validi.
## - Garantire la presenza degli operatori strutturali obbligatori.
## - Aggiungere opzionalmente operatori secondari.
##
## FILOSOFIA:
## - CONNECTOR e BACKBONE sono sempre presenti.
## - Gli operatori secondari sono opzionali e selezionati
##   tramite estrazione pesata.
## - Il genome contiene solo (type, params), non istanze.
# ============================================================================

class_name LayoutGenomeFactory
extends GenomeFactory


# ----------------------------------------------------------------------------
# ATTRIBUTI
# ----------------------------------------------------------------------------

var profile: RoomSizeProfile
var registry: OperatorRegistry
var size: Vector2i


# ----------------------------------------------------------------------------
# COSTRUZIONE
# ----------------------------------------------------------------------------

func _init(_context: LayoutGenomaContext) -> void:
	super._init(_context.rng)
	profile = _context.size_profile
	registry = _context.operator_registry
	size = _context.size


# ----------------------------------------------------------------------------
# CREAZIONE GENOMA
# ----------------------------------------------------------------------------

func random_genome() -> LayoutGenome:
	
	var genome: LayoutGenome = LayoutGenome.new()
	
	# ------------------------------------------------------------------------
	# 1) Operatori strutturali obbligatori
	# ------------------------------------------------------------------------
	
	_add_structural_operator(genome, LayoutOperator.Type.CONNECTOR)
	_add_structural_operator(genome, LayoutOperator.Type.BACKBONE)
	
	
	# ------------------------------------------------------------------------
	# 2) Operatori secondari opzionali
	# ------------------------------------------------------------------------
	
	var picker := OperatorPicker.new(registry, rng)
	
	# Numero casuale di secondari
	var secondary_count := rng.randi_range(1, 3)

	for i in secondary_count:
		var secondary_type := picker.pick_secondary()

		if secondary_type == -1:
			print("LayoutGenomeFactory.random_genome: nessun operatore secondario scelto")
			continue

		_add_operator(genome, secondary_type)

	return genome


# ----------------------------------------------------------------------------
# HELPER INTERNI
# ----------------------------------------------------------------------------

## Aggiunge un operatore strutturale al genome.
## Gli operatori strutturali sono sempre presenti.
func _add_structural_operator(
	genome: LayoutGenome,
	type: LayoutOperator.Type
) -> void:
	
	# Istanza temporanea SOLO per generare parametri
	var dummy_context := OperatorContext.new(profile, rng, size) # mask non serve
	var op: LayoutOperator = registry.instantiate(type, dummy_context, {})
	
	if op == null:
		push_error("LayoutGenomeFactory: operatore strutturale non registrato.")
		return
	
	var params: Dictionary = op.create_random_params()
	genome.genes.append(LayoutGene.new(type, params))


## Aggiunge un operatore generico al genome.
func _add_operator(
	genome: LayoutGenome,
	type: LayoutOperator.Type
) -> void:
	
	# Istanza temporanea SOLO per generare parametri
	var dummy_context := OperatorContext.new(profile, rng, size) # mask non serve
	var op: LayoutOperator = registry.instantiate(type, dummy_context, {})
	
	if op == null:
		push_error("LayoutGenomeFactory: operatore strutturale non registrato.")
		return
	
	var params: Dictionary = op.create_random_params()
	genome.genes.append(LayoutGene.new(type, params))
