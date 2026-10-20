package i3workspacegroup

import (
	"encoding/json"
	"fmt"
	"log"
	"os"
	"time"

	"go.i3wm.org/i3/v4"
)

const barBlinkInterval = 600 * time.Millisecond

func Bar() error {
	for {
		receiver := i3.Subscribe(i3.WorkspaceEventType, i3.OutputEventType, i3.WindowEventType)
		events := make(chan struct{}, 1)
		done := make(chan struct{})
		go func() {
			defer close(done)
			collectBarEvents(receiver, events)
		}()

		ticker := time.NewTicker(barBlinkInterval)
		blink := false
		hasUrgent, err := emitBar(blink)
		if err != nil {
			log.Printf("i3-workspace-group bar: %v", err)
		}

	loop:
		for {
			select {
			case <-events:
				hasUrgent, err = emitBar(blink)
				if err != nil {
					log.Printf("i3-workspace-group bar: %v", err)
				}
			case <-ticker.C:
				if !hasUrgent {
					blink = false
					continue
				}
				blink = !blink
				hasUrgent, err = emitBar(blink)
				if err != nil {
					log.Printf("i3-workspace-group bar: %v", err)
				}
			case <-done:
				break loop
			}
		}
		ticker.Stop()

		err = receiver.Close()
		if err == nil {
			return nil
		}
		log.Printf("i3-workspace-group bar: subscription: %v", err)
		time.Sleep(time.Second)
	}
}

func collectBarEvents(receiver *i3.EventReceiver, events chan<- struct{}) {
	for receiver.Next() {
		if event, ok := receiver.Event().(*i3.WindowEvent); ok {
			if event.Change != "urgent" && event.Change != "close" {
				continue
			}
		}
		select {
		case events <- struct{}{}:
		default:
		}
	}
}

func emitBar(showUrgent bool) (bool, error) {
	outputs, err := i3.GetOutputs()
	if err != nil {
		return false, fmt.Errorf("get outputs: %w", err)
	}
	workspaces, err := i3.GetWorkspaces()
	if err != nil {
		return false, fmt.Errorf("get workspaces: %w", err)
	}

	state, hasUrgent := applyBarBlink(PlanBarState(outputs, workspaces), showUrgent)
	encoder := json.NewEncoder(os.Stdout)
	encoder.SetEscapeHTML(false)
	if err := encoder.Encode(state); err != nil {
		return hasUrgent, err
	}
	return hasUrgent, nil
}
