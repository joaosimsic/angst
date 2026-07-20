{
  lib,
  themesLib,
  themeName,
  checkHelpers,
  ...
}:

let
  t = themesLib.get themeName;
  p = t.palette;

  moduleNames = [
    "nix_shell"
    "env_var"
    "git_branch"
    "git_status"
    "buf"
    "bun"
    "c"
    "cpp"
    "cmake"
    "cobol"
    "crystal"
    "daml"
    "dart"
    "deno"
    "dotnet"
    "elixir"
    "elm"
    "erlang"
    "fennel"
    "fortran"
    "gleam"
    "golang"
    "gradle"
    "haskell"
    "haxe"
    "helm"
    "java"
    "julia"
    "kotlin"
    "lua"
    "maven"
    "meson"
    "mojo"
    "nim"
    "nodejs"
    "ocaml"
    "odin"
    "opa"
    "perl"
    "php"
    "pulumi"
    "python"
    "rlang"
    "raku"
    "ruby"
    "rust"
    "scala"
    "solidity"
    "spack"
    "swift"
    "terraform"
    "typst"
    "vagrant"
    "vlang"
    "zig"
  ];

  modules = import ./modules.nix { inherit lib p t; };

  renderModule =
    module:
    let
      format = module.format or "[$symbol](#${module.color})[($version)]($style) ";
      extra = module.extra or "";
      styleValue = module.style or "#${p.dim}";
    in
    ''
      [${module.name}]
      format = "${format}"
      symbol = "${module.symbol}"
      style = "${styleValue}"
    ''
    + lib.optionalString (extra != "") ''
      ${extra}
    '';

  formatLine =
    "$username$hostname $nix_shell$env_var$directory "
    + "$"
    + lib.concatStringsSep "$" (lib.drop 1 moduleNames);

  inherit (checkHelpers) requireInfix require;

  starshipText = ''
    format = """
    ${formatLine}

    """

    add_newline = true

    [directory]
    format = "[$path]($style)[$read_only]($read_only_style)"
    style = "bold #${p.accent.base}"
    read_only = " RO"
    read_only_style = "bold #${t.ansi.error}"
    truncation_length = 3
    truncate_to_repo = false

    [git_branch]
    format = "[*$branch]($style)"
    style = "#${p.surface.variant}"
    symbol = ""

    [git_status]
    format = ' [\[$all_status$ahead_behind\]]($style) '
    style = "#${t.ansi.warn}"
    conflicted = "[!](#${t.ansi.error})"
    ahead = "[>](#${p.accent.base})"
    behind = "[<](#${p.accent.variant})"
    diverged = "[#](#${t.ansi.error})"
    untracked = "[?](#${p.foreground.base})"
    stashed = "[*](#${p.foreground.base})"
    modified = "[~](#${p.foreground.variant})"
    staged = "[+](#${t.ansi.success})"
    renamed = "[R](#${p.foreground.base})"
    deleted = "[X](#${t.ansi.error})"

    [username]
    format = "[$user]($style)"
    style_user = "bold #${p.surface.variant}"
    style_root = "bold #${t.ansi.error}"
    show_always = true

    [hostname]
    format = "[@$hostname]($style)"
    style = "bold #${p.surface.variant}"
    ssh_only = true

    ${lib.concatStringsSep "\n" (map renderModule modules)}
  '';
in
[
  {
    path = "domains/shell/starship/config/starship.toml";
    text = starshipText;
    checks = [
      (requireInfix starshipText "bold #${p.accent.base}"
        "starship directory style should render ${themeName} accent.base"
      )
      (requireInfix starshipText "bold #${t.ansi.error}"
        "starship error_symbol should render ${themeName} ansi.error"
      )
      (require (
        t.ansi.success != t.ansi.error
      ) "starship semantic ansi.success and ansi.error must differ in ${themeName}")
    ];
  }
]
