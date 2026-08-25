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

  # Wrapper with the full PATH needed by the host-side VM workflow
  # (qemu/openssh/coreutils/procps/bash/nix) — mirrors the old Rust `wrapped`
  # binary without pulling in the Rust toolchain.
  vmTool = pkgs.runCommand "angst-vm" { nativeBuildInputs = [ pkgs.makeWrapper ]; } ''
    mkdir -p $out/bin
    makeWrapper ${goAngst}/bin/angst $out/bin/angst \
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

  # Builds the `angst shell` wrapper that bakes the dev/safe environment paths
  # (the Nix wrapper that was never actually built for the Rust `shell` tool).
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
      runtimeInputs = [ goAngst ];
      text = ''
        export SHELL_DEV_PATH=${devShell}/bin
        export SHELL_SAFE_PATH=${safeShell}/bin
        export SHELL_ENABLED_SHELLS=${enabledShells}
        export SHELL_TS_PARSERS=${treesitterParsers}
        export SHELL_TS_QUERIES=${treesitterQueries}
        exec ${goAngst}/bin/angst shell "$@"
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

  loginShell = import ./login-shell.nix { inherit mkScript pkgs goAngst; };
  sshAddKeys = import ./ssh-add-keys.nix {
    inherit
      mkScript
      pkgs
      goAngst
      lib
      ;
  };
  sshKeyProvision = import ./ssh-key-provision.nix { inherit mkScript pkgs goAngst; };
  bootstrapSecrets = import ./bootstrap-secrets.nix { inherit mkScript pkgs goAngst; };
  projectsSync = import ./projects-sync.nix {
    inherit
      mkScript
      pkgs
      goAngst
      lib
      ;
  };
  ftpMount = import ./ftp-mount.nix { inherit mkScript pkgs goAngst; };
  ftpSecretsHome = import ./ftp-secrets-home.nix { inherit mkScript pkgs goAngst; };
  devshellHook = import ./devshell-hook.nix { inherit pkgs; };
  angstCli = import ./angst-cli.nix { inherit mkScript pkgs goAngst; };

  apps = {
    render = import ./apps/render.nix {
      inherit mkScript;
      inherit angstCli;
    };
    watch = import ./apps/watch.nix {
      inherit mkScript;
      inherit angstCli;
    };
    check = import ./apps/check.nix { inherit mkScript pkgs; };
    lint-themes = import ./apps/lint-themes.nix { inherit mkScript pkgs self; };
    lint-desktop = import ./apps/lint-desktop.nix { inherit mkScript pkgs self; };
    lint-shell = import ./apps/lint-shell.nix { inherit mkScript pkgs self; };
    analyze = import ./apps/analyze.nix { inherit mkScript pkgs; };
    analyze-to-file = import ./apps/analyze-to-file.nix { inherit mkScript pkgs; };
    ssh-deploy = import ./apps/ssh-deploy.nix { inherit mkScript pkgs self; };
  };

  vm = {
    homeManagerUpgrade = import ./vm/home-manager-upgrade.nix { inherit mkScript pkgs goAngst; };
    ephemeralSsh = import ./vm/ephemeral-ssh.nix { inherit mkScript pkgs goAngst; };
    ageKey = import ./vm/age-key.nix { inherit mkScript pkgs goAngst; };
    nixosSwitch = import ./vm/nixos-switch.nix { inherit mkScript pkgs goAngst; };
    homeSwitch = import ./vm/home-switch.nix { inherit mkScript pkgs goAngst; };
  };
in
{
  inherit
    goAngst
    goLoggerUnwrapped
    hmSwitchTool
    mkScript
    vmTool
    mkAngstShell
    loginShell
    sshAddKeys
    sshKeyProvision
    bootstrapSecrets
    projectsSync
    ftpMount
    ftpSecretsHome
    devshellHook
    angstCli
    apps
    vm
    ;
}
