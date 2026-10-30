package vm

import (
	"os"
	"testing"
)

func TestRestartRequestRoundTrip(t *testing.T) {
	restore := withStateDir(t)
	defer restore()

	if err := writeRestartRequest(restartRequest{Headless: true, FullHD: true}); err != nil {
		t.Fatal(err)
	}
	req, ok := readRestartRequest()
	if !ok {
		t.Fatal("expected restart request")
	}
	if !req.Headless || !req.FullHD {
		t.Fatalf("unexpected request: %+v", req)
	}
	if _, err := os.Stat(restartRequestPath()); !os.IsNotExist(err) {
		t.Fatalf("expected request file to be consumed, err=%v", err)
	}
}
