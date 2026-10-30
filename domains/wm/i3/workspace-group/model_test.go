package i3workspacegroup

import (
	"reflect"
	"testing"
)

func TestGroups(t *testing.T) {
	want := []int{1, 2, 3, 4, 5, 6, 7, 8, 9, 10}
	if got := Groups(); !reflect.DeepEqual(got, want) {
		t.Fatalf("Groups() = %v, want %v", got, want)
	}
}

func TestParseWorkspace(t *testing.T) {
	tests := []struct {
		name  string
		group int
		inner int
		ok    bool
	}{
		{name: "1:2", group: 1, inner: 2, ok: true},
		{name: "10:10", group: 10, inner: 10, ok: true},
		{name: "0:1", ok: false},
		{name: "1:0", ok: false},
		{name: "1:2:DP-1", ok: false},
		{name: "foo:1", ok: false},
		{name: "1", ok: false},
	}
	for _, test := range tests {
		group, inner, ok := ParseWorkspace(test.name)
		if group != test.group || inner != test.inner || ok != test.ok {
			t.Errorf("ParseWorkspace(%q) = (%d, %d, %v), want (%d, %d, %v)",
				test.name, group, inner, ok, test.group, test.inner, test.ok)
		}
	}
}

func TestParseSuffixedWorkspace(t *testing.T) {
	group, inner, output, ok := ParseSuffixedWorkspace("1:2:DP-1")
	if !ok || group != 1 || inner != 2 || output != "DP-1" {
		t.Fatalf("ParseSuffixedWorkspace() = (%d, %d, %q, %v), want (1, 2, DP-1, true)", group, inner, output, ok)
	}
	if _, _, _, ok := ParseSuffixedWorkspace("1:2"); ok {
		t.Fatal("ParseSuffixedWorkspace accepted a global workspace")
	}
}

func TestParseLegacyWorkspace(t *testing.T) {
	group, output, ok := ParseLegacyWorkspace("4:HDMI-2")
	if !ok || group != 4 || output != "HDMI-2" {
		t.Fatalf("ParseLegacyWorkspace() = (%d, %q, %v), want (4, HDMI-2, true)", group, output, ok)
	}
	if _, _, ok := ParseLegacyWorkspace("1:2:DP-1"); ok {
		t.Fatal("ParseLegacyWorkspace accepted a nested workspace")
	}
}

func TestParsePlainWorkspace(t *testing.T) {
	if group, ok := ParsePlainWorkspace("4", 4); !ok || group != 4 {
		t.Fatalf("ParsePlainWorkspace() = (%d, %v), want (4, true)", group, ok)
	}
	if _, ok := ParsePlainWorkspace("4:HDMI-2", 4); ok {
		t.Fatal("ParsePlainWorkspace accepted a colon name")
	}
}

func TestQuoteI3(t *testing.T) {
	if got, want := QuoteI3(`a"b\c`), `"a\"b\\c"`; got != want {
		t.Fatalf("QuoteI3() = %q, want %q", got, want)
	}
}
