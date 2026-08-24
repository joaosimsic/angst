#!/usr/bin/env nu

def level-of [line: string] {
  let l = ($line | str lowercase)
  if ($l =~ '(error|panic|failed|fatal)') {
    return "ERROR"
  }
  if ($l =~ 'warn') {
    return "WARN"
  }
  if ($l =~ '(starting home manager|activating|symlinking|setting up|creating|installing|healthcheck)') {
    return "STEP"
  }
  "INFO"
}

def color-badge [level: string] {
  match $level {
    "ERROR" => (ansi red_bold)
    "WARN" => (ansi yellow_bold)
    "STEP" => (ansi cyan_bold)
    _ => (ansi dark_gray)
  }
}

def main [...args: string] {
  let hm_args = if ($args | is-empty) {
    [switch --flake .]
  } else if (($args | first) | str starts-with '-') {
    [switch ...$args]
  } else {
    $args
  }

  let state_dir = (
    $env.XDG_STATE_HOME?
    | default ($nu.home-dir | path join ".local" "state")
    | path join "angst"
  )
  if not ($state_dir | path exists) {
    mkdir $state_dir
  }

  let stamp = (date now | format date "%Y-%m-%dT%H-%M-%S")
  let log_path = ($state_dir | path join $"switch-($stamp).log")
  let latest = ($state_dir | path join "latest.log")
  let user = ($env.USER? | default "user")
  let host = (sys host | get hostname)
  let cmdline = $"home-manager (($hm_args | str join ' '))"

  print $"(ansi green_bold)── angst hm-switch ──(ansi reset) (ansi green)($stamp)  ($user)@($host)(ansi reset)"
  print $"(ansi dark_gray)($cmdline)(ansi reset)"

  let result = (^home-manager ...$hm_args | complete)
  let exit_code = $result.exit_code

  mut all = []
  for line in ($result.stderr | lines) {
    $all = ($all | append { level: (level-of $line), text: $line })
  }
  for line in ($result.stdout | lines) {
    $all = ($all | append { level: (level-of $line), text: $line })
  }

  $"── angst hm-switch ── ($stamp)  ($user)@($host)(char nl)cmd: ($cmdline)(char nl)" | save --force $log_path

  for rec in $all {
    let ts = (date now | format date "%H:%M:%S")
    let badge = (color-badge $rec.level)
    print $"($badge)[($rec.level)](ansi reset) ($ts) ($rec.text)"
    $"[($rec.level)] ($ts) ($rec.text)(char nl)" | save --append $log_path
  }

  let errors = ($all | where level == "ERROR" | length)
  let warns = ($all | where level == "WARN" | length)
  let steps = ($all | where level == "STEP" | length)

  print $"(ansi reset)── summary ──  exit ($exit_code)  errors ($errors)  warnings ($warns)  steps ($steps)"
  print $"log: ($log_path)"

  cp $log_path $latest

  exit $exit_code
}
