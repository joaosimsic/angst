package main

import (
	"bytes"
	"encoding/binary"
	"testing"
)

func TestFrameRoundTrip(t *testing.T) {
	var buffer bytes.Buffer
	if err := writeFrame(&buffer, opFrame, []byte(`{"cmd":"PING"}`)); err != nil {
		t.Fatalf("writeFrame: %v", err)
	}
	op, payload, err := readFrame(&buffer)
	if err != nil {
		t.Fatalf("readFrame: %v", err)
	}
	if op != opFrame {
		t.Fatalf("op = %d, want %d", op, opFrame)
	}
	if string(payload) != `{"cmd":"PING"}` {
		t.Fatalf("payload = %q", payload)
	}
}

func TestFrameRejectsOversizePayload(t *testing.T) {
	var buffer bytes.Buffer
	var header [8]byte
	binary.LittleEndian.PutUint32(header[0:4], opFrame)
	binary.LittleEndian.PutUint32(header[4:8], maxFrameSize+1)
	buffer.Write(header[:])
	_, _, err := readFrame(&buffer)
	if err == nil {
		t.Fatal("expected oversize frame error")
	}
}

func TestFrameEmptyPayload(t *testing.T) {
	var buffer bytes.Buffer
	if err := writeFrame(&buffer, opPing, nil); err != nil {
		t.Fatalf("writeFrame: %v", err)
	}
	op, payload, err := readFrame(&buffer)
	if err != nil {
		t.Fatalf("readFrame: %v", err)
	}
	if op != opPing {
		t.Fatalf("op = %d, want %d", op, opPing)
	}
	if len(payload) != 0 {
		t.Fatalf("payload length = %d, want 0", len(payload))
	}
}
