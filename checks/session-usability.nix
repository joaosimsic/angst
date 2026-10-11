{
  pkgs,
  lib,
  self,
  hostList,
}:

let
  excludedHomes = [
    "login-shell-valid"
    "login-shell-invalid"
  ];
  homeCfgs = builtins.removeAttrs self.homeConfigurations excludedHomes;
  homeNames = builtins.attrNames homeCfgs;

  hostsByName = lib.listToAttrs (
    map (h: {
      name = h.hostname;
      value = h;
    }) hostList
  );

  requiredFor =
    hostName:
    let
      h = hostsByName.${hostName} or { };
      agent = (h.sshAgent or { }).enable or false;
    in
    lib.unique (
      [
        "NIX_LD"
        "NIX_LD_LIBRARY_PATH"
      ]
      ++ lib.optional agent "SSH_AUTH_SOCK"
      ++ builtins.attrNames (h.env or { })
    );

  entryFile =
    name: entry:
    if (entry.source or null) != null then entry.source else pkgs.writeText name (entry.text or "");

  perHome =
    hostName: cfg:
    let
      res = builtins.tryEval (
        let
          c = cfg.config;
          merged = (c.home.sessionVariables or { }) // (c.systemd.user.sessionVariables or { });
          missing = lib.filter (k: !(builtins.hasAttr k merged)) (requiredFor hostName);
          req = map (k: "${k}=${if builtins.elem k missing then "MISSING" else "present"}") (
            requiredFor hostName
          );
        in
        builtins.deepSeq req {
          inherit req;
          envFile = entryFile "${hostName}-environment-d" (
            c.xdg.configFile."environment.d/10-home-manager.conf" or { }
          );
          varsFile = "${c.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh";
        }
      );
      drv = builtins.tryEval (builtins.unsafeDiscardStringContext cfg.activationPackage.drvPath);
    in
    {
      name = hostName;
      ok = res.success && drv.success;
      envFile = if res.success then res.value.envFile else "";
      varsFile = if res.success then res.value.varsFile else "";
      req = if res.success then res.value.req else [ ];
      drvPath = if drv.success then drv.value else "";
    };

  homeData = lib.mapAttrsToList perHome homeCfgs;

  filesManifest = pkgs.writeText "usability-files-manifest" (
    builtins.concatStringsSep "\n" (
      lib.concatMap (h: [
        "home\t${h.name}\tenv\t${h.envFile}"
        "home\t${h.name}\tvars\t${h.varsFile}"
      ]) homeData
    )
    + "\n"
  );

  reqManifest = pkgs.writeText "usability-req-manifest" (
    builtins.concatStringsSep "\n" (
      lib.concatMap (h: map (line: "home\t${h.name}\t${line}") h.req) homeData
    )
    + "\n"
  );

  drvManifest = pkgs.writeText "usability-drv-manifest" (
    builtins.concatStringsSep "\n" (
      map (h: "home\t${h.name}\t${if h.ok then "ok" else "FAIL"}") homeData
    )
    + "\n"
  );

  expectedCount = toString (builtins.length homeNames);

  poisonLib = pkgs.runCommand "poison-libc" { nativeBuildInputs = [ pkgs.stdenv.cc ]; } ''
    mkdir -p $out/lib
    cc -shared -x c /dev/null -o $out/lib/libc.so.6 -Wl,-soname,libc.so.6
  '';

  nixBus = "${pkgs.dbus}/bin";
  nixBin = "${pkgs.coreutils}/bin";
  nixLdd = "${pkgs.glibc.bin}/bin";
  nixBash = "${pkgs.bash}/bin/bash";
  nixBusConf = pkgs.writeText "session-test-bus.conf" ''
    <!DOCTYPE busconfig PUBLIC "-//freedesktop//DTD D-Bus Bus Configuration 1.0//EN" "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
    <busconfig>
      <listen>unix:tmpdir=/tmp</listen>
      <auth>EXTERNAL</auth>
      <allow_anonymous/>
    </busconfig>
  '';
in
pkgs.runCommand "check-session-usability"
  {
    nativeBuildInputs = [
      pkgs.bash
      pkgs.coreutils
      pkgs.gnugrep
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

    WORK="$TMPDIR/.usability-work"
    mkdir -p "$WORK/fakehome" "$WORK/fakert"

    with_session_env() {
      env -i PATH=${nixBus}:${nixBin}:${nixLdd}:/usr/bin:/bin HOME="$WORK/fakehome" XDG_RUNTIME_DIR="$WORK/fakert" TERM=xterm ${nixBash} -c '
        set -o pipefail
        envfile="$0"
        varsfile="$1"
        shift
        while IFS= read -r line; do
          case "$line" in
            ""|\#*) continue ;;
          esac
          k="''${line%%=*}"
          v="''${line#*=}"
          case "$k" in
            ""|*[!A-Za-z0-9_]* ) continue ;;
          esac
          export "$k=$v"
        done < "$envfile"
        . "$varsfile"
        exec "$@"
      ' "$1" "$2" "''${@:3}"
    }

    echo "==> Rendered session files carry no loader vars and boot a bus..."
    probed=0
    while IFS=$'\t' read -r -u 3 kind host slot path; do
      [ -z "$kind" ] && continue
      [ "$slot" = env ] && continue
      vf="$path"
      ef=""
      while IFS=$'\t' read -r -u 4 k2 h2 s2 p2; do
        if [ "$h2" = "$host" ] && [ "$s2" = env ]; then ef="$p2"; fi
      done 4< ${filesManifest}
      if [ -z "$ef" ] || [ ! -s "$ef" ]; then
        echo "INFO: home/$host has no rendered environment.d file, nothing to poison the bus"
        continue
      fi
      if [ ! -f "$vf" ]; then
        fail "home/$host missing rendered hm-session-vars.sh at $vf"
        continue
      fi
      if grep -Eq '^(LD_LIBRARY_PATH|LD_PRELOAD)(=|$)' "$ef" "$vf"; then
        fail "home/$host rendered session file sets a loader var"
        continue
      else
        ok "home/$host rendered session files set no loader var"
      fi
      probed=$((probed + 1))
      ldd_out=$(with_session_env "$ef" "$vf" ldd ${nixBus}/dbus-daemon 2>&1 < /dev/null) || true
      if printf '%s' "$ldd_out" | grep -q "not found"; then
        fail "home/$host dbus-daemon misses libs under generated env: $(printf '%s' "$ldd_out" | grep "not found" | head -n 3 | tr '\n' ';')"
      else
        ok "home/$host dbus-daemon resolves all libs under generated env"
      fi
      bus_err=$(with_session_env "$ef" "$vf" ${nixBus}/dbus-run-session --config-file=${nixBusConf} -- ${nixBin}/true 2>&1 < /dev/null)
      bus_status=$?
      if [ "$bus_status" -eq 0 ]; then
        ok "home/$host session bus starts under generated env"
      else
        fail "home/$host session bus fails to start under generated env: $bus_err"
      fi
    done 3< ${filesManifest}
    if [ "$probed" -eq 0 ]; then
      fail "no host session replayed, probe evaluated nothing"
    fi
    if [ "$probed" -ne ${expectedCount} ]; then
      fail "replayed $probed hosts, expected ${expectedCount}"
    fi
    ok "replayed $probed host sessions"

    echo "==> Negative control, foreign libc in LD must break the same probes..."
    poison_out=$(env -i PATH=${nixBus}:${nixBin}:${nixLdd} LD_LIBRARY_PATH=${poisonLib}/lib ldd ${nixBus}/dbus-daemon 2>&1) || true
    if printf '%s' "$poison_out" | grep -q "${poisonLib}"; then
      ok "control ldd resolves poison libc under poisoned env"
    else
      fail "control blind, poison libc not picked up: $(printf '%s' "$poison_out" | head -n 3 | tr '\n' ';')"
    fi
    if env -i PATH=${nixBus}:${nixBin} HOME="$WORK/fakehome" XDG_RUNTIME_DIR="$WORK/fakert" TERM=xterm LD_LIBRARY_PATH=${poisonLib}/lib ${nixBus}/dbus-run-session --config-file=${nixBusConf} -- ${nixBin}/true >/dev/null 2>&1 < /dev/null; then
      fail "control blind, session bus starts despite foreign libc in LD"
    else
      ok "control session bus breaks under foreign libc in LD"
    fi

    echo "==> Required session vars present (home)..."
    while IFS=$'\t' read -r kind host kv; do
      [ -z "$kind" ] && continue
      k="''${kv%%=*}"
      v="''${kv#*=}"
      if [ "$v" = MISSING ]; then
        fail "home/$host missing essential session var $k"
      else
        ok "home/$host has $k"
      fi
    done < ${reqManifest}

    echo "==> Configs evaluate (home)..."
    while IFS=$'\t' read -r kind host status; do
      [ -z "$kind" ] && continue
      if [ "$status" = ok ]; then
        ok "home/$host evaluates"
      else
        fail "home/$host FAILED to evaluate"
      fi
    done < ${drvManifest}

    [ "$failed" -eq 0 ]
    touch $out
  ''
