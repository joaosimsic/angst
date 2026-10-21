package main

import (
	"bytes"
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"strings"
	"time"
)

const (
	streamKitClientID  = "207646673902501888"
	streamKitTokenURL  = "https://streamkit.discord.com/overlay/token"
	handshakeTimeout   = 10 * time.Second
	commandTimeout     = 10 * time.Second
	authorizeTimeout   = 2 * time.Minute
	authorizationRetry = 5 * time.Minute
)

const (
	opHandshake uint32 = iota
	opFrame
	opClose
	opPing
	opPong
)

const (
	evtVoiceSettingsUpdate   = "VOICE_SETTINGS_UPDATE"
	evtVoiceChannelSelect    = "VOICE_CHANNEL_SELECT"
	evtVoiceConnectionStatus = "VOICE_CONNECTION_STATUS"
)

var errAuthorizationNeeded = errors.New("discord authorization required")

type rpcCommandError struct {
	command string
	code    int
	message string
}

func (e *rpcCommandError) Error() string {
	return fmt.Sprintf("%s failed: code %d: %s", e.command, e.code, e.message)
}

type outgoingMessage struct {
	Cmd   string `json:"cmd"`
	Nonce string `json:"nonce,omitempty"`
	Evt   string `json:"evt,omitempty"`
	Args  any    `json:"args,omitempty"`
}

type rpcMessage struct {
	Cmd   string          `json:"cmd,omitempty"`
	Evt   string          `json:"evt,omitempty"`
	Nonce string          `json:"nonce,omitempty"`
	Args  json.RawMessage `json:"args,omitempty"`
	Data  json.RawMessage `json:"data,omitempty"`
}

type voiceSettings struct {
	Mute *bool `json:"mute"`
	Deaf *bool `json:"deaf"`
}

type voiceChannel struct {
	ID        string  `json:"id"`
	ChannelID *string `json:"channel_id"`
	Name      string  `json:"name"`
}

func (c voiceChannel) key() string {
	if c.ChannelID != nil {
		return *c.ChannelID
	}
	return c.ID
}

type connectionStatus struct {
	State string `json:"state"`
}

type rpcClient struct {
	conn    net.Conn
	pending []*rpcMessage
}

func newNonce() (string, error) {
	var value [16]byte
	if _, err := rand.Read(value[:]); err != nil {
		return "", err
	}
	return hex.EncodeToString(value[:]), nil
}

func (c *rpcClient) readMessage(ctx context.Context) (*rpcMessage, error) {
	for {
		select {
		case <-ctx.Done():
			return nil, ctx.Err()
		default:
		}
		op, payload, err := readFrame(c.conn)
		if err != nil {
			return nil, err
		}
		switch op {
		case opPing:
			if err := writeFrame(c.conn, opPong, payload); err != nil {
				return nil, err
			}
		case opPong:
			continue
		case opClose:
			return nil, errDiscordClosed
		case opFrame:
			var message rpcMessage
			if err := json.Unmarshal(payload, &message); err != nil {
				return nil, fmt.Errorf("decode rpc frame: %w", err)
			}
			return &message, nil
		}
	}
}

func (c *rpcClient) handshake(ctx context.Context) error {
	payload, err := json.Marshal(map[string]any{
		"v":         1,
		"client_id": streamKitClientID,
	})
	if err != nil {
		return err
	}
	if err := c.conn.SetDeadline(time.Now().Add(handshakeTimeout)); err != nil {
		return err
	}
	defer c.conn.SetDeadline(time.Time{})
	if err := writeFrame(c.conn, opHandshake, payload); err != nil {
		return err
	}
	for {
		message, err := c.readMessage(ctx)
		if err != nil {
			return err
		}
		if message.Evt == "READY" {
			return nil
		}
		if message.Evt == "ERROR" {
			return responseError("READY", message)
		}
	}
}

func (c *rpcClient) command(ctx context.Context, command string, args any, evt string, timeout time.Duration) (*rpcMessage, error) {
	nonce, err := newNonce()
	if err != nil {
		return nil, err
	}
	payload, err := json.Marshal(outgoingMessage{
		Cmd:   command,
		Nonce: nonce,
		Evt:   evt,
		Args:  args,
	})
	if err != nil {
		return nil, err
	}
	if err := c.conn.SetDeadline(time.Now().Add(timeout)); err != nil {
		return nil, err
	}
	defer c.conn.SetDeadline(time.Time{})
	if err := writeFrame(c.conn, opFrame, payload); err != nil {
		return nil, err
	}
	for {
		message, err := c.readMessage(ctx)
		if err != nil {
			return nil, err
		}
		if message.Nonce == nonce {
			return message, nil
		}
		if message.Evt != "" {
			c.pending = append(c.pending, message)
		}
	}
}

func responseError(command string, message *rpcMessage) error {
	if message.Evt != "ERROR" {
		return nil
	}
	var payload struct {
		Code    int    `json:"code"`
		Message string `json:"message"`
	}
	_ = json.Unmarshal(message.Data, &payload)
	return &rpcCommandError{
		command: command,
		code:    payload.Code,
		message: payload.Message,
	}
}

func (c *rpcClient) authenticate(ctx context.Context, store *stateStore) error {
	token, err := loadToken()
	if err != nil {
		logf("read token cache: %v", err)
	}
	if token != "" {
		ok, err := c.tryAuthenticate(ctx, token)
		if err != nil {
			return err
		}
		if ok {
			return nil
		}
		logf("cached discord token rejected; reauthorizing")
		if err := clearToken(); err != nil {
			logf("clear token cache: %v", err)
		}
	}

	store.update(func(snap *snapshot) { snap.AuthPending = true })
	code, err := c.authorize(ctx)
	if err != nil {
		store.update(func(snap *snapshot) { snap.AuthPending = false })
		return fmt.Errorf("%w: %v", errAuthorizationNeeded, err)
	}
	token, err = exchangeAuthorizationCode(ctx, code)
	if err != nil {
		store.update(func(snap *snapshot) { snap.AuthPending = false })
		return fmt.Errorf("%w: %v", errAuthorizationNeeded, err)
	}
	ok, err := c.tryAuthenticate(ctx, token)
	if err != nil {
		store.update(func(snap *snapshot) { snap.AuthPending = false })
		return err
	}
	if !ok {
		store.update(func(snap *snapshot) { snap.AuthPending = false })
		return fmt.Errorf("%w: AUTHENTICATE rejected", errAuthorizationNeeded)
	}
	if err := saveToken(token); err != nil {
		logf("save token cache: %v", err)
	}
	store.update(func(snap *snapshot) { snap.AuthPending = false })
	return nil
}

func (c *rpcClient) authorize(ctx context.Context) (string, error) {
	message, err := c.command(ctx, "AUTHORIZE", map[string]any{
		"client_id": streamKitClientID,
		"scopes":    []string{"rpc"},
	}, "", authorizeTimeout)
	if err != nil {
		return "", err
	}
	if err := responseError("AUTHORIZE", message); err != nil {
		return "", err
	}
	var payload struct {
		Code string `json:"code"`
	}
	if err := json.Unmarshal(message.Data, &payload); err != nil {
		return "", fmt.Errorf("decode AUTHORIZE response: %w", err)
	}
	if payload.Code == "" {
		return "", errors.New("AUTHORIZE response missing code")
	}
	return payload.Code, nil
}

func (c *rpcClient) tryAuthenticate(ctx context.Context, token string) (bool, error) {
	message, err := c.command(ctx, "AUTHENTICATE", map[string]string{
		"access_token": token,
	}, "", commandTimeout)
	if err != nil {
		return false, err
	}
	if message.Evt == "ERROR" {
		logf("AUTHENTICATE rejected: %v", responseError("AUTHENTICATE", message))
		return false, nil
	}
	return true, nil
}

func exchangeAuthorizationCode(ctx context.Context, code string) (string, error) {
	payload, err := json.Marshal(map[string]string{"code": code})
	if err != nil {
		return "", err
	}
	request, err := http.NewRequestWithContext(ctx, http.MethodPost, streamKitTokenURL, bytes.NewReader(payload))
	if err != nil {
		return "", err
	}
	request.Header.Set("Content-Type", "application/json")
	request.Header.Set("Accept", "application/json")
	client := &http.Client{Timeout: 20 * time.Second}
	response, err := client.Do(request)
	if err != nil {
		return "", err
	}
	defer response.Body.Close()
	body, err := io.ReadAll(io.LimitReader(response.Body, 1<<20))
	if err != nil {
		return "", err
	}
	if response.StatusCode < 200 || response.StatusCode >= 300 {
		return "", fmt.Errorf("streamkit token exchange: %s: %s", response.Status, strings.TrimSpace(string(body)))
	}
	var result struct {
		AccessToken string `json:"access_token"`
	}
	if err := json.Unmarshal(body, &result); err != nil {
		return "", fmt.Errorf("decode streamkit token response: %w", err)
	}
	if result.AccessToken == "" {
		return "", errors.New("streamkit token response missing access_token")
	}
	return result.AccessToken, nil
}

func (c *rpcClient) subscribe(ctx context.Context, evt string) error {
	message, err := c.command(ctx, "SUBSCRIBE", nil, evt, commandTimeout)
	if err != nil {
		return err
	}
	return responseError("SUBSCRIBE "+evt, message)
}

func (c *rpcClient) refreshSettings(ctx context.Context, store *stateStore) error {
	message, err := c.command(ctx, "GET_VOICE_SETTINGS", nil, "", commandTimeout)
	if err != nil {
		return err
	}
	if err := responseError("GET_VOICE_SETTINGS", message); err != nil {
		return err
	}
	if len(message.Data) == 0 || string(message.Data) == "null" {
		return nil
	}
	var settings voiceSettings
	if err := json.Unmarshal(message.Data, &settings); err != nil {
		return fmt.Errorf("decode voice settings: %w", err)
	}
	store.update(func(snap *snapshot) {
		snap.Discord = true
		if settings.Mute != nil {
			snap.Mute = *settings.Mute
		}
		if settings.Deaf != nil {
			snap.Deaf = *settings.Deaf
		}
	})
	return nil
}

func (c *rpcClient) refreshSelectedChannel(ctx context.Context, store *stateStore) error {
	message, err := c.command(ctx, "GET_SELECTED_VOICE_CHANNEL", nil, "", commandTimeout)
	if err != nil {
		return err
	}
	if err := responseError("GET_SELECTED_VOICE_CHANNEL", message); err != nil {
		return err
	}
	var channel voiceChannel
	if len(message.Data) == 0 || string(message.Data) == "null" {
		store.update(func(snap *snapshot) {
			snap.Discord = true
			snap.InChannel = false
			snap.Connected = false
			snap.Channel = ""
		})
		return nil
	}
	if err := json.Unmarshal(message.Data, &channel); err != nil {
		return fmt.Errorf("decode selected voice channel: %w", err)
	}
	key := channel.key()
	if key == "" {
		store.update(func(snap *snapshot) {
			snap.Discord = true
			snap.InChannel = false
			snap.Connected = false
			snap.Channel = ""
		})
		return nil
	}
	store.update(func(snap *snapshot) {
		snap.Discord = true
		snap.InChannel = true
		snap.Connected = true
		snap.Channel = channel.Name
	})
	if channel.Name == "" {
		return c.refreshChannel(ctx, store, key)
	}
	return nil
}

func (c *rpcClient) refreshChannel(ctx context.Context, store *stateStore, id string) error {
	message, err := c.command(ctx, "GET_CHANNEL", map[string]string{"channel_id": id}, "", commandTimeout)
	if err != nil {
		return err
	}
	if err := responseError("GET_CHANNEL", message); err != nil {
		return err
	}
	var channel voiceChannel
	if len(message.Data) == 0 || string(message.Data) == "null" {
		return nil
	}
	if err := json.Unmarshal(message.Data, &channel); err != nil {
		return fmt.Errorf("decode channel: %w", err)
	}
	if channel.Name == "" {
		return nil
	}
	store.update(func(snap *snapshot) { snap.Channel = channel.Name })
	return nil
}

func (c *rpcClient) handleEvent(ctx context.Context, store *stateStore, message *rpcMessage) error {
	switch message.Evt {
	case evtVoiceSettingsUpdate:
		return c.refreshSettings(ctx, store)
	case evtVoiceChannelSelect:
		var channel voiceChannel
		if err := json.Unmarshal(message.Data, &channel); err != nil {
			return c.refreshSelectedChannel(ctx, store)
		}
		key := channel.key()
		if key == "" {
			store.update(func(snap *snapshot) {
				snap.Discord = true
				snap.InChannel = false
				snap.Connected = false
				snap.Channel = ""
			})
		} else {
			store.update(func(snap *snapshot) {
				snap.Discord = true
				snap.InChannel = true
				snap.Connected = true
				snap.Channel = ""
			})
			if err := c.refreshChannel(ctx, store, key); err != nil {
				return err
			}
		}
		return c.refreshSettings(ctx, store)
	case evtVoiceConnectionStatus:
		var status connectionStatus
		if err := json.Unmarshal(message.Data, &status); err != nil {
			return nil
		}
		store.update(func(snap *snapshot) {
			snap.Discord = true
			snap.Connected = status.State != "DISCONNECTED"
		})
	}
	return nil
}

func (c *rpcClient) drainPending(ctx context.Context, store *stateStore) error {
	for len(c.pending) > 0 {
		message := c.pending[0]
		c.pending = c.pending[1:]
		if message.Evt == "" {
			continue
		}
		if err := c.handleEvent(ctx, store, message); err != nil {
			return err
		}
	}
	return nil
}

func (c *rpcClient) eventLoop(ctx context.Context, store *stateStore) error {
	for {
		message, err := c.readMessage(ctx)
		if err != nil {
			return err
		}
		if message.Evt == "" {
			continue
		}
		if err := c.handleEvent(ctx, store, message); err != nil {
			return err
		}
		if err := c.drainPending(ctx, store); err != nil {
			return err
		}
	}
}

func runSession(ctx context.Context, store *stateStore) (bool, error) {
	conn, err := dialDiscord()
	if err != nil {
		return false, err
	}
	defer conn.Close()

	done := make(chan struct{})
	defer close(done)
	go func() {
		select {
		case <-ctx.Done():
			conn.Close()
		case <-done:
		}
	}()

	client := &rpcClient{conn: conn}
	if err := client.handshake(ctx); err != nil {
		return false, err
	}
	store.update(func(snap *snapshot) { snap.Discord = true })

	if err := client.authenticate(ctx, store); err != nil {
		return true, err
	}
	for _, evt := range []string{
		evtVoiceSettingsUpdate,
		evtVoiceChannelSelect,
		evtVoiceConnectionStatus,
	} {
		if err := client.subscribe(ctx, evt); err != nil {
			return true, err
		}
	}

	if err := client.refreshSettings(ctx, store); err != nil {
		return true, err
	}
	if err := client.refreshSelectedChannel(ctx, store); err != nil {
		return true, err
	}
	if err := client.drainPending(ctx, store); err != nil {
		return true, err
	}

	return true, client.eventLoop(ctx, store)
}

func runDaemon(ctx context.Context, store *stateStore) {
	backoff := time.Second
	for {
		established, err := runSession(ctx, store)
		if ctx.Err() != nil {
			return
		}
		store.update(func(snap *snapshot) {
			snap.Discord = false
			snap.InChannel = false
			snap.Connected = false
			snap.Channel = ""
			snap.Mute = false
			snap.Deaf = false
			snap.AuthPending = false
		})
		if err != nil {
			logf("session ended: %v", err)
		}
		wait := backoff
		if errors.Is(err, errAuthorizationNeeded) {
			wait = authorizationRetry
		}
		select {
		case <-ctx.Done():
			return
		case <-time.After(wait):
		}
		if established {
			backoff = time.Second
		} else if backoff < 30*time.Second {
			backoff *= 2
			if backoff > 30*time.Second {
				backoff = 30 * time.Second
			}
		}
	}
}
