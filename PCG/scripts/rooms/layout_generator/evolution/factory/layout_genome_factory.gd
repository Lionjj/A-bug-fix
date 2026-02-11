# ============================================================================
# LayoutGenomeFactory
# ============================================================================
## Crea genomi iniziali e li muta.
# ============================================================================

class_name LayoutGenomeFactory
extends GenomeFactory

var profile: RoomSizeProfile

func _init(_profile: RoomSizeProfile) -> void:
	profile = _profile


func random_genome( rng: RandomNumberGenerator) -> LayoutGenome:
	var g: LayoutGenome = LayoutGenome.new()

	#----------------------------------------------------------------------
	# Genoma operatore: Divider
	#----------------------------------------------------------------------
	g.genes.append(
		LayoutGene.new("divider", {
			"divider_count": rng.randi_range(
				profile.min_divider_count,
				profile.max_divider_count
			),
			
			"is_vertical": rng.randf_range(
				profile.min_divider_vertical,
				profile.max_divider_vertical
			) < profile.divider_threshold_vertical
		})
	)

	#----------------------------------------------------------------------
	# Genoma operatore: indent
	#----------------------------------------------------------------------
	
	var indent_count: int = rng.randi_range(profile.min_indent_count, profile.max_indent_count)
	for i in range(indent_count):
		g.genes.append(
			LayoutGene.new("indent", {
				"width": rng.randi_range(
					profile.min_width_indent, 
					profile.max_width_indent
				),
				
				"depth": rng.randi_range(
					profile.min_depth_indent, 
					profile.max_depth_indent
				),
				
				"side": Dir4.ORDER[rng.randi() % Dir4.ORDER.size()]
			})
		)
	
	
	#----------------------------------------------------------------------
	# Genoma operatore: Platform
	#----------------------------------------------------------------------
	
	if rng.randf() < 0.5:
		g.genes.append(
			LayoutGene.new("platform", {
				"platform_count": rng.randi_range(
					profile.min_platform_count, 
					profile.max_platform_count
				),
				
				"platform_width": rng.randi_range(
					profile.min_width_platform, 
					profile.max_width_platform
				),
				
				"platform_thickness": rng.randi_range(
					profile.min_thickness_platform, 
					profile.max_thickness_platform
				),
				
			})
		)

	#----------------------------------------------------------------------
	# Genoma operatore: Platform
	#----------------------------------------------------------------------
	
	if rng.randf() < 0.2:
		g.genes.append(
			LayoutGene.new("ring", {
				"ring_offset": rng.randi_range(
					profile.min_ring_offset,
					profile.max_ring_offset
				),
				
				"ring_thickness": rng.randi_range(
					profile.min_ring_thickness,
					profile.max_ring_thickness
				),
				
				"ring_gate_width": rng.randi_range(
					profile.min_ring_gate_width,
					profile.max_ring_gate_width
				),
				
				"ring_gate_count": rng.randi_range(
					profile.min_ring_gate_count,
					profile.max_ring_gate_count
				)
			})
		)
	
	#----------------------------------------------------------------------
	# Genoma operatore: SplitCorner
	#----------------------------------------------------------------------
	
	if rng.randf() < 0.4:
		g.genes.append(
			LayoutGene.new("split_corner", {
				"corner_width": rng.randi_range(
					profile.min_width_indent,
					profile.max_width_indent
				),
				
				"corner_depth": rng.randi_range(
					profile.min_depth_indent,
					profile.max_depth_indent
				),
				
				"corner_index": rng.randi_range(0, 3)
			})
		)
	
	
	#----------------------------------------------------------------------
	# Genoma operatore: Pillar
	#----------------------------------------------------------------------
	
	if rng.randf() < 0.4:
		g.genes.append(
			LayoutGene.new("pillar", {
				"pillar_count": rng.randi_range(
					profile.min_pillar_count,
					profile.max_pillar_count
				),
				"pillar_width": rng.randi_range(
					profile.min_pillar_width,
					profile.max_pillar_width
				),
				"pillar_height": rng.randi_range(
					profile.min_pillar_height,
					profile.max_pillar_height
				)
			})
		)


	return g
