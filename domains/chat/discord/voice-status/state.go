package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"syscall"
	"time"
	"unicode"
)

const (
	panelFreshness = 15 * time.Second
	channelLimit   = 24
)

type snapshot struct {
	PID         int    `json:"pid"`
	UpdatedAt   int64  `json:"updated_at"`
	Discord     bool   `json:"discord"`
	InChannel   bool   `json:"in_channel"`
	Connected   bool   `json:"connected"`
	Channel     string `json:"channel,omitempty"`
	Mute        bool   `json:"mute,omitempty"`
	Deaf        bool   `json:"deaf,omitempty"`
	AuthPending bool   `json:"auth_pending,omitempty"`
}

type panelState struct {
	Icon  string `json:"icon"`
	State string `json:"state"`
	Text  string `json:"text"`
}

var hiddenPanel = panelState{State: "Idle"}

type stateStore struct {
	mu   sync.Mutex
	path string
	snap snapshot
}

func runtimeBaseDir() string {
	if dir := os.Getenv("XDG_RUNTIME_DIR"); dir != "" {
		return dir
	}
	return os.TempDir()
}

func statePath() string {
	return filepath.Join(runtimeBaseDir(), "angst", "discord-voice", "state.json")
}

func stateHome() (string, error) {
	if dir := os.Getenv("XDG_STATE_HOME"); dir != "" {
		return dir, nil
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(home, ".local", "state"), nil
}

func tokenPath() (string, error) {
	base, err := stateHome()
	if err != nil {
		return "", err
	}
	return filepath.Join(base, "angst", "discord-voice", "token.json"), nil
}

type tokenCache struct {
	AccessToken string `json:"access_token"`
}

func loadToken() (string, error) {
	path, err := tokenPath()
	if err != nil {
		return "", err
	}
	data, err := os.ReadFile(path)
	if errors.Is(err, os.ErrNotExist) {
		return "", nil
	}
	if err != nil {
		return "", err
	}
	var cache tokenCache
	if err := json.Unmarshal(data, &cache); err != nil {
		return "", err
	}
	return cache.AccessToken, nil
}

func saveToken(token string) error {
	path, err := tokenPath()
	if err != nil {
		return err
	}
	data, err := json.Marshal(tokenCache{AccessToken: token})
	if err != nil {
		return err
	}
	data = append(data, '\n')
	return writeAtomic(path, data, 0o600)
}

func clearToken() error {
	path, err := tokenPath()
	if err != nil {
		return err
	}
	err = os.Remove(path)
	if errors.Is(err, os.ErrNotExist) {
		return nil
	}
	return err
}

func writeAtomic(path string, data []byte, mode os.FileMode) error {
	dir := filepath.Dir(path)
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return err
	}
	file, err := os.CreateTemp(dir, ".tmp-*")
	if err != nil {
		return err
	}
	name := file.Name()
	defer os.Remove(name)
	if err := file.Chmod(mode); err != nil {
		file.Close()
		return err
	}
	if _, err := file.Write(data); err != nil {
		file.Close()
		return err
	}
	if err := file.Close(); err != nil {
		return err
	}
	return os.Rename(name, path)
}

func newStateStore() (*stateStore, error) {
	store := &stateStore{
		path: statePath(),
		snap: snapshot{PID: os.Getpid()},
	}
	store.mu.Lock()
	defer store.mu.Unlock()
	store.snap.UpdatedAt = time.Now().UnixMilli()
	return store, store.writeLocked()
}

func (s *stateStore) update(fn func(*snapshot)) {
	s.mu.Lock()
	defer s.mu.Unlock()
	fn(&s.snap)
	s.snap.UpdatedAt = time.Now().UnixMilli()
	if err := s.writeLocked(); err != nil {
		logf("write state: %v", err)
	}
}

func (s *stateStore) heartbeat() {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.snap.UpdatedAt = time.Now().UnixMilli()
	if err := s.writeLocked(); err != nil {
		logf("write state: %v", err)
	}
}

func (s *stateStore) close() {
	_ = os.Remove(s.path)
}

func (s *stateStore) writeLocked() error {
	data, err := json.Marshal(s.snap)
	if err != nil {
		return err
	}
	data = append(data, '\n')
	return writeAtomic(s.path, data, 0o600)
}

func panelFromSnapshot(snap snapshot, now time.Time) panelState {
	if snap.PID <= 0 || now.Sub(time.UnixMilli(snap.UpdatedAt)) > panelFreshness {
		return hiddenPanel
	}
	if err := syscall.Kill(snap.PID, 0); err != nil {
		return hiddenPanel
	}
	if snap.AuthPending {
		return panelState{
			Icon:  "microphone_muted",
			State: "Warning",
			Text:  "discord auth",
		}
	}
	if !snap.Discord || !snap.InChannel || !snap.Connected {
		return hiddenPanel
	}
	name := sanitizeChannel(snap.Channel)
	if snap.Deaf {
		return panelState{
			Icon:  "volume_muted",
			State: "Critical",
			Text:  name + " deaf",
		}
	}
	if snap.Mute {
		return panelState{
			Icon:  "microphone_muted",
			State: "Warning",
			Text:  name,
		}
	}
	return panelState{
		Icon:  "microphone",
		State: "Good",
		Text:  name,
	}
}

func sanitizeChannel(name string) string {
	name = strings.TrimSpace(name)
	var builder strings.Builder
	count := 0
	for _, r := range name {
		if unicode.IsControl(r) {
			continue
		}
		if count >= channelLimit {
			builder.WriteString("...")
			break
		}
		builder.WriteRune(r)
		count++
	}
	result := strings.TrimSpace(builder.String())
	if result == "" {
		return "voice"
	}
	return result
}

func readSnapshot(path string) (snapshot, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return snapshot{}, err
	}
	var snap snapshot
	if err := json.Unmarshal(data, &snap); err != nil {
		return snapshot{}, err
	}
	return snap, nil
}

func runStatus() error {
	panel := hiddenPanel
	if snap, err := readSnapshot(statePath()); err == nil {
		panel = panelFromSnapshot(snap, time.Now())
	}
	encoder := json.NewEncoder(os.Stdout)
	if err := encoder.Encode(panel); err != nil {
		return fmt.Errorf("encode status: %w", err)
	}
	return nil
}
