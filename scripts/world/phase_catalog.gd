extends RefCounted
class_name PhaseCatalog
## Campanha completa, em ordem. Mesmo padrão de MapCatalog e ShopCatalog.

const FIRST_PHASE_ID := &"phase_1"

const PHASE_PATHS := [
	"res://resources/phases/phase_1.tres",
	"res://resources/phases/phase_2.tres",
	"res://resources/phases/phase_3.tres",
]

static var PHASES: Array[PhaseData] = _build_phases()


static func get_phases() -> Array[PhaseData]:
	return PHASES


static func get_phase(phase_id: StringName) -> PhaseData:
	for phase in PHASES:
		if phase != null and phase.phase_id == phase_id:
			return phase
	return get_first_phase()


static func get_first_phase() -> PhaseData:
	return PHASES[0] if not PHASES.is_empty() else null


static func has_phase(phase_id: StringName) -> bool:
	for phase in PHASES:
		if phase != null and phase.phase_id == phase_id:
			return true
	return false


## A fase imediatamente seguinte na campanha, ou null se esta for a última.
static func get_next_phase(phase_id: StringName) -> PhaseData:
	for index in range(PHASES.size()):
		if PHASES[index].phase_id == phase_id:
			return PHASES[index + 1] if index + 1 < PHASES.size() else null
	return null


static func get_phase_index(phase_id: StringName) -> int:
	for index in range(PHASES.size()):
		if PHASES[index].phase_id == phase_id:
			return index
	return -1


static func _build_phases() -> Array[PhaseData]:
	var result: Array[PhaseData] = []
	for path in PHASE_PATHS:
		if not ResourceLoader.exists(path):
			push_warning("PhaseCatalog: fase ausente em \"%s\"." % path)
			continue
		var phase := load(path) as PhaseData
		if phase != null and phase.is_valid():
			result.append(phase)
		else:
			push_warning("PhaseCatalog: \"%s\" não é uma PhaseData válida." % path)
	result.sort_custom(func(a: PhaseData, b: PhaseData) -> bool: return a.order < b.order)
	return result
