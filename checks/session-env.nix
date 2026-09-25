{
  pkgs,
  lib,
  self,
}:

let
  excludedHomes = [
    "login-shell-valid"
    "login-shell-invalid"
  ];
  homeCfgs = builtins.removeAttrs self.homeConfigurations excludedHomes;
  systemCfgs = self.nixosConfigurations or { };

  renderEnv = env: lib.mapAttrsToList (n: v: "${n}=${toString v}") env;

  isLoaderEntry =
    e:
    e == "LD_LIBRARY_PATH"
    || e == "LD_PRELOAD"
    || lib.hasPrefix "LD_LIBRARY_PATH=" e
    || lib.hasPrefix "LD_PRELOAD=" e;

  # Home-manager user services: ban all loader vars (no nixpkgs defaults
  # here; every entry is angst/HM-controlled).
  hmSvcRows =
    prefix: services:
    lib.concatMap (
      sName:
      let
        s = services.${sName};
        hm = s.Service or { };
        entries = map toString ((hm.Environment or [ ]) ++ (hm.PassEnvironment or [ ]));
      in
      map (e: "${prefix}/${sName}\t${e}") entries
    ) (builtins.attrNames services);

  homeEntry =
    hostName: cfg:
    let
      res = builtins.tryEval (
        let
          c = cfg.config;
          v = {
            globalEnv =
              renderEnv (c.home.sessionVariables or { }) ++ renderEnv (c.systemd.user.sessionVariables or { });
            services = hmSvcRows "user" (c.systemd.user.services or { });
          };
        in
        builtins.deepSeq v v
      );
      drv = builtins.tryEval (builtins.unsafeDiscardStringContext cfg.activationPackage.drvPath);
    in
    {
      name = hostName;
      ok = res.success && drv.success;
      globalEnv = if res.success then res.value.globalEnv else [ ];
      services = if res.success then res.value.services else [ ];
      drvPath = if drv.success then drv.value else "";
    };

  systemEntry =
    hostName: cfg:
    let
      res = builtins.tryEval (
        let
          c = cfg.config;
          hmUsers = c.home-manager.users or { };
          # Stock nixpkgs NSS wiring (e.g. dbus-broker, nscd, sshd):
          # LD_LIBRARY_PATH is exactly the NSS module path. Safe on NixOS
          # (all Nix-built) -> exempt. Anything else loader-related fails.
          nssPath = toString (c.system.nssModules.path or "");
          isNssDefault = e: e == "LD_LIBRARY_PATH=${nssPath}";
          sysSvc = map (
            sName:
            let
              s = c.systemd.services.${sName};
              entries =
                renderEnv (s.environment or { }) ++ map toString ((s.serviceConfig or { }).Environment or [ ]);
              bad = lib.filter (e: isLoaderEntry e && !(isNssDefault e)) entries;
              exempt = lib.length (lib.filter isNssDefault entries);
            in
            {
              rows = map (e: "system/${sName}\t${e}") bad;
              exemptNss = exempt;
            }
          ) (builtins.attrNames (c.systemd.services or { }));
          v = {
            globalEnv =
              renderEnv (c.environment.sessionVariables or { }) ++ renderEnv (c.environment.variables or { });
            userServices = lib.concatMap (
              sName:
              let
                s = c.systemd.user.services.${sName};
                scfg = s.serviceConfig or { };
                entries = renderEnv (s.environment or { }) ++ map toString (scfg.Environment or [ ]);
              in
              map (e: "user/${sName}\t${e}") entries
            ) (builtins.attrNames (c.systemd.user.services or { }));
            systemServices = lib.concatMap (x: x.rows) sysSvc;
            exemptNss = lib.foldl' (acc: x: acc + x.exemptNss) 0 sysSvc;
            hmEnv = lib.concatMap (
              uName:
              let
                u = hmUsers.${uName};
              in
              map (line: "${uName}\t${line}") (
                renderEnv (u.home.sessionVariables or { }) ++ renderEnv (u.systemd.user.sessionVariables or { })
              )
            ) (builtins.attrNames hmUsers);
          };
        in
        builtins.deepSeq v v
      );
      drv = builtins.tryEval (
        builtins.unsafeDiscardStringContext cfg.config.system.build.toplevel.drvPath
      );
    in
    {
      name = hostName;
      ok = res.success && drv.success;
      globalEnv = if res.success then res.value.globalEnv else [ ];
      userServices = if res.success then res.value.userServices else [ ];
      systemServices = if res.success then res.value.systemServices else [ ];
      exemptNss = if res.success then res.value.exemptNss else 0;
      hmEnv = if res.success then res.value.hmEnv else [ ];
      drvPath = if drv.success then drv.value else "";
    };

  homeData = lib.mapAttrsToList homeEntry homeCfgs;
  systemData = lib.mapAttrsToList systemEntry systemCfgs;

  envRows =
    lib.concatMap (h: map (line: "home\t${h.name}\t${line}") h.globalEnv) homeData
    ++ lib.concatMap (h: map (line: "system\t${h.name}\t${line}") h.globalEnv) systemData
    ++ lib.concatMap (h: map (line: "nixos-hm\t${h.name}\t${line}") h.hmEnv) systemData;

  svcRows =
    lib.concatMap (h: map (line: "home-svc\t${h.name}\t${line}") h.services) homeData
    ++ lib.concatMap (h: map (line: "sys-user-svc\t${h.name}\t${line}") h.userServices) systemData
    ++ lib.concatMap (h: map (line: "sys-svc\t${h.name}\t${line}") h.systemServices) systemData;

  infoRows = lib.concatMap (h: [
    "system\t${h.name}\texempt-nss-system-svc=${toString h.exemptNss}"
  ]) systemData;

  drvRows =
    map (h: "home\t${h.name}\t${if h.ok then "ok" else "FAIL"}") homeData
    ++ map (h: "system\t${h.name}\t${if h.ok then "ok" else "FAIL"}") systemData;

  envManifest = pkgs.writeText "session-env-manifest" (builtins.concatStringsSep "\n" envRows);
  svcManifest = pkgs.writeText "session-svc-manifest" (builtins.concatStringsSep "\n" svcRows);
  infoManifest = pkgs.writeText "session-info-manifest" (builtins.concatStringsSep "\n" infoRows);
  drvManifest = pkgs.writeText "session-drv-manifest" (builtins.concatStringsSep "\n" drvRows);
in
pkgs.runCommand "check-session-env"
  {
    nativeBuildInputs = [
      pkgs.gnugrep
      pkgs.coreutils
    ];
  }
  ''
    set -uo pipefail
    cd ${self}

    ok() { echo "PASS: $1"; }
    fail() {
      echo "FAIL: $1"
      failed=1
    }
    failed=0

    echo "==> Checking global session env has no loader vars (home + nixos)..."
    count=0
    while IFS=$'\t' read -r kind host kv; do
      [ -z "$kind" ] && continue
      count=$((count + 1))
      k="''${kv%%=*}"
      v="''${kv#*=}"
      case "$k" in
        LD_LIBRARY_PATH | LD_PRELOAD)
          fail "$kind/$host sets global $k (must stay shell-local; breaks dbus -> login loop): ''${v:0:120}"
          ;;
      esac
      case "$v" in
        *libsystemd* | *GLIBC_ABI*)
          fail "$kind/$host global $k pulls loader-shadow libs: ''${v:0:120}"
          ;;
      esac
    done < ${envManifest}
    [ "$count" -gt 0 ] || echo "No global session env entries; nothing to check."
    ok "global session env clean ($count entries)"

    echo "==> Checking systemd services leak no loader vars (home + nixos)..."
    echo "    (stock nixpkgs NSS wiring on NixOS system services is exempt)"
    count=0
    while IFS=$'\t' read -r kind host svc entry; do
      [ -z "$kind" ] && continue
      count=$((count + 1))
      case "$entry" in
        LD_LIBRARY_PATH | LD_PRELOAD | LD_LIBRARY_PATH=* | LD_PRELOAD=*)
          fail "$kind/$host service $svc leaks loader var via Environment/PassEnvironment: ''${entry:0:160}"
          ;;
      esac
    done < ${svcManifest}
    [ "$count" -gt 0 ] || echo "No systemd service env entries; nothing to check."
    while IFS=$'\t' read -r kind host info; do
      [ -z "$kind" ] && continue
      echo "INFO: $kind/$host $info (nixpkgs default, safe on NixOS)"
    done < ${infoManifest}
    ok "systemd service env clean ($count entries)"

    echo "==> Checking every config evaluates (pure-eval gate, home + nixos)..."
    count=0
    while IFS=$'\t' read -r kind host status; do
      [ -z "$kind" ] && continue
      count=$((count + 1))
      if [ "$status" = ok ]; then
        ok "$kind/$host evaluates"
      else
        fail "$kind/$host FAILED to evaluate (e.g. fetchurl without sha256 blocks switch)"
      fi
    done < ${drvManifest}
    [ "$count" -gt 0 ] || echo "No configurations; nothing to check."

    echo "==> Checking nixGL nvidiaHash is pinned..."
    if grep -q 'nvidiaHash = null' domains/display/gpu/home.nix; then
      fail "domains/display/gpu/home.nix has nvidiaHash = null (pure eval fetchurl fails, switch blocked)"
    elif grep -Eq 'nvidiaHash = "[A-Za-z0-9+/=_-]{32,}"' domains/display/gpu/home.nix; then
      ok "nixGL nvidiaHash pinned"
    else
      fail "domains/display/gpu/home.nix nvidiaHash is not a pinned hash"
    fi

    [ "$failed" -eq 0 ]
    touch $out
  ''
