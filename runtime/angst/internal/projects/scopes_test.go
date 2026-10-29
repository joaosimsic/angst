package projects

import (
	"reflect"
	"testing"

	"angst/internal/scope"
)

func TestScopesOrDefault(t *testing.T) {
	if got := scopesFor("personal", true); !reflect.DeepEqual(got, []scope.Scope{scope.Personal}) {
		t.Fatalf("personal = %v", got)
	}
	if got := scopesFor("", false); !reflect.DeepEqual(got, []scope.Scope{scope.Personal, scope.Work}) {
		t.Fatalf("default = %v", got)
	}
}
