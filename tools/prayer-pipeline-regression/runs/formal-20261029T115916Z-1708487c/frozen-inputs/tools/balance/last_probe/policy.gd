extends "res://tools/balance/followup/policy.gd"
## Final iteration: all pre-cult faith is reserved for actual PR05 responses.
func power_candidates(view: Dictionary, facts: Array) -> Array:
	return [] if view.cults.is_empty() else super.power_candidates(view, facts)

func preparation_candidate(view: Dictionary, facts: Array, prayer: Dictionary) -> Dictionary:
	return {} if view.cults.is_empty() else super.preparation_candidate(view, facts, prayer)
