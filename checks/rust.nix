{ pkgs, lib, hostList, ... }:

let
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
  allPkgs = if representative != null then representative.scan.allToolchainPackages else [ ];
  findBy = pat: lib.findFirst (p: builtins.match pat (p.name or "") != null) null allPkgs;
  nightlyTc = findBy "rust-nightly-with-components.*";
  stableWrap = findBy "rust-stable-.*-wrappers";
in
pkgs.runCommand "check-rust"
  {
    nativeBuildInputs = [
      pkgs.bash
      pkgs.stdenv.cc
    ];
  }
  ''
    set -euo pipefail
    ${lib.optionalString (nightlyTc == null) ''
      echo "FAIL: nightly toolchain missing from representative host packages"
      exit 1
    ''}
    ${lib.optionalString (stableWrap == null) ''
      echo "FAIL: stable wrappers missing from representative host packages"
      exit 1
    ''}
    NIGHTLY=${if nightlyTc == null then "/nonexistent" else "${nightlyTc}"}
    WRAP=${if stableWrap == null then "/nonexistent" else "${stableWrap}"}
    echo "==> nightly versions"
    "$NIGHTLY/bin/rustc" --version | tee /tmp/rustc-nightly-version
    grep -q "nightly" /tmp/rustc-nightly-version
    "$NIGHTLY/bin/cargo" --version | tee /tmp/cargo-nightly-version
    grep -q "nightly" /tmp/cargo-nightly-version
    "$NIGHTLY/bin/rust-analyzer" --version
    echo "==> cranelift backend present"
    ls "$NIGHTLY/lib/rustlib/x86_64-unknown-linux-gnu/codegen-backends/" | tee /tmp/backends
    grep -q "cranelift" /tmp/backends
    echo "==> stable wrappers versions"
    "$WRAP/bin/rustc-stable" --version | tee /tmp/rustc-stable-version
    grep -q "1.95.0" /tmp/rustc-stable-version
    "$WRAP/bin/cargo-stable" --version | tee /tmp/cargo-stable-version
    grep -q "1.95.0" /tmp/cargo-stable-version
    echo "==> stable sysroot resolves"
    SYSROOT=$("$WRAP/bin/rustc-stable" --print sysroot)
    echo "$SYSROOT"
    test -d "$SYSROOT/lib/rustlib/x86_64-unknown-linux-gnu/lib"
    ls "$SYSROOT/lib/rustlib/x86_64-unknown-linux-gnu/lib/" | grep -q "libstd"
    echo "==> stable rustc hello world"
    WORK=$(mktemp -d)
    cat > "$WORK/hello.rs" <<'EOF'
    fn main() { println!("hello-stable"); }
    EOF
    "$WRAP/bin/rustc-stable" "$WORK/hello.rs" -o "$WORK/hello-stable"
    "$WORK/hello-stable" | grep -q "hello-stable"
    echo "==> nightly rustc hello world"
    cat > "$WORK/hi.rs" <<'EOF'
    fn main() { println!("hello-nightly"); }
    EOF
    "$NIGHTLY/bin/rustc" "$WORK/hi.rs" -o "$WORK/hello-nightly"
    "$WORK/hello-nightly" | grep -q "hello-nightly"
    echo "==> stable cargo hello world"
    mkdir -p "$WORK/cargostable/src"
    cat > "$WORK/cargostable/Cargo.toml" <<'EOF'
    [package]
    name = "cargostable"
    version = "0.1.0"
    edition = "2021"
    EOF
    cat > "$WORK/cargostable/src/main.rs" <<'EOF'
    fn main() { println!("cargo-stable-ok"); }
    EOF
    (cd "$WORK/cargostable" && "$WRAP/bin/cargo-stable" build --offline)
    "$WORK/cargostable/target/debug/cargostable" | grep -q "cargo-stable-ok"
    echo "=== All rust checks passed ==="
    touch $out
  ''
