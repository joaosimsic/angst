$env.STARSHIP_SHELL = "nu"

def create_left_prompt [] {
    starship prompt --cmd-duration $env.CMD_DURATION_MS $'--status=($env.LAST_EXIT_CODE)'
}

$env.PROMPT_COMMAND = { || create_left_prompt }
$env.PROMPT_COMMAND_RIGHT = ""
$env.PROMPT_INDICATOR = ""
$env.PROMPT_INDICATOR_VI_INSERT = ": "
$env.PROMPT_INDICATOR_VI_NORMAL = "> "
$env.PROMPT_MULTILINE_INDICATOR = "::: "

$env.EDITOR = "nvim"
$env.VISUAL = "nvim"

const XDG_CONFIG_HOME = ($nu.home-dir | path join ".config")
const XDG_DATA_HOME = ($nu.data-dir | path dirname)
const XDG_CACHE_HOME = ($nu.cache-dir | path dirname)

$env.XDG_CONFIG_HOME = $XDG_CONFIG_HOME
$env.XDG_DATA_HOME = $XDG_DATA_HOME
$env.XDG_CACHE_HOME = $XDG_CACHE_HOME

$env.CLAUDE_CONFIG_DIR = ($XDG_CONFIG_HOME | path join "claude")

$env.PATH = (
    $env.PATH
    | split row (char esep)
    | prepend ($nu.home-dir | path join ".local/bin")
    | prepend ($nu.home-dir | path join ".cargo/bin")
    | uniq
)

# Add nix profile pkgconfig to PKG_CONFIG_PATH for cargo/rust-analyzer builds
$env.PKG_CONFIG_PATH = ("~/.nix-profile/lib/pkgconfig" | path expand)

const carapace_init = ($XDG_CACHE_HOME | path join "carapace/init.nu")

if not ($carapace_init | path exists) {
    mkdir ($carapace_init | path dirname)
    carapace _carapace nushell | save --force $carapace_init
}
source $carapace_init
