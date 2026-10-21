package i3workspacegroup

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"syscall"
)

type State struct {
	Last      map[string]map[string]int `json:"last"`
	Urgent    map[string]int64          `json:"urgent,omitempty"`
	UrgentSeq int64                     `json:"urgent_seq,omitempty"`
}

func newState() State {
	return State{
		Last:   make(map[string]map[string]int),
		Urgent: make(map[string]int64),
	}
}

func (state State) LastInner(group int, output string, fallback int) int {
	outputs, ok := state.Last[strconv.Itoa(group)]
	if !ok {
		return fallback
	}
	inner, ok := outputs[output]
	if !ok || inner < 1 || inner > MaxInner {
		return fallback
	}
	return inner
}

func statePath() string {
	directory := os.Getenv("XDG_RUNTIME_DIR")
	if directory == "" {
		directory = os.TempDir()
	}
	return filepath.Join(directory, fmt.Sprintf("i3-workspace-group-state-%d.json", os.Getuid()))
}

func readStateFile(path string) (State, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return newState(), nil
		}
		return newState(), fmt.Errorf("read state: %w", err)
	}

	var state State
	if err := json.Unmarshal(data, &state); err != nil {
		return newState(), fmt.Errorf("parse state: %w", err)
	}
	if state.Last == nil {
		state.Last = make(map[string]map[string]int)
	}
	if state.Urgent == nil {
		state.Urgent = make(map[string]int64)
	}
	return state, nil
}

func writeStateFile(path string, state State) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return fmt.Errorf("create state directory: %w", err)
	}

	data, err := json.Marshal(state)
	if err != nil {
		return fmt.Errorf("encode state: %w", err)
	}

	file, err := os.CreateTemp(filepath.Dir(path), ".i3-workspace-group-state-*")
	if err != nil {
		return fmt.Errorf("create state file: %w", err)
	}
	tempPath := file.Name()
	defer os.Remove(tempPath)

	if err := file.Chmod(0o600); err != nil {
		file.Close()
		return fmt.Errorf("chmod state file: %w", err)
	}
	if _, err := file.Write(data); err != nil {
		file.Close()
		return fmt.Errorf("write state file: %w", err)
	}
	if err := file.Close(); err != nil {
		return fmt.Errorf("close state file: %w", err)
	}
	if err := os.Rename(tempPath, path); err != nil {
		return fmt.Errorf("replace state file: %w", err)
	}
	return nil
}

func lockState(path string, exclusive bool) (*os.File, error) {
	lockPath := path + ".lock"
	file, err := os.OpenFile(lockPath, os.O_CREATE|os.O_RDWR, 0o600)
	if err != nil {
		return nil, fmt.Errorf("open state lock: %w", err)
	}
	operation := syscall.LOCK_SH
	if exclusive {
		operation = syscall.LOCK_EX
	}
	if err := syscall.Flock(int(file.Fd()), operation); err != nil {
		file.Close()
		return nil, fmt.Errorf("lock state: %w", err)
	}
	return file, nil
}

func unlockState(file *os.File) {
	_ = syscall.Flock(int(file.Fd()), syscall.LOCK_UN)
	_ = file.Close()
}

func loadState(path string) (State, error) {
	lock, err := lockState(path, false)
	if err != nil {
		return newState(), err
	}
	defer unlockState(lock)
	return readStateFile(path)
}

func updateState(path string, group int, output string, inner int) error {
	lock, err := lockState(path, true)
	if err != nil {
		return err
	}
	defer unlockState(lock)

	state, err := readStateFile(path)
	if err != nil {
		state = newState()
	}

	key := strconv.Itoa(group)
	if state.Last[key] == nil {
		state.Last[key] = make(map[string]int)
	}
	for outputName, currentInner := range state.Last[key] {
		if outputName != output && currentInner == inner {
			delete(state.Last[key], outputName)
		}
	}
	state.Last[key][output] = inner
	return writeStateFile(path, state)
}

func seedState(path string, values map[int]map[string]int) error {
	lock, err := lockState(path, true)
	if err != nil {
		return err
	}
	defer unlockState(lock)

	state, err := readStateFile(path)
	if err != nil {
		state = newState()
	}
	for group, outputs := range values {
		key := strconv.Itoa(group)
		if state.Last[key] == nil {
			state.Last[key] = make(map[string]int)
		}
		for output, inner := range outputs {
			state.Last[key][output] = inner
		}
	}
	return writeStateFile(path, state)
}

func bellKey(session string, tabID uint32) string {
	return "z\x1f" + session + "\x1f" + strconv.FormatUint(uint64(tabID), 10)
}

func parseBellKey(key string) (string, uint32, bool) {
	const prefix = "z\x1f"
	if !strings.HasPrefix(key, prefix) {
		return "", 0, false
	}
	index := strings.LastIndexByte(key, '\x1f')
	if index < len(prefix) {
		return "", 0, false
	}
	tabID, err := strconv.ParseUint(key[index+1:], 10, 32)
	if err != nil {
		return "", 0, false
	}
	return key[len(prefix):index], uint32(tabID), true
}

func updateUrgent(path string, current map[string]bool, preserveZellij bool) (State, error) {
	lock, err := lockState(path, true)
	if err != nil {
		return newState(), err
	}
	defer unlockState(lock)

	state, err := readStateFile(path)
	if err != nil {
		state = newState()
	}
	changed := false

	for key := range state.Urgent {
		if current[key] {
			continue
		}
		if preserveZellij && strings.HasPrefix(key, "z\x1f") {
			continue
		}
		delete(state.Urgent, key)
		changed = true
	}

	keys := make([]string, 0, len(current))
	for key := range current {
		if _, found := state.Urgent[key]; !found {
			keys = append(keys, key)
		}
	}
	sort.Strings(keys)
	for _, key := range keys {
		state.UrgentSeq++
		state.Urgent[key] = state.UrgentSeq
		changed = true
	}

	if !changed {
		return state, nil
	}
	if err := writeStateFile(path, state); err != nil {
		return state, err
	}
	return state, nil
}
