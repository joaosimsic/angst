{
  lib,
  themesLib,
  themeName,
  checkHelpers,
  ...
}:

let
  t = themesLib.get themeName;

  moduleNames = [
    "env_var"
    "directory"
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
    "pixi"
    "purescript"
    "python"
    "quarto"
    "raku"
    "red"
    "rlang"
    "ruby"
    "rust"
    "scala"
    "solidity"
    "spack"
    "swift"
    "terraform"
    "typst"
    "vlang"
    "xmake"
    "zig"
    "conda"
    "nix_shell"
    "guix_shell"
    "docker_context"
    "package"
  ];

  modules = [
    {
      name = "buf";
      symbol = " ";
      color = "00A1E0";
    }
    {
      name = "bun";
      symbol = " ";
      color = "FBF0DF";
    }
    {
      name = "c";
      symbol = " ";
      color = "A8B9CC";
    }
    {
      name = "cpp";
      symbol = " ";
      color = "00599C";
      extra = "disabled = false";
    }
    {
      name = "cmake";
      symbol = " ";
      color = "064F8C";
    }
    {
      name = "cobol";
      symbol = " ";
      color = "005CA5";
    }
    {
      name = "crystal";
      symbol = " ";
      color = "FFFFFF";
    }
    {
      name = "daml";
      symbol = "󰚩 ";
      color = "4477AA";
    }
    {
      name = "dart";
      symbol = " ";
      color = "0175C2";
    }
    {
      name = "deno";
      symbol = " ";
      color = "70FFAF";
    }
    {
      name = "dotnet";
      symbol = " ";
      color = "512BD4";
    }
    {
      name = "elixir";
      symbol = " ";
      color = "4B275F";
    }
    {
      name = "elm";
      symbol = " ";
      color = "1293D8";
    }
    {
      name = "erlang";
      symbol = " ";
      color = "A90533";
    }
    {
      name = "fennel";
      symbol = " ";
      color = "FFF3D7";
      extra = "disabled = false";
    }
    {
      name = "fortran";
      symbol = " ";
      color = "734F96";
    }
    {
      name = "gleam";
      symbol = " ";
      color = "FFAFF3";
    }
    {
      name = "golang";
      symbol = " ";
      color = "00ADD8";
    }
    {
      name = "gradle";
      symbol = " ";
      color = "02303A";
    }
    {
      name = "haskell";
      symbol = " ";
      color = "5E5086";
    }
    {
      name = "haxe";
      symbol = " ";
      color = "EA8220";
    }
    {
      name = "helm";
      symbol = "󰠳 ";
      color = "0F1689";
    }
    {
      name = "java";
      symbol = " ";
      color = "ED8B00";
    }
    {
      name = "julia";
      symbol = " ";
      color = "9558B2";
    }
    {
      name = "kotlin";
      symbol = " ";
      color = "7F52FF";
    }
    {
      name = "lua";
      symbol = " ";
      color = "000080";
    }
    {
      name = "maven";
      symbol = " ";
      color = "C71A36";
    }
    {
      name = "meson";
      symbol = "󰔷 ";
      color = "007800";
      format = "[$symbol](#007800)[$project]($style) ";
    }
    {
      name = "mojo";
      symbol = " ";
      color = "FF4C1F";
    }
    {
      name = "nim";
      symbol = "󰆥 ";
      color = "FFC200";
    }
    {
      name = "nodejs";
      symbol = " ";
      color = "339933";
    }
    {
      name = "ocaml";
      symbol = " ";
      color = "EC6813";
    }
    {
      name = "odin";
      symbol = "󰟢 ";
      color = "3882D2";
    }
    {
      name = "opa";
      symbol = "󰟓 ";
      color = "7D9199";
    }
    {
      name = "perl";
      symbol = " ";
      color = "39457E";
    }
    {
      name = "php";
      symbol = " ";
      color = "777BB4";
    }
    {
      name = "pixi";
      symbol = "󰏗 ";
      color = "F5C542";
    }
    {
      name = "purescript";
      symbol = " ";
      color = "FFFFFF";
    }
    {
      name = "python";
      symbol = " ";
      color = "3776AB";
      format = "[$symbol](#3776AB)[$version]($style) ";
    }
    {
      name = "quarto";
      symbol = "󰧮 ";
      color = "39729E";
    }
    {
      name = "raku";
      symbol = "󰛓 ";
      color = "0000FB";
    }
    {
      name = "red";
      symbol = "󰝤 ";
      color = "D91E18";
    }
    {
      name = "rlang";
      symbol = "󰟔 ";
      color = "276DC3";
    }
    {
      name = "ruby";
      symbol = " ";
      color = "CC342D";
    }
    {
      name = "rust";
      symbol = "󱘗 ";
      color = "DEA584";
    }
    {
      name = "scala";
      symbol = " ";
      color = "DC322F";
    }
    {
      name = "solidity";
      symbol = " ";
      color = "8A8A8A";
    }
    {
      name = "spack";
      symbol = "󰆼 ";
      color = "0F70B7";
      format = "[$symbol](#0F70B7)[$environment]($style) ";
    }
    {
      name = "swift";
      symbol = " ";
      color = "F05138";
    }
    {
      name = "terraform";
      symbol = "󱁢 ";
      color = "844FBA";
      format = "[$symbol](#844FBA)[$workspace]($style) ";
    }
    {
      name = "typst";
      symbol = " ";
      color = "239DAD";
    }
    {
      name = "vlang";
      symbol = " ";
      color = "5D87BF";
    }
    {
      name = "xmake";
      symbol = " ";
      color = "22A079";
    }
    {
      name = "zig";
      symbol = " ";
      color = "F7A41D";
    }
    {
      name = "conda";
      symbol = " ";
      color = "44A833";
      format = "[$symbol](#44A833)[$environment]($style) ";
    }
    {
      name = "nix_shell";
      symbol = " ";
      color = "5277C3";
      format = "[$symbol](#5277C3)[$state]($style) ";
    }
    {
      name = "env_var.SHELL_MODE";
      symbol = " ";
      color = "5277C3";
      format = "[$symbol](#5277C3)[$env_value]($style) ";
      extra = ''
        style = "bold white"
        variable = "SHELL_MODE"
      '';
    }
    {
      name = "guix_shell";
      symbol = " ";
      color = "FFCC00";
      format = "[$symbol](#FFCC00) ";
    }
    {
      name = "docker_context";
      symbol = " ";
      color = "2496ED";
      format = "[$symbol](#2496ED)[$context]($style) ";
    }
    {
      name = "package";
      symbol = "󰏗 ";
      color = "CB3837";
      format = "[$symbol](#CB3837)[$version]($style) ";
    }
  ];

  renderModule =
    module:
    let
      format = module.format or "[$symbol](#${module.color})[($version)]($style) ";
      extra = module.extra or "";
    in
    ''
      [${module.name}]
      format = "${format}"
      symbol = "${module.symbol}"
      style = "#${t.COMMENT}"
    ''
    + lib.optionalString (extra != "") ''
      ${extra}
    '';

  formatLine = "$env_var$directory " + "$" + lib.concatStringsSep "$" (lib.drop 1 moduleNames);

  inherit (checkHelpers) requireInfix require;

  starshipText = ''
    format = """
    ${formatLine}

    """

    add_newline = true

    [directory]
    format = "[$path]($style)[$read_only]($read_only_style)"
    style = "bold #${t.ACCENT}"
    read_only = " RO"
    read_only_style = "bold #${t.ERROR}"
    truncation_length = 3
    truncate_to_repo = false

    [git_branch]
    format = "*[$branch]($style)"
    style = "#${t.COMMENT}"
    symbol = ""

    [git_status]
    format = ' [\[$all_status$ahead_behind\]]($style) '
    style = "#${t.WARNING}"
    conflicted = "!"
    ahead = "+"
    behind = "-"
    diverged = "+-"
    untracked = "?"
    stashed = "*"
    modified = "~"
    staged = "+"
    renamed = "r"
    deleted = "x"

    [username]
    format = "[$user]($style) "
    style_user = "bold #${t.BRIGHT}"
    style_root = "bold #${t.ERROR}"
    show_always = true

    [hostname]
    format = "[@$hostname]($style) "
    style = "bold #${t.COMMENT}"
    ssh_only = true

    ${lib.concatStringsSep "\n" (map renderModule modules)}
  '';
in
[
  {
    path = "domains/shell/starship/config/starship.toml";
    text = starshipText;
    checks = [
      (requireInfix starshipText "bold #${t.ACCENT}"
        "starship directory style should render ${themeName} ACCENT"
      )
      (requireInfix starshipText "bold #${t.ERROR}"
        "starship error_symbol should render ${themeName} ERROR"
      )
      (require (t.SUCCESS != t.ERROR) "starship semantic SUCCESS and ERROR must differ in ${themeName}")
    ];
  }
]
