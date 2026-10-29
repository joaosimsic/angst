package db

import (
	"reflect"
	"testing"

	"angst/internal/scope"
)

func TestScopesOrDefault(t *testing.T) {
	if got := scopesFor("work", true); !reflect.DeepEqual(got, []scope.Scope{scope.Work}) {
		t.Fatalf("work = %v", got)
	}
	if got := scopesFor("bogus", true); len(got) != 0 {
		t.Fatalf("explicit invalid = %v", got)
	}
	if got := scopesFor("", false); !reflect.DeepEqual(got, []scope.Scope{scope.Personal, scope.Work}) {
		t.Fatalf("default = %v", got)
	}
}

func TestScopeAllowed(t *testing.T) {
	allowed := []scope.Scope{scope.Personal}
	if !scopeAllowed(allowed, "personal") {
		t.Fatal("personal should be allowed")
	}
	if scopeAllowed(allowed, "work") {
		t.Fatal("work should not be allowed")
	}
}
