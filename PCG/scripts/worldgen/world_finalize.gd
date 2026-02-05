# ============================================================================
# WorldFinalize
# ============================================================================
## Modulo di finalizzazione della generazione del livello.[br]
##
## [b]Responsabilità principali[/b]:[br]
## - Eseguire il merge finale dei [TileMapLayer] (stanze + corridoi).[br]
## - Inizializzare eventuali sistemi di autotiling con il seed della run.[br]
## - Instanziare il player nello spawn point corretto.[br]
## - Effettuare il setup minimo del player e registrarlo nel [GameManager].[br]
##[br]
## [b]Cosa NON fa[/b]:[br]
## - Non genera stanze, corridoi o grafi.[br]
## - Non decide lo spawn point: lo riceve già calcolato nel context.[br]
## - Non gestisce logiche runtime avanzate del player o del livello.[br]
##[br]
## [b]Dipendenze[/b]:[br]
## - [TileMapUtility]: per il merge dei [TileMapLayer].[br]
## - [WorldFinalizeContext]: fornisce tutti i riferimenti necessari.[br]
## - [GameManager]: registra il player attivo della run.[br]
##[br]
## [b]Note architetturali[/b]:[br]
## - Stateless: non mantiene stato interno, opera esclusivamente sui dati del context.[br]
## - Pensato per essere l’ultimo step della pipeline di generazione.[br]
# ============================================================================

extends RefCounted
class_name WorldFinalize


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Esegue la finalizzazione del mondo e lo rende giocabile.[br]
##[br]
## [param ctx]: WorldFinalizeContext [b]DTO[/b][br]
##[br]
## Ritorna:[br]
## - [TileMapLayer] finale risultante dal merge.[br]
## - [code]null[/code] in caso di errore critico (context invalido o player_scene mancante).[br]
##[br]
## Effetti collaterali:[br]
## - Instanzia il player nella scena.[br]
## - Registra il player nel [GameManager].[br]
## - Imposta parametri base di movimento del player.[br]
static func merge_and_spawn(ctx: WorldFinalizeContext) -> TileMapLayer:
	# -----------------------------------------------------------------------
	# Guard clauses
	# -----------------------------------------------------------------------

	# Il context e il level_root sono obbligatori per qualsiasi operazione.
	if ctx == null or ctx.level_root == null:
		push_error("WorldFinalize: context o level_root non valido")
		return null

	# Senza player_scene il livello non è giocabile: errore bloccante.
	if ctx.player_scene == null:
		push_error("WorldFinalize: player_scene is null")
		return null

	# -----------------------------------------------------------------------
	# Merge TileMapLayer
	# -----------------------------------------------------------------------

	# Unisce tutte le collision delle stanze e il corridoio in un unico layer finale.
	var final_layer: TileMapLayer = TileMapUtility.merge_tile_map_layer(ctx.level_root)

	# -----------------------------------------------------------------------
	# Autotiles seed
	# -----------------------------------------------------------------------

	# Se presente un sistema di autotiling, gli passiamo il seed della run
	# per garantire coerenza visiva e riproducibilità.
	if ctx.auto_tiles != null:
		ctx.auto_tiles.seed = ctx.seed

	# -----------------------------------------------------------------------
	# Player spawn
	# -----------------------------------------------------------------------

	# Instanzia il player e lo posiziona nello spawn point calcolato in precedenza.
	var p: Player = ctx.player_scene.instantiate()
	p.global_position = ctx.spawn_point
	ctx.level_root.add_child(p)

	# -----------------------------------------------------------------------
	# Player setup minimo
	# -----------------------------------------------------------------------

	# Abilitiamo i sistemi base: il player deve essere immediatamente controllabile.
	p.movement_enabled = true
	p.wall_check_enabled = true

	# Registrazione globale del player per accesso da altri sistemi runtime.
	GameManager.set_player(p)

	return final_layer
