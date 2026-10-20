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
		out   string
		ok    bool
	}{
		{name: "1:2:DP-1", group: 1, inner: 2, out: "DP-1", ok: true},
		{name: "10:10:HDMI-2", group: 10, inner: 10, out: "HDMI-2", ok: true},
		{name: "0:1:DP-1", ok: false},
		{name: "1:0:DP-1", ok: false},
		{name: "1:2:", ok: false},
		{name: "1:2", ok: false},
		{name: "foo:1:DP-1", ok: false},
		{name: "1", ok: false},
	}
	for _, test := range tests {
		group, inner, out, ok := ParseWorkspace(test.name)
		if group != test.group || inner != test.inner || out != test.out || ok != test.ok {
			t.Errorf("ParseWorkspace(%q) = (%d, %d, %q, %v), want (%d, %d, %q, %v)",
				test.name, group, inner, out, ok, test.group, test.inner, test.out, test.ok)
		}
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
