package main

import "path"

func (analyzer analyzer) privateImportViolations() []violation {
	violations := make([]violation, 0, len(analyzer.paths))

	for _, source := range analyzer.paths {
		sourceInfo := analyzer.infos[source]
		if sourceInfo.IsTest {
			continue
		}

		violations = append(violations, analyzer.privateImportViolationsFor(source, sourceInfo)...)
	}

	return violations
}

func (analyzer analyzer) privateImportViolationsFor(source string, sourceInfo *fileInfo) []violation {
	violations := make([]violation, 0, len(sourceInfo.Imports))

	for target := range sourceInfo.Imports {
		targetInfo, ok := analyzer.infos[target]
		if !ok || !analyzer.privateImport(source, target, targetInfo) {
			continue
		}
		violations = append(violations, privateImportViolation(source, target))
	}

	return violations
}

func (analyzer analyzer) privateImport(source, target string, info *fileInfo) bool {
	if info.IsTest || info.Kind != "attrs" || info.ModuleRoot == "" {
		return false
	}

	if target == path.Join(info.ModuleRoot, "default.nix") {
		return false
	}

	return !analyzer.worktree.Under(source, info.ModuleRoot)
}

func (info *fileInfo) importIssueViolations() []violation {
	violations := make([]violation, 0, len(info.Issues))

	for _, issue := range info.Issues {
		violations = append(violations, violation{
			Path:    info.Path,
			Name:    "<import>",
			Scope:   "global",
			Message: issue,
		})
	}

	return violations
}

func privateImportViolation(source, target string) violation {
	return violation{
		Path:    source,
		Name:    target,
		Scope:   "module",
		Message: "private module imported from outside its module directory",
	}
}
