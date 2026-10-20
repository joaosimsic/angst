package main

import (
	"fmt"
	"os"
	"os/signal"
	"syscall"

	"github.com/BurntSushi/xgb"
	"github.com/BurntSushi/xgb/xfixes"
	"github.com/BurntSushi/xgb/xproto"
)

func main() {
	conn, err := xgb.NewConn()
	if err != nil {
		fail("connect: %v", err)
	}

	if err := xfixes.Init(conn); err != nil {
		conn.Close()
		fail("xfixes: %v", err)
	}
	if _, err := xfixes.QueryVersion(conn, 5, 0).Reply(); err != nil {
		conn.Close()
		fail("xfixes version: %v", err)
	}

	setup := xproto.Setup(conn)
	roots := make([]xproto.Window, 0, len(setup.Roots))
	for _, screen := range setup.Roots {
		roots = append(roots, screen.Root)
	}

	for _, root := range roots {
		if err := xfixes.HideCursorChecked(conn, root).Check(); err != nil {
			conn.Close()
			fail("hide cursor: %v", err)
		}
	}
	conn.Sync()

	signals := make(chan os.Signal, 1)
	signal.Notify(signals, os.Interrupt, syscall.SIGTERM, syscall.SIGHUP, syscall.SIGQUIT)
	<-signals

	for _, root := range roots {
		if err := xfixes.ShowCursorChecked(conn, root).Check(); err != nil {
			fmt.Fprintf(os.Stderr, "i3-mouse-hold: show cursor: %v\n", err)
		}
	}
	conn.Sync()
	conn.Close()
}

func fail(format string, args ...any) {
	fmt.Fprintf(os.Stderr, "i3-mouse-hold: "+format+"\n", args...)
	os.Exit(1)
}
