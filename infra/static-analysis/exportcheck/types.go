package main

type fileInfo struct {
	Path        string
	ModuleRoot  string
	IsTest      bool
	Kind        string
	Exports     []string
	Imports     map[string]struct{}
	AliasTarget map[string]string
	Refs        map[string]map[string]struct{}
	Issues      []string
}

type violation struct {
	Path    string
	Name    string
	Scope   string
	Message string
}
