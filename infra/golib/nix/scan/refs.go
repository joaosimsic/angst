package scan

type referenceSet map[string]map[string]struct{}

func newReferenceSet() referenceSet {
	return referenceSet{}
}

func (set referenceSet) add(files map[string]struct{}, target, name string) {
	if _, ok := files[target]; !ok || name == "" {
		return
	}

	set.ensureTarget(target)

	set[target][name] = struct{}{}
}

func (set referenceSet) merge(other referenceSet) {
	for target, names := range other {
		set.ensureTarget(target)

		for name := range names {
			set[target][name] = struct{}{}
		}
	}
}

func (set referenceSet) ensureTarget(target string) {
	if set[target] == nil {
		set[target] = map[string]struct{}{}
	}
}
