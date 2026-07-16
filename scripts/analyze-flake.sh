#!/usr/bin/env bash
# Diagnostic script — no set -e because rg/grep return 1 on no-match
set -u

# ─────────────────────────────────────────────
# angst flake analysis
# Usage: bash scripts/analyze-flake.sh
# ─────────────────────────────────────────────

# Auto-detect TTY — strip ANSI codes when redirecting to file
if [ -t 1 ]; then
  BOLD="\033[1m"; CYAN="\033[36m"; GREEN="\033[32m"; YELLOW="\033[33m"
  RED="\033[31m"; MAGENTA="\033[35m"; DIM="\033[2m"; RESET="\033[0m"
else
  BOLD=""; CYAN=""; GREEN=""; YELLOW=""; RED=""; MAGENTA=""; DIM=""; RESET=""
  export NO_COLOR=1  # tells tools like statix to suppress their own ANSI codes
fi

header() {
  printf "\n${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${RESET}\n"
  printf "${BOLD}${CYAN}  %s${RESET}\n" "$1"
  printf "${CYAN}═══════════════════════════════════════════════════════════════${RESET}\n"
}

subheader() {
  printf "\n${BOLD}${YELLOW}  %s${RESET}\n" "$1"
}

label() {
  printf "${DIM}%s${RESET} ${BOLD}%s${RESET}\n" "$1" "$2"
}

warn() {
  printf "${YELLOW}  ⚠  %s${RESET}\n" "$1"
}

ok() {
  printf "${GREEN}  ✓  %s${RESET}\n" "$1"
}

dim() {
  printf "${DIM}%s${RESET}\n" "$1"
}

print_table() {
  while IFS= read -r line; do
    printf "  %s\n" "$line"
  done
}

cd "$(git rev-parse --show-toplevel 2>/dev/null || echo .)"

total_nix=$(find . -name '*.nix' -not -path './.git/*' -not -path './result/*' | wc -l)
total_nix_loc=$(find . -name '*.nix' -not -path './.git/*' -not -path './result/*' -exec cat {} + | wc -l)
total_rust_loc=$(find tools -name '*.rs' -exec cat {} + 2>/dev/null | wc -l)
total_sh_loc=$(find scripts -name '*.sh' -exec cat {} + 2>/dev/null | wc -l)
total_md_loc=$(find openwiki -name '*.md' -exec cat {} + 2>/dev/null | wc -l)

printf "${BOLD}${CYAN}"
printf "╔══════════════════════════════════════════════════════════════╗\n"
printf "║              angst flake analysis                           ║\n"
printf "║              %-42s║\n" "$(date '+%Y-%m-%d %H:%M')"
printf "╚══════════════════════════════════════════════════════════════╝${RESET}\n"

# ─── 1. OVERVIEW ────────────────────────────
header "1. OVERVIEW"
printf "  ${BOLD}Files${RESET}          ${total_nix} .nix files, ${total_nix_loc} LOC\n"
printf "  ${BOLD}Rust${RESET}           ${total_rust_loc} LOC (tools/vm + tools/shell)\n"
printf "  ${BOLD}Scripts${RESET}        ${total_sh_loc} LOC (bash)\n"
printf "  ${BOLD}Docs${RESET}           ${total_md_loc} LOC (openwiki)\n"

nix_flake_check=$(nix flake check 2>&1 | tail -1 || echo "failed")
if echo "$nix_flake_check" | grep -q "all checks passed"; then
  ok "flake check: passed"
else
  warn "flake check: $nix_flake_check"
fi

# ─── 2. FILE SIZE HEATMAP ───────────────────
header "2. FILE SIZE HEATMAP (top 30)"
printf "  ${DIM}%4s  %-50s %s${RESET}\n" "LOC" "File" "Section"
find . -name '*.nix' -not -path './.git/*' -not -path './result/*' \
  -not -path './tools/vm/*' -not -path './tools/shell/*' \
  -exec wc -l {} + 2>/dev/null \
  | sort -rn | head -31 | while IFS= read -r line; do
  loc=$(echo "$line" | awk '{print $1}')
  file=$(echo "$line" | awk '{$1=""; print $0}' | sed 's/^ *//')
  [ "$file" = "total" ] && continue
  # Determine section from path
  section=$(echo "$file" | sed -n 's|^\./\([^/]*\)/.*|\1|p')
  [ -z "$section" ] && section="root"
  if [ "$loc" -gt 200 ]; then
    printf "  ${RED}%4d${RESET}  %-50s ${DIM}%s${RESET}\n" "$loc" "$file" "$section"
  elif [ "$loc" -gt 100 ]; then
    printf "  ${YELLOW}%4d${RESET}  %-50s ${DIM}%s${RESET}\n" "$loc" "$file" "$section"
  else
    printf "  ${GREEN}%4d${RESET}  %-50s ${DIM}%s${RESET}\n" "$loc" "$file" "$section"
  fi
done

# ─── 3. DIRECTORY SIZE BREAKDOWN ────────────
header "3. DIRECTORY SIZE BREAKDOWN"
for dir in lib domains toolchains themes capabilities hosts common scripts; do
  if [ -d "$dir" ]; then
    count=$(find "$dir" -name '*.nix' -not -path './.git/*' | wc -l)
    loc=$(find "$dir" -name '*.nix' -not -path './.git/*' -exec cat {} + | wc -l)
    # also count Rust in tools dirs
    rust_count=0
    rust_loc=0
    if [ "$dir" = "tools" ]; then
      rust_count=$(find tools -name '*.rs' | wc -l)
      rust_loc=$(find tools -name '*.rs' -exec cat {} + | wc -l)
    fi
    printf "  ${BOLD}%-20s${RESET} %3d .nix files, %4d LOC" "$dir/" "$count" "$loc"
    if [ "$rust_count" -gt 0 ]; then
      printf " ${DIM}(+ %d .rs files, %d LOC)${RESET}" "$rust_count" "$rust_loc"
    fi
    printf "\n"
  fi
done

# Subflake breakdown
printf "  ${BOLD}%-20s${RESET} " "tools/vm/ (subflake)"
vm_nix=$(find tools/vm -name '*.nix' -exec cat {} + 2>/dev/null | wc -l)
vm_rs=$(find tools/vm -name '*.rs' -exec cat {} + 2>/dev/null | wc -l)
printf "(%d nix LOC + %d rs LOC)" "$vm_nix" "$vm_rs"
printf "\n"
printf "  ${BOLD}%-20s${RESET} " "tools/shell/ (subflake)"
sh_nix=$(find tools/shell -name '*.nix' -exec cat {} + 2>/dev/null | wc -l)
sh_rs=$(find tools/shell -name '*.rs' -exec cat {} + 2>/dev/null | wc -l)
printf "(%d nix LOC + %d rs LOC)" "$sh_nix" "$sh_rs"
printf "\n"

# ─── 4. FLAKE OUTPUT SURFACE ────────────────
header "4. FLAKE OUTPUT SURFACE"
printf "\n"
for pair in "packages:  packages.x86_64-linux" "devShells: devShells.x86_64-linux" "apps:      apps.x86_64-linux" "checks:    checks.x86_64-linux" "nixosConfig: nixosConfigurations" "homeConfig:  homeConfigurations"; do
  label=$(echo "$pair" | awk '{print $1}')
  attr=$(echo "$pair" | awk '{print $2}')
  printf "  ${BOLD}%s${RESET}\n" "$label"
  result=$(nix eval ".#$attr" --apply "builtins.attrNames" 2>/dev/null) || {
    warn "could not eval .#$attr"
    continue
  }
  echo "$result" | sed 's/\[//g; s/\]//g; s/"//g' | tr -s ' ' '\n' | sed '/^$/d' | sed 's/^/    /'
  printf "\n"
done

# ─── 5. DUPLICATION HOTSPOTS ────────────────
header "5. DUPLICATION HOTSPOTS"

subheader "userEnv parsing (same pattern in N files)"
# Files that re-implement the userEnv lookup chain (builds.pathExists user.env + parseEnv)
for f in $(rg -l 'parseEnv\.nix|userEnv\s*=|builtins\.pathExists.*user\.env' --type nix 2>/dev/null); do
  # Skip unrelated parseEnv references (e.g. in test files)
  if rg -q 'envPath\s*=|userEnv\s*=' "$f" 2>/dev/null; then
    warn "$f"
  fi
done

subheader '"x86_64-linux" hardcoded'
rg -l 'x86_64-linux' --type nix 2>/dev/null | while IFS= read -r f; do
  printf "  ${DIM}%s${RESET}\n" "$f"
done

subheader '"proj/angst" hardcoded'
rg -l 'proj/angst' --type nix 2>/dev/null | while IFS= read -r f; do
  printf "  ${DIM}%s${RESET}\n" "$f"
done

subheader '"allowUnfree" hardcoded'
rg -l 'allowUnfree' --type nix 2>/dev/null | while IFS= read -r f; do
  printf "  ${DIM}%s${RESET}\n" "$f"
done

# ─── 6. HARDCODED STRINGS TABLE ─────────────
header "6. HARDCODED STRINGS INVENTORY"
count_string() {
  local s="$1" desc="$2"
  count=$(rg -cF "$s" --type nix 2>/dev/null | awk -F: '{sum+=$2} END {print sum+0}')
  files=$(rg -lF "$s" --type nix 2>/dev/null | wc -l)
  printf "  ${BOLD}%-20s${RESET} %4d×  in %2d files  ${DIM}%s${RESET}\n" "\"$s\"" "$count" "$files" "$desc"
}
printf "\n"
count_string "angst"       "project name"
count_string "ANGST"       "env var prefix"
count_string "nixpkgs"     "flake input"
count_string "home-manager"   "flake input"
count_string "proj/angst"     "repo path"
count_string "x86_64"        "architecture"
count_string "allowUnfree"   "nixpkgs config"
count_string "generic"       "default host"
count_string "monochrome"    "default theme"
count_string "NIX_"          "nix env vars"
count_string "ANGST_"        "angst env vars"

# ─── 7. IMPORT/DEPENDENCY GRAPH ─────────────
header "7. IMPORT/DEPENDENCY GRAPH"

subheader "flake.nix imports"
rg '^[a-zA-Z].*import ' flake.nix 2>/dev/null | while IFS= read -r line; do
  printf "  %s\n" "$line"
done

subheader "lib/flake/default.nix imports"
rg 'import ' lib/flake/default.nix 2>/dev/null | while IFS= read -r line; do
  printf "  %s\n" "$line"
done

subheader "Key re-imports (suggests dedup candidates)"
for pattern in 'parseEnv' 'domains/default' 'themes/default' 'shared.nix'; do
  count=$(rg -l "$pattern" --type nix 2>/dev/null | wc -l)
  if [ "$count" -gt 1 ]; then
    printf "  ${YELLOW}$pattern${RESET}: ${count} files import it\n"
    rg -l "$pattern" --type nix 2>/dev/null | sed 's/^/    /'
  fi
done

# ─── 8. DOMAIN INVENTORY ────────────────────
header "8. DOMAIN INVENTORY"
printf "  ${DIM}%-22s %-22s render module nixos  size${RESET}\n" "Category" "Domain"
for catdir in domains/*/; do
  catname=$(basename "$catdir")
  for domdir in "$catdir"*/; do
    [ -d "$domdir" ] || continue
    domname=$(basename "$domdir")
    has_render=$([ -f "${domdir}render.nix"  ] && echo "✓    " || echo "—    ")
    has_module=$([ -f "${domdir}module.nix"  ] && echo "✓    " || echo "—    ")
    has_nixos=$([ -f "${domdir}nixos.nix"    ] && echo "✓    " || echo "—    ")
    dom_loc=$(find "$domdir" -name '*.nix' -exec cat {} + 2>/dev/null | wc -l)
    printf "  ${BOLD}%-20s${RESET} %-22s %s %s %s ${DIM}%d LOC${RESET}\n" \
      "$catname" "$domname" "$has_render" "$has_module" "$has_nixos" "$dom_loc"
  done
done

# ─── 9. THEME INVENTORY ─────────────────────
header "9. THEME INVENTORY"
if [ -d themes ]; then
  for f in themes/*.nix; do
    name=$(basename "$f" .nix)
    [ "$name" = "default" ] || [ "$name" = "schema" ] && continue
    loc=$(wc -l < "$f")
    default_mark=""
    [ "$name" = "monochrome" ] && default_mark=" ${DIM}(default)${RESET}"
    printf "  ${BOLD}%-20s${RESET} %3d LOC%s\n" "$name" "$loc" "$default_mark"
  done
fi

# ─── 10. CAPABILITIES INVENTORY ─────────────
header "10. CAPABILITIES INVENTORY"
if [ -d capabilities ]; then
  for f in capabilities/*.nix; do
    name=$(basename "$f" .nix)
    [ "$name" = "default" ] && continue
    loc=$(wc -l < "$f")
    printf "  ${BOLD}%-20s${RESET} %3d LOC\n" "$name" "$loc"
  done
fi

# ─── 11. TOOLCHAIN INVENTORY ────────────────
header "11. TOOLCHAIN INVENTORY"
if [ -d toolchains ]; then
  for f in toolchains/*.nix; do
    name=$(basename "$f" .nix)
    [ "$name" = "default" ] && continue
    loc=$(wc -l < "$f")
    # get package names from each toolchain
    pkgs=$(rg 'runtime.*\[|lsp.*\[|formatter.*\[' "$f" 2>/dev/null | head -3 | sed 's/.*\[\(.*\)\].*/\1/' | head -1)
    printf "  ${BOLD}%-20s${RESET} %3d LOC\n" "$name" "$loc"
  done
fi

# ─── 12. HOST INVENTORY ─────────────────────
header "12. HOST INVENTORY"
for hostdir in hosts/*/; do
  hostname=$(basename "$hostdir")
  printf "  ${BOLD}%s/${RESET}\n" "$hostname"
  for f in "$hostdir"*.nix; do
    loc=$(wc -l < "$f")
    printf "    ├─ %-30s %3d LOC\n" "$(basename "$f")" "$loc"
  done
done

# ─── 13. DEAD CODE ──────────────────────────
header "13. DEAD CODE"
if command -v deadnix &>/dev/null; then
  deadnix . --quiet --no-lambda-pattern-names 2>/dev/null | sed 's/\x1b\[[0-9;]*[a-zA-Z]//g' || true
else
  warn "deadnix not found"
fi

# ─── 14. ANTI-PATTERNS ──────────────────────
header "14. ANTI-PATTERNS (statix)"
if command -v statix &>/dev/null; then
  statix check . 2>/dev/null | sed 's/\x1b\[[0-9;]*[a-zA-Z]//g' || true
else
  warn "statix not found"
fi

# ─── 15. CONDITIONAL LOGIC ───────────────────
header "15. CONDITIONAL LOGIC USAGE"
for pat in mkIf mkDefault mkForce mkOption mkEnableOption; do
  count=$(rg -lF "$pat" --type nix 2>/dev/null | wc -l)
  total=$(rg -cF "$pat" --type nix 2>/dev/null | awk -F: '{sum+=$2} END {print sum+0}')
  printf "  ${BOLD}%-20s${RESET} %4d×  in %2d files\n" "$pat" "${total:-0}" "$count"
done

# ─── 16. BUILTINS USAGE ─────────────────────
header "16. BUILTINS USAGE FREQUENCY"
rg -o --no-filename 'builtins\.\w+' --type nix 2>/dev/null | sort | uniq -c | sort -rn | head -20 \
  | while IFS= read -r line; do
    count=$(echo "$line" | awk '{print $1}')
    name=$(echo "$line" | awk '{print $2}')
    printf "  ${BOLD}%-20s${RESET} %4d×\n" "$name" "$count"
  done

# ─── 17. SPECIAL ARGS ───────────────────────
header "17. SPECIAL ARGS (module interface)"

subheader "extraSpecialArgs (mkHome.nix -> home-manager)"
rg 'extraSpecialArgs =' -A 15 lib/build/mkHome.nix 2>/dev/null \
  | rg '[a-zA-Z]' | sed 's/^/  /'

subheader "specialArgs (mkHost.nix -> NixOS)"
rg 'specialArgs =' -A 15 lib/build/mkHost.nix 2>/dev/null \
  | rg '[a-zA-Z]' | sed 's/^/  /'

# ─── 18. ERROR HANDLING ─────────────────────
header "18. ERROR HANDLING"
throw_count=$(rg -c 'builtins\.throw|throw ' --type nix 2>/dev/null | awk -F: '{sum+=$2} END {print sum+0}')
abort_count=$(rg -c 'builtins\.abort|abort ' --type nix 2>/dev/null | awk -F: '{sum+=$2} END {print sum+0}')
assert_count=$(rg -c '\bassert ' --type nix 2>/dev/null | awk -F: '{sum+=$2} END {print sum+0}')
printf "  ${BOLD}%-15s${RESET} %4d×\n" "throw"  "${throw_count:-0}"
printf "  ${BOLD}%-15s${RESET} %4d×\n" "abort"  "${abort_count:-0}"
printf "  ${BOLD}%-15s${RESET} %4d×\n" "assert" "${assert_count:-0}"
printf "\n"
subheader "throw locations"
rg -n 'throw "' --type nix 2>/dev/null | head -15 | sed 's/^/  /'

# ─── 19. COMPLEXITY METRICS ─────────────────
header "19. COMPLEXITY METRICS"

subheader "Deep let-in nesting (depth >= 3)"
for f in $(find . -name '*.nix' -not -path './.git/*' -not -path './result/*'); do
  depth=0
  maxdepth=0
  while IFS= read -r line; do
    stripped=$(echo "$line" | sed 's/^[[:space:]]*//')
    case "$stripped" in
      let\ *) depth=$((depth+1)); [ "$depth" -gt "$maxdepth" ] && maxdepth=$depth;;
      in\ *|in) depth=$((depth-1));;
    esac
  done < "$f"
  [ "$maxdepth" -ge 3 ] && printf "  ${YELLOW}depth %d${RESET}  %s\n" "$maxdepth" "$f"
done

subheader "String interpolation hotspots (\${})"
rg -c '\$\{' --type nix 2>/dev/null | sort -t: -k2 -rn | head -10 | while IFS=: read -r file count; do
  printf "  %4d  %s\n" "$count" "$file"
done

subheader "Large let blocks (> 50 lines)"
awk '
  /^[[:space:]]*let[[:space:]]*$/ { in_let=1; let_start=NR; let_lines=0; next }
  /^[[:space:]]*in[[:space:]]*$/ && in_let { if (let_lines > 50) printf "  %4d lines  %s:%d\n", let_lines, FILENAME, let_start; in_let=0 }
  in_let { let_lines++ }
' $(find . -name 'render.nix' -not -path './.git/*') 2>/dev/null

# ─── 20. GIT CHURN ──────────────────────────
header "20. GIT CHURN (most changed files, 1 year)"
if git log --oneline --since="1 year ago" -- '*.nix' '*.sh' '*.rs' 2>/dev/null | head -1 >/dev/null; then
  git log --oneline --since="1 year ago" --name-only -- '*.nix' '*.sh' '*.rs' 2>/dev/null \
    | sort | uniq -c | sort -rn | head -15 \
    | while IFS= read -r line; do
      count=$(echo "$line" | awk '{print $1}')
      file=$(echo "$line" | awk '{$1=""; print $0}' | sed 's/^ *//')
      if [ "$count" -ge 20 ]; then
        printf "  ${RED}%3d${RESET}  %s\n" "$count" "$file"
      elif [ "$count" -ge 10 ]; then
        printf "  ${YELLOW}%3d${RESET}  %s\n" "$count" "$file"
      else
        printf "  ${GREEN}%3d${RESET}  %s\n" "$count" "$file"
      fi
    done
else
  warn "no commits in last year"
fi

printf "\n${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${RESET}\n"
printf "${BOLD}${GREEN}  Analysis complete.${RESET}\n"
printf "${CYAN}═══════════════════════════════════════════════════════════════${RESET}\n"
