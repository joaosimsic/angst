package main

import (
	"testing"

	"github.com/joaosimsic/angst/infra/golib/repo"
)

func runAnalysis(infos map[string]*fileInfo) []violation {
	return analyze(repo.Worktree{}, infos)
}

func newFileInfo(file string, isTest bool, kind string, moduleRoot string, exports []string) *fileInfo {
	return &fileInfo{
		Path:        file,
		IsTest:      isTest,
		Kind:        kind,
		ModuleRoot:  moduleRoot,
		Exports:     exports,
		Imports:     map[string]struct{}{},
		AliasTarget: map[string]string{},
		Refs:        map[string]map[string]struct{}{},
	}
}

func addReferences(info *fileInfo, target string, names ...string) {
	if info.Refs[target] == nil {
		info.Refs[target] = map[string]struct{}{}
	}

	for _, name := range names {
		info.Refs[target][name] = struct{}{}
	}
}

func TestAnalyzeGlobalUsedOutside(t *testing.T) {
	facade := newFileInfo("mod/default.nix", false, "attrs", "mod", []string{"api"})
	consumer := newFileInfo("consumer.nix", false, "attrs", "", nil)

	addReferences(consumer, "mod/default.nix", "api")

	if got := runAnalysis(map[string]*fileInfo{facade.Path: facade, consumer.Path: consumer}); len(got) != 0 {
		t.Fatalf("unexpected violations: %#v", got)
	}
}

func TestAnalyzeGlobalTestOnly(t *testing.T) {
	facade := newFileInfo("mod/default.nix", false, "attrs", "mod", []string{"api"})
	testFile := newFileInfo("mod/test.nix", true, "bool", "mod", nil)

	addReferences(testFile, "mod/default.nix", "api")

	got := runAnalysis(map[string]*fileInfo{facade.Path: facade, testFile.Path: testFile})
	if len(got) != 1 || got[0].Name != "api" || got[0].Scope != "global" {
		t.Fatalf("expected one global violation, got %#v", got)
	}
}

func TestAnalyzePrivateUsedInside(t *testing.T) {
	facade := newFileInfo("mod/default.nix", false, "attrs", "mod", []string{"api"})
	privateFile := newFileInfo("mod/private.nix", false, "attrs", "mod", []string{"helper"})

	addReferences(facade, "mod/private.nix", "helper")

	consumer := newFileInfo("consumer.nix", false, "attrs", "", nil)

	addReferences(consumer, "mod/default.nix", "api")

	if got := runAnalysis(map[string]*fileInfo{facade.Path: facade, privateFile.Path: privateFile, consumer.Path: consumer}); len(got) != 0 {
		t.Fatalf("unexpected violations: %#v", got)
	}
}

func TestAnalyzePrivateTestOnly(t *testing.T) {
	privateFile := newFileInfo("mod/private.nix", false, "attrs", "mod", []string{"helper"})
	testFile := newFileInfo("mod/test.nix", true, "bool", "mod", nil)

	addReferences(testFile, "mod/private.nix", "helper")

	got := runAnalysis(map[string]*fileInfo{privateFile.Path: privateFile, testFile.Path: testFile})
	if len(got) != 1 || got[0].Name != "helper" || got[0].Scope != "module" {
		t.Fatalf("expected one module violation, got %#v", got)
	}
}

func TestAnalyzePrivateImportedOutside(t *testing.T) {
	privateFile := newFileInfo("mod/private.nix", false, "attrs", "mod", []string{"helper"})
	facade := newFileInfo("mod/default.nix", false, "attrs", "mod", nil)

	addReferences(facade, "mod/private.nix", "helper")

	consumer := newFileInfo("consumer.nix", false, "attrs", "", nil)
	consumer.Imports["mod/private.nix"] = struct{}{}

	got := runAnalysis(map[string]*fileInfo{privateFile.Path: privateFile, facade.Path: facade, consumer.Path: consumer})
	if len(got) != 1 || got[0].Path != "consumer.nix" || got[0].Name != "mod/private.nix" {
		t.Fatalf("expected private import violation, got %#v", got)
	}
}

func TestAnalyzeLeafUsedOutside(t *testing.T) {
	leaf := newFileInfo("infra/lib/leaf.nix", false, "attrs", "", []string{"api"})
	consumer := newFileInfo("consumer.nix", false, "attrs", "", nil)

	addReferences(consumer, "infra/lib/leaf.nix", "api")

	if got := runAnalysis(map[string]*fileInfo{leaf.Path: leaf, consumer.Path: consumer}); len(got) != 0 {
		t.Fatalf("unexpected violations: %#v", got)
	}
}

func TestAnalyzeLeafSelfOnly(t *testing.T) {
	leaf := newFileInfo("infra/lib/leaf.nix", false, "attrs", "", []string{"api"})

	addReferences(leaf, "infra/lib/leaf.nix", "api")

	got := runAnalysis(map[string]*fileInfo{leaf.Path: leaf})
	if len(got) != 1 || got[0].Name != "api" || got[0].Scope != "global" {
		t.Fatalf("expected one global violation, got %#v", got)
	}
}

func TestAnalyzeSkipsFlakeEntrypoint(t *testing.T) {
	flake := newFileInfo("flake.nix", false, "attrs", "", []string{"inputs", "outputs"})

	if got := runAnalysis(map[string]*fileInfo{flake.Path: flake}); len(got) != 0 {
		t.Fatalf("unexpected violations: %#v", got)
	}
}

func TestAnalyzeSkipsNonAttrs(t *testing.T) {
	lambda := newFileInfo("pkg/package.nix", false, "lambda", "pkg", nil)
	derivation := newFileInfo("shell.nix", false, "derivation", "", nil)

	if got := runAnalysis(map[string]*fileInfo{lambda.Path: lambda, derivation.Path: derivation}); len(got) != 0 {
		t.Fatalf("unexpected violations: %#v", got)
	}
}
