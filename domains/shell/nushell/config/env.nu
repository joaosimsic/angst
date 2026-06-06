$env.STARSHIP_SHELL = "nu"
$env.PROMPT_COMMAND = {|| starship prompt }
$env.PROMPT_COMMAND_RIGHT = ""
$env.PROMPT_INDICATOR = ""
$env.PROMPT_INDICATOR_VI_INSERT = ""
$env.PROMPT_INDICATOR_VI_NORMAL = ""
$env.PROMPT_MULTILINE_INDICATOR = "::: "

$env.EDITOR = "nvim"
$env.VISUAL = "nvim"

$env.XDG_CONFIG_HOME = ($env.HOME | path join ".config")
$env.XDG_DATA_HOME = ($env.HOME | path join ".local/share")
$env.XDG_CACHE_HOME = ($env.HOME | path join ".cache")

$env.CLAUDE_CONFIG_DIR = ($env.HOME | path join ".config/claude")

$env.PATH = (
    $env.PATH
    | split row (char esep)
    | prepend ($env.HOME | path join ".local/bin")
    | prepend ($env.HOME | path join ".cargo/bin")
    | uniq
)
