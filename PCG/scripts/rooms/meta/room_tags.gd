# ============================================================================
# RoomTags
# ============================================================================
## Definisce i **tag semantici** associabili ai template stanza.[br]
##
## Responsabilità:[br]
## - Fornire una codifica compatta dei ruoli semantici di una stanza.[br]
## - Permettere combinazioni multiple di ruoli tramite bitmask.[br]
## - Supportare regole di selezione e fallback nel PCG.[br]
##
## Nota di design:[br]
## - Ogni tag è rappresentato da un BIT (bitmask).[br]
## - Un template può avere PIÙ tag contemporaneamente.[br]
## - I tag descrivono cosa una stanza *può* essere, non cosa *è*.[br]
## - La decisione finale sull’uso del template è demandata a [RoomRules].[br]
# ============================================================================

class_name RoomTags


# ---------------------------------------------------------------------------
# Tag enumeration (bitmask)
# ---------------------------------------------------------------------------

enum Tag {
	## Punto di ingresso del livello.[br]
	## Tipicamente unico (one-shot).
	START		= 1 << 0,

	## Stanza centrale / nodo di smistamento.[br]
	## Spesso ad alta connettività.
	HUB			= 1 << 1,

	## Stanza di gameplay standard.[br]
	## Può contenere nemici, trappole, obiettivi.
	CHALLENGE	= 1 << 2,

	## Stanza che fornisce progressione.[br]
	## Tipicamente chiavi, abilità o upgrade.
	KEY_ROOM	= 1 << 3,

	## Stanza di salvataggio.[br]
	## Può contenere checkpoint o recovery.
	SAVE		= 1 << 4,

	## Stanza opzionale / laterale.[br]
	## Non necessaria per completare la run.
	SIDE		= 1 << 5,

	## Layout ampio.[br]
	## Ottimizzato per combattimenti e ondate.
	ARENA		= 1 << 6,

	## Stanza boss.[br]
	## Soggetta a regole speciali di generazione.
	BOSS		= 1 << 7,

	## Tag di fallback.[br]
	## Usato quando nessun template soddisfa pienamente le regole.
	FALLBACK	= 1 << 8
}
