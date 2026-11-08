extends RefCounted
class_name RageProgression

signal rage_changed(current: float, maximum: float, condemnation_threshold: float)
signal selection_pending(milestone: int)
signal selection_resolved(milestone: int, aura_id: String)
signal condemned(threshold: float, maximum: float)

# Provisional source-design tuning; values are configurable and not user-approved balance.
const MILESTONES: Array[int] = [10, 30, 50, 70, 90]
const AURA_POOL: Array[String] = ["light", "judgment", "fire", "shadow"]

var gain_per_effective_hit: float
var decay_per_second: float
var rage_cap: float
var rage := 0.0
var maximum_rage := 0.0
var condemnation_minimum := 3.0
var condemnation_fraction := 0.25
var current_soul_condemned := false
var pending_milestones: Array[int] = []
var claimed_milestones: Array[int] = []
var aura_choices: Dictionary = {}
var unlocked_spells: Array[String] = []

func _init(hit_gain: float = 3.0, passive_decay: float = 1.0, cap: float = 1000.0) -> void:
	gain_per_effective_hit = maxf(0.0, hit_gain)
	decay_per_second = maxf(0.0, passive_decay)
	rage_cap = maxf(90.0, cap)

func record_effective_hit(actual_damage: float) -> bool:
	if current_soul_condemned or not is_finite(actual_damage) or actual_damage <= 0.0:
		return false
	var old_rage := rage
	rage = minf(rage_cap, rage + gain_per_effective_hit)
	if rage <= old_rage:
		return false
	maximum_rage = maxf(maximum_rage, rage)
	for milestone: int in MILESTONES:
		if old_rage < float(milestone) and rage >= float(milestone) and not claimed_milestones.has(milestone) and not pending_milestones.has(milestone):
			pending_milestones.append(milestone)
			selection_pending.emit(milestone)
	_emit_state()
	return true

func advance(delta: float, gameplay_active: bool = true) -> void:
	if not gameplay_active or current_soul_condemned or not is_finite(delta) or delta <= 0.0:
		return
	var old_rage := rage
	rage = maxf(0.0, rage - decay_per_second * delta)
	if rage == old_rage:
		return
	_emit_state()
	var threshold := condemnation_threshold()
	if threshold > 0.0 and rage < threshold:
		current_soul_condemned = true
		condemned.emit(threshold, maximum_rage)

func resolve_selection(aura_id: String) -> bool:
	if pending_milestones.is_empty() or not AURA_POOL.has(aura_id):
		return false
	var milestone: int = pending_milestones.pop_front()
	claimed_milestones.append(milestone)
	aura_choices[milestone] = aura_id
	if not unlocked_spells.has(aura_id):
		unlocked_spells.append(aura_id)
	selection_resolved.emit(milestone, aura_id)
	return true

func condemnation_threshold() -> float:
	if maximum_rage < float(MILESTONES[0]):
		return 0.0
	return maxf(condemnation_minimum, condemnation_fraction * maximum_rage)

func pending_milestone() -> int:
	return pending_milestones[0] if not pending_milestones.is_empty() else -1

func aura_is_active(milestone: int) -> bool:
	return aura_choices.has(milestone) and rage >= float(milestone)

func _emit_state() -> void:
	rage_changed.emit(rage, maximum_rage, condemnation_threshold())

func reset_soul() -> void:
	rage = 0.0
	maximum_rage = 0.0
	current_soul_condemned = false
	pending_milestones.clear()
	claimed_milestones.clear()
	aura_choices.clear()
	unlocked_spells.clear()
	_emit_state()
