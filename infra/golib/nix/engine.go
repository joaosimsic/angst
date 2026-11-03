package nix

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os/exec"
	"strings"

	"github.com/joaosimsic/angst/infra/golib/repo"
)

type Engine struct {
	Worktree repo.Worktree
	Command  string
}

type Exports struct {
	Kind  string   `json:"kind"`
	Names []string `json:"names"`
}

func (engine Engine) ParseExpression(relativePath string) (string, error) {
	output, err := engine.run("--parse", engine.Worktree.Abs(relativePath))
	if err != nil {
		return "", err
	}

	return string(output), nil
}

func (engine Engine) Exports(relativePath string) (Exports, error) {
	absolutePath := engine.Worktree.Abs(relativePath)

	expression := fmt.Sprintf(`let
  value = import (/. + "%s");
  type = builtins.typeOf value;
  isDerivation = type == "set" && (value.type or "") == "derivation";
  kinds = {
    set = if isDerivation then "derivation" else "attrs";
  };
  kind = kinds.${type} or type;
  names = if kind == "attrs" then builtins.attrNames value else [ ];
in
{ inherit kind names; }`, Quote(absolutePath))

	output, err := engine.run("--eval", "--strict", "--json", "-E", expression)
	if err != nil {
		return Exports{}, err
	}

	var exports Exports
	if err := json.Unmarshal(output, &exports); err != nil {
		return Exports{}, fmt.Errorf("decode nix output: %w", err)
	}

	return exports, nil
}

func (engine Engine) run(args ...string) ([]byte, error) {
	command := engine.Command
	if command == "" {
		command = "nix-instantiate"
	}

	cmd := exec.Command(command, args...)

	var stderr bytes.Buffer
	cmd.Stderr = &stderr

	output, err := cmd.Output()
	if err != nil {
		message := strings.TrimSpace(stderr.String())
		if message == "" {
			return nil, fmt.Errorf("%s: %w", command, err)
		}

		return nil, fmt.Errorf("%s: %s: %w", command, message, err)
	}

	return output, nil
}

func Quote(value string) string {
	value = strings.ReplaceAll(value, `\`, `\\`)

	value = strings.ReplaceAll(value, `"`, `\"`)

	value = strings.ReplaceAll(value, `${`, `\${`)

	return value
}
