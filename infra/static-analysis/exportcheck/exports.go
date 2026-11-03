package main

import "path"

func (analyzer analyzer) exportViolations() []violation {
	violations := make([]violation, 0, len(analyzer.paths))

	for _, file := range analyzer.paths {
		info := analyzer.infos[file]
		if !info.reportsExports() {
			continue
		}

		violations = append(violations, info.importIssueViolations()...)
		violations = append(violations, analyzer.exportFileViolations(file, info)...)
	}

	return violations
}

func (analyzer analyzer) exportFileViolations(file string, info *fileInfo) []violation {
	private := info.privateExport(file)
	scope := exportScope(private)
	violations := make([]violation, 0, len(info.Exports))

	for _, name := range info.Exports {
		if analyzer.exportUsed(file, info, private, name) {
			continue
		}

		violations = append(violations, exportViolation(file, name, scope, private))
	}

	return violations
}

func (analyzer analyzer) exportUsed(file string, info *fileInfo, private bool, name string) bool {
	for _, source := range analyzer.paths {
		user := analyzer.infos[source]
		if !user.references(source, file, name) {
			continue
		}

		if analyzer.countsAsUsage(source, info, private) {
			return true
		}
	}

	return false
}

func (analyzer analyzer) countsAsUsage(source string, info *fileInfo, private bool) bool {
	if info.ModuleRoot == "" {
		return true
	}

	return analyzer.worktree.Under(source, info.ModuleRoot) == private
}

func (info *fileInfo) reportsExports() bool {
	return !info.IsTest && info.Kind == "attrs" && info.Path != "flake.nix"
}

func (info *fileInfo) privateExport(file string) bool {
	return info.ModuleRoot != "" && file != path.Join(info.ModuleRoot, "default.nix")
}

func (info *fileInfo) references(source, target, name string) bool {
	if info.IsTest || source == target {
		return false
	}

	_, ok := info.Refs[target][name]

	return ok
}

func exportScope(private bool) string {
	if private {
		return "module"
	}

	return "global"
}

func exportViolation(file, name, scope string, private bool) violation {
	message := "not referenced by a non-test file outside the module"
	if private {
		message = "not referenced by a non-test file inside the module"
	}

	return violation{Path: file, Name: name, Scope: scope, Message: message}
}
