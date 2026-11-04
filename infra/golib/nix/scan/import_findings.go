package scan

type importFindings struct {
	imports map[string]struct{}
	aliases map[string]string
	issues  []string
}

func newImportFindings() importFindings {
	return importFindings{
		imports: map[string]struct{}{},
		aliases: map[string]string{},
	}
}

func (findings *importFindings) addImport(target string) {
	if target == "" {
		return
	}

	findings.imports[target] = struct{}{}
}

func (findings *importFindings) addAlias(name, target string) {
	if name == "" || target == "" {
		return
	}

	findings.aliases[name] = target
}

func (findings *importFindings) addIssue(issue string) {
	findings.issues = append(findings.issues, issue)
}

func (findings importFindings) importSet() map[string]struct{} {
	return findings.imports
}

func (findings importFindings) aliasTargets() map[string]string {
	return findings.aliases
}

func (findings importFindings) foundIssues() []string {
	return findings.issues
}
