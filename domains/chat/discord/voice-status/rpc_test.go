package main

import (
	"encoding/json"
	"testing"
)

func TestResponseError(t *testing.T) {
	message := &rpcMessage{
		Evt:  "ERROR",
		Data: json.RawMessage(`{"code":4006,"message":"Not authenticated or invalid scope"}`),
	}
	err := responseError("GET_VOICE_SETTINGS", message)
	if err == nil {
		t.Fatal("expected error")
	}
	rpcErr, ok := err.(*rpcCommandError)
	if !ok {
		t.Fatalf("error type = %T", err)
	}
	if rpcErr.code != 4006 {
		t.Fatalf("code = %d", rpcErr.code)
	}
}

func TestResponseErrorSuccess(t *testing.T) {
	if err := responseError("GET_VOICE_SETTINGS", &rpcMessage{}); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
}

func TestVoiceChannelKey(t *testing.T) {
	id := "voice-id"
	if got := (voiceChannel{ID: "channel-id"}).key(); got != "channel-id" {
		t.Fatalf("id key = %q", got)
	}
	if got := (voiceChannel{ChannelID: &id}).key(); got != id {
		t.Fatalf("channel_id key = %q", got)
	}
	if got := (voiceChannel{ChannelID: nil}).key(); got != "" {
		t.Fatalf("empty key = %q", got)
	}
}
