class_name ConnectorProfile
extends Resource

# ----- parametri base (espandibili) -----
@export var min_width_tiles: int = 4

# cap assoluto (hard cap)
@export var max_width_abs: int = 12

# cap relativo allo spazio utile (0..1). Es: 0.30 = max 30% del lato utile
@export var max_width_ratio: float = 0.30

# margine extra dai corner (oltre wall_thickness). Ti evita aperture troppo vicino agli angoli.
@export var corner_margin_tiles: int = 1

# se vuoi: evita aperture troppo vicine tra loro (su lati opposti o stesso lato, ecc.)
@export var min_spacing_between_openings: int = 0
