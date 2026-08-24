#!/usr/bin/env nu

def level-of [line: string] {
  let l = ($line | str lowercase)
  if ($l =~ '(error|panic|failed|fatal|invalid nushell)') {
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

def main --wrapped [...args] {
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
  let exit_file = ($state_dir | path join $"exit-($stamp)")
  let latest = ($state_dir | path join "latest.log")
  let user = ($env.USER? | default "user")
  let host = (sys host | get hostname)
  let cmdline = $"home-manager (($hm_args | str join ' '))"

  print $"(ansi green_bold)── angst hm-switch ──(ansi reset) (ansi green)($stamp)  ($user)@($host)(ansi reset)"
  print $"(ansi dark_gray)($cmdline)(ansi reset)"

  $"── angst hm-switch ── ($stamp)  ($user)@($host)(char nl)cmd: ($cmdline)(char nl)" | save --force $log_path

  let stream = (
    ^bash -c 'home-manager "$@" 2>&1; echo $? > "$0"' $exit_file ...$hm_args
    | lines
    | each { |line|
        let lvl = (level-of $line)
        let ts = (date now | format date "%H:%M:%S")
        let badge = (color-badge $lvl)
        print $"($badge)[($lvl)](ansi reset) ($ts) ($line)"
        $"[($lvl)] ($ts) ($line)(char nl)" | save --append $log_path
      }
  )

  let exit_code = (open $exit_file | str trim | into int)
  rm -f $exit_file

  let logged = (open $log_path | lines | parse -r '\[(?P<lvl>\w+)\]')
  let errors = ($logged | where lvl == "ERROR" | length)
  let warns = ($logged | where lvl == "WARN" | length)
  let steps = ($logged | where lvl == "STEP" | length)

  print $"(ansi reset)── summary ──  exit ($exit_code)  errors ($errors)  warnings ($warns)  steps ($steps)"
  print $"log: ($log_path)"

  cp $log_path $latest

  exit $exit_code
}
