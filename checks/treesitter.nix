{
  pkgs,
  lib,
  hostList,
}:

let
  vmHost = lib.findFirst (h: h.hostname == "vm") null hostList;
  nixosHosts = lib.filter (h: h.type == "nixos") hostList;
  representative =
    let
      preferred = lib.findFirst (h: h.hostname == "nixos") null nixosHosts;
    in
    if preferred != null then
      preferred
    else if nixosHosts != [ ] then
      builtins.head nixosHosts
    else if hostList != [ ] then
      builtins.head hostList
    else
      null;

  grammarsFor =
    host: lib.unique (lib.concatMap (t: t.toolchains.treesitterGrammars or [ ]) host.toolchainModules);
  soFor =
    grammar: lib.replaceStrings [ "-" ] [ "_" ] (lib.removePrefix "tree-sitter-" grammar.pname) + ".so";

  hostChecks = lib.concatMapStrings (
    host:
    let
      parsers = host.scan.treesitter.treesitterParsers;
      grammars = grammarsFor host;
      expectedSos = map soFor grammars;
    in
    ''
      echo "--- Checking host ${host.hostname} (${toString (builtins.length grammars)} grammars) at ${parsers} ---"
      ${lib.concatMapStrings (so: ''
        if [ ! -f "${parsers}/${so}" ]; then
          echo "FAIL: ${host.hostname} missing parser ${so} in ${parsers}"
          echo "Available:"
          ls -1 "${parsers}" || true
          exit 1
        fi
      '') expectedSos}
      echo "PASS: ${host.hostname} all ${toString (builtins.length grammars)} parsers present"
    ''
  ) hostList;

  devShellChecks =
    let
      vmParsers = if vmHost != null then vmHost.scan.treesitter.treesitterParsers else null;
      devParsers =
        if representative != null then representative.scan.treesitter.treesitterParsers else null;
    in
    lib.optionalString (vmParsers != null) ''
      echo "--- Checking devShell vm parsers at ${vmParsers} ---"
      if [ ! -f "${vmParsers}/haskell.so" ]; then
        echo "FAIL: devShell vm missing haskell.so (would clobber host haskell parser with ci minimal set)"
        ls -1 "${vmParsers}" || true
        exit 1
      fi
      echo "PASS: devShell vm has haskell.so"
    ''
    + lib.optionalString (devParsers != null) ''
      echo "--- Checking devShell dev parsers at ${devParsers} ---"
      if [ ! -f "${devParsers}/haskell.so" ]; then
        echo "FAIL: devShell dev missing haskell.so"
        ls -1 "${devParsers}" || true
        exit 1
      fi
      echo "PASS: devShell dev has haskell.so"
    '';

  extraChecks = lib.optionalString (vmHost != null && representative != null) ''
    echo "--- Cross-check vm vs ci minimal distinction ---"
    vmCount=$(ls -1 "${vmHost.scan.treesitter.treesitterParsers}" | wc -l)
    devCount=$(ls -1 "${representative.scan.treesitter.treesitterParsers}" | wc -l)
    echo "vm parsers count: $vmCount, representative parsers count: $devCount"
    if [ "$vmCount" -lt 10 ]; then
      echo "FAIL: vm parsers suspiciously minimal ($vmCount), expected full toolchain set"
      ls -1 "${vmHost.scan.treesitter.treesitterParsers}" || true
      exit 1
    fi
  '';

in
pkgs.runCommand "check-treesitter" { } ''
  echo "=== Treesitter parser presence check ==="
  ${hostChecks}
  ${devShellChecks}
  ${extraChecks}
  echo "=== All treesitter checks passed ==="
  touch $out
''
