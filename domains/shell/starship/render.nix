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
    "r"
    "raku"
    "ruby"
    "rust"
    "scala"
    "solidity"
    "spack"
    "sphinx"
    "sql"
    "svelte"
    "swift"
    "terraform"
    "typst"
    "vagrant"
    "vala"
    "verilog"
    "vlang"
    "zig"
  ];

  modules = [
    {
      name = "daml";
      symbol = " ";
      color = "BFCAA3";
    }
    {
      name = "buf";
      symbol = " ";
      color = "C8916C";
    }
    {
      name = "bun";
      symbol = " ";
      color = "F9C1B1";
    }
    {
      name = "c";
      symbol = " ";
      color = "599BF5";
    }
    {
      name = "cmake";
      symbol = " ";
      color = "75AADB";
    }
    {
      name = "cobol";
      symbol = "⚙ ";
      color = "005CA5";
    }
    {
      name = "cpp";
      symbol = " ";
      color = "599BF5";
    }
    {
      name = "crystal";
      symbol = " ";
      color = "FAE2AF";
    }
    {
      name = "dart";
      symbol = " ";
      color = "66B9F0";
    }
    {
      name = "deno";
      symbol = " ";
      color = "A7D192";
    }
    {
      name = "dotnet";
      symbol = " ";
      color = "A77EDB";
    }
    {
      name = "elixir";
      symbol = " ";
      color = "A076B5";
    }
    {
      name = "elm";
      symbol = " ";
      color = "5CC1D5";
    }
    {
      name = "erlang";
      symbol = " ";
      color = "CA274A";
    }
    {
      name = "fennel";
      symbol = " ";
      color = "C2D48B";
    }
    {
      name = "fortran";
      symbol = "󱈚 ";
      color = "815AA4";
    }
    {
      name = "gleam";
      symbol = " ";
      color = "F6C8B5";
    }
    {
      name = "golang";
      symbol = " ";
      color = "6AD0E0";
    }
    {
      name = "gradle";
      symbol = " ";
      color = "86CD82";
    }
    {
      name = "haskell";
      symbol = " ";
      color = "9B6CCE";
    }
    {
      name = "haxe";
      symbol = " ";
      color = "EAA56F";
    }
    {
      name = "helm";
      symbol = "⎈ ";
      color = "5880BE";
    }
    {
      name = "java";
      symbol = " ";
      color = "E76F54";
    }
    {
      name = "julia";
      symbol = " ";
      color = "3EB886";
    }
    {
      name = "kotlin";
      symbol = " ";
      color = "7B60B5";
    }
    {
      name = "lua";
      symbol = " ";
      color = "519ABC";
    }
    {
      name = "maven";
      symbol = " ";
      color = "C64A36";
    }
    {
      name = "meson";
      symbol = "󰔿 ";
      color = "6DB48D";
    }
    {
      name = "mojo";
      symbol = " ";
      color = "EAA56F";
    }
    {
      name = "nim";
      symbol = " ";
      color = "C9D17E";
    }
    {
      name = "nodejs";
      symbol = " ";
      color = "6DA55F";
    }
    {
      name = "ocaml";
      symbol = " ";
      color = "E67E4C";
    }
    {
      name = "odin";
      symbol = " ";
      color = "3884D9";
    }
    {
      name = "opa";
      symbol = " ";
      color = "87D0D0";
    }
    {
      name = "perl";
      symbol = " ";
      color = "A0BADA";
    }
    {
      name = "php";
      symbol = " ";
      color = "7C8FC3";
    }
    {
      name = "pulumi";
      symbol = " ";
      color = "C17776";
    }
    {
      name = "python";
      symbol = " ";
      color = "F5D87B";
    }
    {
      name = "r";
      symbol = "󰟔 ";
      color = "3A80B9";
    }
    {
      name = "raku";
      symbol = " ";
      color = "B5C0D1";
    }
    {
      name = "ruby";
      symbol = " ";
      color = "C7383E";
    }
    {
      name = "rust";
      symbol = " ";
      color = "E8AF4C";
    }
    {
      name = "scala";
      symbol = " ";
      color = "C53B2D";
    }
    {
      name = "solidity";
      symbol = "ﲹ ";
      color = "C0C9D7";
    }
    {
      name = "spack";
      symbol = " ";
      color = "66A1B7";
    }
    {
      name = "sphinx";
      symbol = " ";
      color = "97BBD9";
    }
    {
      name = "sql";
      symbol = " ";
      color = "B3BAC5";
    }
    {
      name = "svelte";
      symbol = " ";
      color = "CF897B";
    }
    {
      name = "swift";
      symbol = "�刀 ";
      color = "E77656";
    }
    {
      name = "terraform";
      symbol = " ";
      color = "7C91BE";
    }
    {
      name = "typst";
      symbol = " ";
      color = "435C73";
    }
    {
      name = "vagrant";
      symbol = " ";
      color = "4173B7";
    }
    {
      name = "vala";
      symbol = " ";
      color = "99405C";
    }
    {
      name = "verilog";
      symbol = "󰍛 ";
      color = "286887";
    }
    {
      name = "vlang";
      symbol = "󰍛 ";
      color = "86AACB";
    }
    {
      name = "zig";
      symbol = " ";
      color = "DF9169";
    }
  ];

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

  formatLine = "$username$hostname $env_var$directory " + "$" + lib.concatStringsSep "$" (lib.drop 1 moduleNames);

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
    format = "*[$branch]($style)"
    style = "#${p.dim}"
    symbol = ""

    [git_status]
    format = ' [\[$all_status$ahead_behind\]]($style) '
    style = "#${t.ansi.warn}"
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
    format = "[$user]($style)"
    style_user = "bold #5f7a5f"
    style_root = "bold #${t.ansi.error}"
    show_always = true

    [hostname]
    format = "[@$hostname]($style)"
    style = "bold #5f7a5f"
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
      (require (t.ansi.success != t.ansi.error) "starship semantic ansi.success and ansi.error must differ in ${themeName}")
    ];
  }
]
