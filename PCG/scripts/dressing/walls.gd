extends AutoMapLayer

extends AutoMapLayer

# --- METTI QUI LE COORDINATE DELL’ATLAS ---
const INSIDE     = Vector2i(0,0)

const TOP        = Vector2i(1,0)   # bordo superiore del muro (soffitto del blocco)
const BOTTOM     = Vector2i(2,0)   # bordo inferiore
const LEFT       = Vector2i(3,0)   # bordo sinistro
const RIGHT      = Vector2i(4,0)   # bordo destro

const OUT_NW     = Vector2i(0,1)   # angolo esterno alto-sx
const OUT_NE     = Vector2i(1,1)   # angolo esterno alto-dx
const OUT_SW     = Vector2i(2,1)   # angolo esterno basso-sx
const OUT_SE     = Vector2i(3,1)   # angolo esterno basso-dx
# ----------------------------------------

func get_tile(neighbors: Array[bool] = [false,false,false,false]) -> Array:
	# neighbors = [N,E,S,W] (solidi vicini nel Layout)

	var N = neighbors[0]
	var E = neighbors[1]
	var S = neighbors[2]
	var W = neighbors[3]

	# Se non c’è blocco qui (layout vuoto), non disegnare nulla.
	# (Questo funziona se AutoMapLayer chiama get_tile solo per celle piene del layout;
	# se invece te lo chiama ovunque, allora devi usare -1 quando la cella corrente non è piena:
	# ma nel 5tile normalmente la cella "corrente" è piena perché stai iterando sul layout pieno.)
	# In pratica: se stai usando il layout come “maschera”, questa riga spesso non serve.
	# La metto come fallback:
	if neighbors == [false,false,false,false]:
		# significa "isolato": se è un blocco singolo vuoi comunque un pezzo.
		# se vuoi che non compaia, metti [-1,-1,-1]. Se vuoi un blocchetto, usa INSIDE.
		return [INSIDE.x, INSIDE.y, 0]

	# interno pieno
	if N and E and S and W:
		return [INSIDE.x, INSIDE.y, 0]

	# bordi singoli
	if (not N) and E and S and W:
		return [TOP.x, TOP.y, 0]
	if N and E and (not S) and W:
		return [BOTTOM.x, BOTTOM.y, 0]
	if N and E and S and (not W):
		return [LEFT.x, LEFT.y, 0]
	if N and (not E) and S and W:
		return [RIGHT.x, RIGHT.y, 0]

	# angoli esterni (2 lati adiacenti esposti)
	if (not N) and E and S and (not W):
		return [OUT_NW.x, OUT_NW.y, 0]
	if (not N) and (not E) and S and W:
		return [OUT_NE.x, OUT_NE.y, 0]
	if N and E and (not S) and (not W):
		return [OUT_SW.x, OUT_SW.y, 0]
	if N and (not E) and (not S) and W:
		return [OUT_SE.x, OUT_SE.y, 0]

	# fallback: se manca qualche caso, riempi
	return [INSIDE.x, INSIDE.y, 0]
