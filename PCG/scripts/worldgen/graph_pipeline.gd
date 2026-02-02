# ============================================================================
# GraphPipeline
# ============================================================================
## Pipeline principale per generare un [MissionGraph] pronto per essere usato
## nella costruzione del livello.[br]
##
## Responsabilità principali:[br]
## - Risolvere/decidere il seed effettivo da usare (input seed vs cache).[br]
## - Costruire il grafo base ([BaseGraph]).[br]
## - Eseguire l'espansione grammaticale ([ExpandDriver]) entro il budget.[br]
## - Validare i vincoli (solvibilità) tramite [ConstraintValidator].[br]
## - Preparare un [RandomNumberGenerator] coerente con il seed scelto.[br]
## - Aggiornare il seed cache per le run successive ([CacheRng]).[br]
##
## Note architetturali:[br]
## - La pipeline è stateless: espone solo una funzione statica.[br]
## - In caso di grafo non solvibile, la pipeline NON genera rng/seed completi:
##   marca [member Result.solvable] a false e aggiorna la cache per il retry.[br]
## - Se [param randomize_seed] è true, il seed viene randomizzato e sovrascrive
##   quello derivato da input/cache.[br]
# ============================================================================

extends RefCounted
class_name GraphPipeline


# ---------------------------------------------------------------------------
# Result
# ---------------------------------------------------------------------------

## Risultato della pipeline.[br]
## [br]
## - [member solvable] true se il grafo passa i vincoli, false altrimenti.[br]
## - [member seed] seed effettivo usato per l'rng (quando solvable).[br]
## - [member rng] generatore randomico configurato (quando solvable).[br]
## - [member graph] grafo missioni generato (sempre presente, ma usalo solo se solvable).[br]
class Result:
	var solvable: bool = true
	var seed: int = 0
	var rng: RandomNumberGenerator = null
	var graph: MissionGraph = null


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Esegue la pipeline di generazione del grafo.[br]
## [br]
## Flusso:[br]
## 1) determina il seed effettivo (CacheRng se valido, altrimenti [param seed]).[br]
## 2) costruisce il grafo base.[br]
## 3) espande il grafo con la grammatica entro [param budget_nodes].[br]
## 4) valida la solvibilità: se fallisce, incrementa seed cache e ritorna.[br]
## 5) prepara l'rng: se randomize -> randomize(), altrimenti seed deterministico.[br]
## 6) aggiorna CacheRng con il seed effettivo usato.[br]
## [br]
## [param seed] Seed di partenza (usato se la cache non è attiva).[br]
## [param budget_nodes] Budget massimo di nodi per l'espansione.[br]
## [param randomize_seed] Se true, sovrascrive il seed con uno random.[br]
## [return] [GraphPipeline.Result] con stato della run e dati generati.[br]
static func run(seed: int, budget_nodes: int, randomize_seed: bool = false) -> Result:
	var r: Result = Result.new()
	
	var effective_seed: int = CacheRng.seed if CacheRng.cached else seed
	
	var G: MissionGraph = BaseGraph.build_base()
	ExpandDriver.run(G, budget_nodes)

	if not ConstraintValidator.solvable(G):
		r.solvable = false
		
		CacheRng.seed = effective_seed + 1
		CacheRng.cached = true
		
		return r

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	
	if randomize_seed: 
		rng.randomize()
		effective_seed = rng.seed
	
	r.rng = rng
	r.graph = G
	r.seed = effective_seed
	
	CacheRng.seed = effective_seed
	CacheRng.cached = true
	
	return r
