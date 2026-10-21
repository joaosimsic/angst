package i3workspacegroup

import (
	"fmt"
	"log"
	"time"

	"go.i3wm.org/i3/v4"
)

func Daemon() error {
	lock, err := acquireDaemonLock()
	if err != nil {
		return err
	}
	defer lock.Close()

	if renamed, err := AdoptIfNeeded(); err != nil {
		log.Printf("i3-workspace-group daemon: adopt: %v", err)
	} else if renamed > 0 {
		log.Printf("i3-workspace-group daemon: adopted %d workspace(s)", renamed)
	}

	if err := syncOpacity(); err != nil {
		log.Printf("i3-workspace-group daemon: %v", err)
	}

	for {
		receiver := i3.Subscribe(i3.WorkspaceEventType, i3.OutputEventType, i3.WindowEventType)
		triggers := make(chan struct{}, 1)
		go collectTriggers(receiver, triggers)

		for range triggers {
			time.Sleep(25 * time.Millisecond)
			drainTriggers(triggers)
			if err := syncOnce(); err != nil {
				log.Printf("i3-workspace-group daemon: %v", err)
			}
		}

		if err := receiver.Close(); err != nil {
			log.Printf("i3-workspace-group daemon: subscription: %v", err)
		}
		time.Sleep(time.Second)
	}
}

func collectTriggers(receiver *i3.EventReceiver, triggers chan<- struct{}) {
	defer close(triggers)
	for receiver.Next() {
		switch event := receiver.Event().(type) {
		case *i3.WorkspaceEvent:
			if event.Change == "focus" || event.Change == "init" || event.Change == "move" {
				notifyTrigger(triggers)
			}
		case *i3.OutputEvent:
			notifyTrigger(triggers)
		case *i3.WindowEvent:
			switch event.Change {
			case "new", "close", "focus", "move", "floating", "fullscreen_mode":
				notifyTrigger(triggers)
			}
		}
	}
}

func syncOnce() error {
	if err := syncOpacity(); err != nil {
		log.Printf("i3-workspace-group daemon: %v", err)
	}

	if renamed, err := AdoptIfNeeded(); err != nil {
		log.Printf("i3-workspace-group daemon: adopt: %v", err)
	} else if renamed > 0 {
		log.Printf("i3-workspace-group daemon: adopted %d workspace(s)", renamed)
	}

	workspaces, err := i3.GetWorkspaces()
	if err != nil {
		return fmt.Errorf("get workspaces: %w", err)
	}

	for _, workspace := range workspaces {
		if !workspace.Visible {
			continue
		}
		group, inner, ok := ParseWorkspace(workspace.Name)
		if !ok {
			continue
		}
		if err := updateState(statePath(), group, workspace.Output, inner); err != nil {
			log.Printf("i3-workspace-group daemon: %v", err)
		}
	}

	focused, ok := focusedWorkspace(workspaces)
	if !ok {
		return nil
	}
	group, _, ok := ParseWorkspace(focused.Name)
	if !ok {
		return nil
	}

	outputs, err := i3.GetOutputs()
	if err != nil {
		return fmt.Errorf("get outputs: %w", err)
	}
	return runCommands(PlanSync(outputs, workspaces, loadCurrentState(), group))
}

func notifyTrigger(triggers chan<- struct{}) {
	select {
	case triggers <- struct{}{}:
	default:
	}
}

func drainTriggers(triggers <-chan struct{}) {
	for {
		select {
		case <-triggers:
		default:
			return
		}
	}
}
