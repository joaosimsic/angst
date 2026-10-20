{
  self,
  pkgs,
  lib,
  runtime,
}:

let
  username = "joao";
  home = "/home/${username}";
  persistRoot = "/state";
  dataRoot = "/home/durable";

  enabledFeatures = [
    "agents.opencode"
    "security.age"
    "browser.firefox"
    "browser.google-chrome"
    "git.code"
    "git.projects"
    "editor.nvim"
    "kernel.graphical"
    "shell.nushell"
    "toolchain:rust"
  ];

  featureData = import ../modules/nixos/persist-features.nix;
  durableEntries = builtins.filter (e: e.durable or false) (
    lib.concatMap (id: featureData.features.${id} or [ ]) enabledFeatures
  );

  # Hermetic age identity + a fake app secret, so app-secrets provisioning
  # runs without touching the real encrypted stores.
  testSecrets = pkgs.runCommand "angst-test-secrets" { nativeBuildInputs = [ pkgs.age ]; } ''
    mkdir -p $out/secrets/apps/personal $out/identity
    age-keygen -o $out/identity/keys.txt 2>/dev/null
    chmod 600 $out/identity/keys.txt
    recipient=$(age-keygen -y $out/identity/keys.txt)
    printf 'test-opencode-go-key' | age -r "$recipient" -o $out/secrets/apps/personal/opencode-go-key.age
  '';

  # Reproduce the reinstall/systemd failure mode: the durable backing dirs and
  # the home mount-point parents exist but are owned by root.
  seedScript = pkgs.writeShellScript "angst-test-seed" ''
    set -eu
    ${lib.concatLines (
      map (
        e: "install -d -o root -g root -m 0755 ${lib.escapeShellArg "${dataRoot}/${e.name}"}"
      ) durableEntries
    )}
    install -d -o root -g root -m 0755 ${lib.escapeShellArg home}
    install -d -o root -g root -m 0755 ${lib.escapeShellArg "${home}/.config"}
    install -d -o root -g root -m 0755 ${lib.escapeShellArg "${home}/.config/age"}
    install -d -o root -g root -m 0755 ${lib.escapeShellArg "${home}/.local"}
    install -d -o root -g root -m 0755 ${lib.escapeShellArg "${home}/.local/share"}
    cp ${testSecrets}/identity/keys.txt ${dataRoot}/age/keys.txt
    cp ${testSecrets}/identity/keys.txt ${home}/.config/age/keys.txt
    chown ${username}:users ${dataRoot}/age/keys.txt ${home}/.config/age/keys.txt
    chmod 600 ${dataRoot}/age/keys.txt ${home}/.config/age/keys.txt
  '';

  durablePaths = map (e: "${dataRoot}/${e.name}") durableEntries;

  testScript = ''
    import shlex

    def owner(path):
        return machine.succeed(f"stat -c '%U' {shlex.quote(path)}").strip()

    def assert_owner(path, expected):
        actual = owner(path)
        assert actual == expected, f"{path} owned by {actual}, expected {expected}"

    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("home-manager-joao.service")

    # durable sources on the data partition must be repaired to joao
    for path in ${builtins.toJSON durablePaths}:
        machine.wait_until_succeeds(f"test -e {shlex.quote(path)}")
        assert_owner(path, "${username}")

    # bind-mount targets, their parents, and the rebuilt secrets must be joao
    for path in [
        "${home}/.config",
        "${home}/.config/age",
        "${home}/.config/git",
        "${home}/.cargo",
        "${home}/.mozilla",
        "${home}/.config/google-chrome",
        "${home}/.local/share/keyrings",
        "${home}/.local/share/nushell",
        "${home}/.local/share/opencode",
        "${home}/.local/state/opencode",
        "${home}/.local/share/nvim",
        "${home}/.local/state/nvim",
        "${home}/projects",
        "${home}/.secrets",
        "${home}/.secrets/opencode-go-key",
    ]:
        machine.wait_until_succeeds(f"test -e {shlex.quote(path)}")
        assert_owner(path, "${username}")

    # joao can actually read the secret and write the persisted dirs
    machine.succeed("runuser -u ${username} -- test -r ${home}/.secrets/opencode-go-key")
    machine.succeed("runuser -u ${username} -- test -w ${home}/.config")
    machine.succeed("runuser -u ${username} -- test -w ${home}/.config/age")
    machine.succeed("runuser -u ${username} -- test -w ${home}/.secrets")

    # system-level persistence on the impermanence root stays root-owned
    machine.wait_until_succeeds("test -e ${persistRoot}")
    assert_owner("${persistRoot}", "root")
  '';
in
pkgs.testers.runNixOSTest {
  name = "angst-persist-ownership";

  # The test declares requiredFeatures.kvm by default; force KVM so it errors
  # out on a runner without hardware acceleration instead of silently using TCG.
  qemu.forceAccel = true;
  globalTimeout = 30 * 60;

  nodes.machine = {
    imports = [
      self.inputs.impermanence.nixosModules.impermanence
      self.inputs.home-manager.nixosModules.home-manager
      (import ../modules/nixos/persist.nix {
        inherit lib enabledFeatures;
        inherit username;
        persist = {
          enable = true;
          root = persistRoot;
          inherit dataRoot;
          homeDirs = [ ];
          homeFiles = [ ];
        };
        homeDirectory = home;
      })
    ];

    users.users.${username} = {
      isNormalUser = true;
      uid = 1000;
      group = "users";
      inherit home;
      createHome = true;
    };

    systemd.services.angst-test-seed = {
      description = "angst: seed root-owned persisted state for the ownership test";
      wantedBy = [ "multi-user.target" ];
      after = [ "local-fs.target" ];
      before = [
        "angst-persist-ownership.service"
        "home-manager-joao.service"
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = seedScript;
      };
    };

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = "hm-backup";
      extraSpecialArgs = {
        flakeSelf = testSecrets;
        inherit runtime;
        hostScopes = [
          "personal"
          "work"
        ];
        hostSecrets = [ "opencode-go-key" ];
      };
      users.${username} = {
        imports = [ ../modules/home/app-secrets.nix ];
        home.stateVersion = "25.11";
      };
    };
  };

  inherit testScript;
}
