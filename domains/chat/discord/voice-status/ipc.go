package main

import (
	"encoding/binary"
	"errors"
	"fmt"
	"io"
	"net"
	"os"
	"path/filepath"
)

const maxFrameSize = 16 << 20

var errDiscordClosed = errors.New("discord closed the connection")

func writeFrame(w io.Writer, op uint32, payload []byte) error {
	if len(payload) > maxFrameSize {
		return fmt.Errorf("frame payload too large: %d", len(payload))
	}
	var header [8]byte
	binary.LittleEndian.PutUint32(header[0:4], op)
	binary.LittleEndian.PutUint32(header[4:8], uint32(len(payload)))
	if err := writeFull(w, header[:]); err != nil {
		return err
	}
	if len(payload) == 0 {
		return nil
	}
	return writeFull(w, payload)
}

func writeFull(w io.Writer, data []byte) error {
	for len(data) > 0 {
		n, err := w.Write(data)
		if err != nil {
			return err
		}
		if n == 0 {
			return io.ErrShortWrite
		}
		data = data[n:]
	}
	return nil
}

func readFrame(r io.Reader) (uint32, []byte, error) {
	var header [8]byte
	if _, err := io.ReadFull(r, header[:]); err != nil {
		return 0, nil, err
	}
	op := binary.LittleEndian.Uint32(header[0:4])
	length := binary.LittleEndian.Uint32(header[4:8])
	if length > maxFrameSize {
		return 0, nil, fmt.Errorf("frame payload too large: %d", length)
	}
	payload := make([]byte, length)
	if _, err := io.ReadFull(r, payload); err != nil {
		return 0, nil, err
	}
	return op, payload, nil
}

func discoverDiscordSocket() (string, error) {
	var bases []string
	seen := make(map[string]bool)
	add := func(path string) {
		if path == "" || seen[path] {
			return
		}
		seen[path] = true
		bases = append(bases, path)
	}
	runtimeDir := os.Getenv("XDG_RUNTIME_DIR")
	add(runtimeDir)
	add(os.Getenv("TMPDIR"))
	add(os.Getenv("TMP"))
	add(os.Getenv("TEMP"))
	add("/tmp")
	if runtimeDir != "" {
		add(filepath.Join(runtimeDir, "app", "com.discordapp.Discord"))
	}
	for _, base := range bases {
		for i := 0; i < 10; i++ {
			path := filepath.Join(base, fmt.Sprintf("discord-ipc-%d", i))
			info, err := os.Stat(path)
			if err == nil && info.Mode()&os.ModeSocket != 0 {
				return path, nil
			}
		}
	}
	return "", errors.New("discord ipc socket not found")
}

func dialDiscord() (net.Conn, error) {
	path, err := discoverDiscordSocket()
	if err != nil {
		return nil, err
	}
	conn, err := net.Dial("unix", path)
	if err != nil {
		return nil, fmt.Errorf("connect %s: %w", path, err)
	}
	return conn, nil
}
