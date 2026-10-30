package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"os/signal"
	"syscall"
	"time"
)

var logger = log.New(os.Stderr, "angst-discord-voice: ", log.LstdFlags)

func logf(format string, args ...any) {
	logger.Printf(format, args...)
}

func main() {
	command := "daemon"
	if len(os.Args) > 1 {
		command = os.Args[1]
	}
	switch command {
	case "daemon":
		if err := runDaemonCommand(); err != nil {
			logf("%v", err)
			os.Exit(1)
		}
	case "status":
		if err := runStatus(); err != nil {
			logf("%v", err)
			os.Exit(1)
		}
	case "help", "-h", "--help":
		fmt.Fprintln(os.Stdout, "usage: angst-discord-voice [daemon|status]")
	default:
		fmt.Fprintf(os.Stderr, "unknown command %q\n", command)
		os.Exit(2)
	}
}

func runDaemonCommand() error {
	store, err := newStateStore()
	if err != nil {
		return fmt.Errorf("initialize state: %w", err)
	}
	defer store.close()

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	go func() {
		ticker := time.NewTicker(5 * time.Second)
		defer ticker.Stop()
		for {
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
				store.heartbeat()
			}
		}
	}()

	runDaemon(ctx, store)
	return nil
}
