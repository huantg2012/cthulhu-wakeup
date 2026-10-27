extends "res://tools/balance/policy.gd"
## Iteration 2 changes one public event preference, never world state or CSV.
func event_candidates(view: Dictionary, choices: Array) -> Array:
	var result: Array = super.event_candidates(view, choices)
	var ritual_events: Array = []
	for event: Dictionary in view.events:
		if event.descriptor.get("content_id") == "EVENT_04": ritual_events.append(event.id)
	for candidate: Dictionary in result:
		if candidate.key.get_slice("/", 1) in ritual_events:
			candidate.rank = 100 if candidate.key.ends_with("/B") else 10
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.rank > b.rank if a.rank != b.rank else a.key < b.key)
	return result
