{
  pkgs,
  lib,
  self,
}:

let
  goAngstUnwrapped = pkgs.buildGoModule {
    pname = "angst";
    version = "0.1.0";
    src = ./angst;
    vendorHash = null;
  };

  goAngst = pkgs.runCommand "angst" { nativeBuildInputs = [ pkgs.makeWrapper ]; } ''
    mkdir -p $out/bin
    makeWrapper ${goAngstUnwrapped}/bin/angst $out/bin/angst \
      --prefix PATH : ${
        lib.makeBinPath [
          pkgs.age
          pkgs.openssh
        ]
      }
  '';

  goVmUnwrapped = pkgs.buildGoModule {
    pname = "vm";
    version = "0.1.0";
    src = ./vm;
    vendorHash = null;
    subPackages = [ "cmd/vm" ];
  };

  goVm = pkgs.runCommand "vm" { nativeBuildInputs = [ pkgs.makeWrapper ]; } ''
    mkdir -p $out/bin
    makeWrapper ${goVmUnwrapped}/bin/vm $out/bin/vm \
      --prefix PATH : ${
        lib.makeBinPath [
          pkgs.age
          pkgs.openssh
        ]
      }
  '';

  goShellUnwrapped = pkgs.buildGoModule {
    pname = "angst-shell";
    version = "0.1.0";
    src = ./shell;
    vendorHash = null;
    subPackages = [ "cmd/shell" ];
  };

  goShell = pkgs.runCommand "angst-shell" { nativeBuildInputs = [ pkgs.makeWrapper ]; } ''
    mkdir -p $out/bin
    makeWrapper ${goShellUnwrapped}/bin/shell $out/bin/angst-shell \
      --prefix PATH : ${
        lib.makeBinPath [
          pkgs.age
          pkgs.openssh
        ]
      }
  '';

  goAnalyzeUnwrapped = pkgs.buildGoModule {
    pname = "analyze";
    version = "0.1.0";
    src = ./analyze;
    vendorHash = null;
    subPackages = [ "cmd/analyze" ];
  };

  goAnalyze = pkgs.runCommand "analyze" { nativeBuildInputs = [ pkgs.makeWrapper ]; } ''
    mkdir -p $out/bin
    makeWrapper ${goAnalyzeUnwrapped}/bin/analyze $out/bin/analyze \
      --prefix PATH : ${
        lib.makeBinPath [
          pkgs.age
          pkgs.openssh
        ]
      }
  '';

  vmTool = pkgs.runCommand "vm-tool" { nativeBuildInputs = [ pkgs.makeWrapper ]; } ''
    mkdir -p $out/bin
    makeWrapper ${goVm}/bin/vm $out/bin/vm \
      --prefix PATH : ${
        lib.makeBinPath [
          pkgs.qemu
          pkgs.openssh
          pkgs.coreutils
          pkgs.procps
          pkgs.bash
          pkgs.nix
          pkgs.age
        ]
      }
  '';

  mkAngstShell =
    {
      devShell,
      safeShell,
      treesitter ? null,
      enabledShells ? "/bin/bash",
    }:
    let
      treesitterParsers = if treesitter != null then treesitter.treesitterParsers else "";
      treesitterQueries = if treesitter != null then treesitter.treesitterQueries else "";
    in
    pkgs.writeShellApplication {
      name = "angst-shell";
      runtimeInputs = [ goShell ];
      text = ''
        export SHELL_DEV_PATH=${devShell}/bin
        export SHELL_SAFE_PATH=${safeShell}/bin
        export SHELL_ENABLED_SHELLS=${enabledShells}
        export SHELL_TS_PARSERS=${treesitterParsers}
        export SHELL_TS_QUERIES=${treesitterQueries}
        exec ${goShell}/bin/angst-shell "$@"
      '';
    };

  goLoggerUnwrapped = pkgs.buildGoModule {
    pname = "angst-logger";
    version = "0.1.0";
    src = ./logger;
    vendorHash = null;
    subPackages = [ "cmd/hm-switch" ];
  };

  hmSwitchTool = pkgs.runCommand "angst-hm-switch" { nativeBuildInputs = [ pkgs.makeWrapper ]; } ''
    mkdir -p $out/bin
    makeWrapper ${goLoggerUnwrapped}/bin/hm-switch $out/bin/hm-switch \
      --prefix PATH : ${
        lib.makeBinPath [
          pkgs.bash
          pkgs.coreutils
        ]
      } \
      --set-default ANGST_LOG_LEVEL info
  '';

  mkScript =
    {
      name,
      text,
      runtimeInputs ? [ ],
      excludeShellChecks ? [ ],
      meta ? { },
    }:
    let
      drv = pkgs.writeShellApplication {
        inherit
          name
          text
          runtimeInputs
          excludeShellChecks
          ;
        meta = meta // {
          mainProgram = name;
        };
      };
    in
    drv // { bin = "${drv}/bin/${name}"; };

  # Import a script passing exactly the arguments it declares. This avoids
  # every script needing a `...` rest attribute while still sharing one pool
  # of available dependencies.
  callWith =
    pool: path:
    let
      f = import path;
    in
    f (builtins.intersectAttrs (builtins.functionArgs f) pool);

  # Full pool of dependencies a script may reference. Each script receives
  # only the subset it actually declares (via builtins.functionArgs).
  allArgs = {
    inherit
      mkScript
      pkgs
      lib
      goAngst
      goVm
      goShell
      goAnalyze
      goLoggerUnwrapped
      self
      vmTool
      hmSwitchTool
      ;
  };

  # angst-cli is imported first because other scripts depend on it as the
  # `angstCli` argument.
  angstCli = callWith allArgs ./angst-cli.nix;

  allArgsWithAngstCli = allArgs // {
    inherit angstCli;
  };

  goSourceDirs = [
    "angst"
    "shell"
    "logger"
    "analyze"
    "cmd"
    "internal"
  ];

  discover =
    dir:
    let
      entries = builtins.readDir dir;
      names = builtins.attrNames entries;

      process =
        name:
        let
          path = dir + "/${name}";
          type = entries.${name};
        in
        if type == "directory" then
          if builtins.elem name goSourceDirs then
            null
          else
            {
              inherit name;
              value = discover path;
            }
        else if
          type == "regular" && name != "default.nix" && name != "angst-cli.nix" && lib.hasSuffix ".nix" name
        then
          {
            name = lib.removeSuffix ".nix" name;
            value = callWith allArgsWithAngstCli path;
          }
        else
          null;

      handled = builtins.filter (x: x != null) (map process names);
    in
    builtins.listToAttrs handled;

  scripts = discover ./.;
in
{
  inherit
    goAngst
    goVm
    goVmUnwrapped
    goShell
    goShellUnwrapped
    goAnalyze
    goAnalyzeUnwrapped
    goLoggerUnwrapped
    hmSwitchTool
    mkScript
    vmTool
    mkAngstShell
    ;

}
// scripts
// {
  angst-cli = angstCli;
}
