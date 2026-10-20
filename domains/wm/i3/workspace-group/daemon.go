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

	for {
		receiver := i3.Subscribe(i3.WorkspaceEventType, i3.OutputEventType)
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
			if event.Change == "focus" || event.Change == "init" {
				notifyTrigger(triggers)
			}
		case *i3.OutputEvent:
			notifyTrigger(triggers)
		}
	}
}

func syncOnce() error {
	workspaces, err := i3.GetWorkspaces()
	if err != nil {
		return fmt.Errorf("get workspaces: %w", err)
	}

	if commands := PlanRepair(workspaces); len(commands) > 0 {
		if err := runCommands(commands); err != nil {
			return err
		}
		workspaces, err = i3.GetWorkspaces()
		if err != nil {
			return fmt.Errorf("get workspaces after repair: %w", err)
		}
	}

	for _, workspace := range workspaces {
		if !workspace.Visible {
			continue
		}
		group, inner, output, ok := ParseWorkspace(workspace.Name)
		if !ok {
			continue
		}
		if err := updateState(statePath(), group, output, inner); err != nil {
			log.Printf("i3-workspace-group daemon: %v", err)
		}
	}

	focused, ok := focusedWorkspace(workspaces)
	if !ok {
		return nil
	}
	group, _, _, ok := ParseWorkspace(focused.Name)
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
