package i3workspacegroup

import (
	"encoding/json"
	"fmt"
	"log"
	"os"
	"time"

	"go.i3wm.org/i3/v4"
)

func Bar() error {
	for {
		receiver := i3.Subscribe(i3.WorkspaceEventType, i3.OutputEventType)
		if err := emitBar(); err != nil {
			log.Printf("i3-workspace-group bar: %v", err)
		}
		for receiver.Next() {
			if err := emitBar(); err != nil {
				log.Printf("i3-workspace-group bar: %v", err)
			}
		}
		err := receiver.Close()
		if err == nil {
			return nil
		}
		log.Printf("i3-workspace-group bar: subscription: %v", err)
		time.Sleep(time.Second)
	}
}

func emitBar() error {
	outputs, err := i3.GetOutputs()
	if err != nil {
		return fmt.Errorf("get outputs: %w", err)
	}
	workspaces, err := i3.GetWorkspaces()
	if err != nil {
		return fmt.Errorf("get workspaces: %w", err)
	}

	encoder := json.NewEncoder(os.Stdout)
	encoder.SetEscapeHTML(false)
	return encoder.Encode(PlanBarState(outputs, workspaces))
}
