"""Helper utilities for angst flake analysis."""

import json
import re
import shutil
import subprocess
from collections import Counter
from pathlib import Path
from typing import Any

REPO = Path.cwd()


def has_cmd(name: str) -> bool:
    """Check if a command is available on PATH."""
    return shutil.which(name) is not None


def run(
    cmd: list[str],
    timeout: int | None = 120,
    check: bool = False,
    **kwargs,
) -> tuple[int, str, str]:
    """Run a command and return (returncode, stdout, stderr)."""
    try:
        r = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
            check=check,
            **kwargs,
        )
        if check:
            r.check_returncode()
        return r.returncode, r.stdout, r.stderr
    except FileNotFoundError:
        return -1, "", f"command not found: {cmd[0]}"
    except subprocess.TimeoutExpired:
        return -1, "", f"timed out ({timeout}s)"
    except subprocess.CalledProcessError as e:
        return e.returncode, e.stdout, e.stderr


def run_quiet(cmd: list[str], **kwargs) -> str:
    """Run and return stdout.strip(); empty string on failure."""
    rc, out, _ = run(cmd, **kwargs)
    return out.strip() if rc == 0 else ""


def find_nix_files(root: Path | None = None) -> list[Path]:
    """Find all .nix files in the repo, excluding .git, result, and tool subflakes."""
    root = root or REPO
    result: list[Path] = []
    for p in root.rglob("*.nix"):
        parts = p.relative_to(REPO).parts
        if ".git" in parts or "result" in parts:
            continue
        if len(parts) >= 2 and parts[0] == "tools" and parts[1] in ("vm", "shell"):
            continue
        result.append(p)
    return sorted(result)


def nix_eval(
    attr: str,
    apply: str | None = None,
    json_out: bool = False,
    **kwargs,
) -> tuple[int, str, str]:
    """nix eval wrapper."""
    cmd = ["nix", "eval", f".#{attr}", "--no-warn-dirty"]
    if json_out:
        cmd.append("--json")
    if apply:
        cmd.extend(["--apply", apply])
    return run(cmd, **kwargs)


def nix_eval_attr_names(attr: str, **kwargs) -> list[str]:
    """Return list of attribute names under #.attr."""
    rc, out, _ = nix_eval(attr, apply="builtins.attrNames", json_out=True, **kwargs)
    if rc != 0:
        return []
    try:
        return json.loads(out)
    except json.JSONDecodeError:
        return []


def git_log(patterns: list[str], since: str = "1 year ago") -> list[str]:
    """Run git log --name-only for the given patterns and since date."""
    cmd = [
        "git",
        "log",
        "--oneline",
        f"--since={since}",
        "--name-only",
        "--",
    ] + patterns
    rc, out, _ = run(cmd, timeout=30)
    if rc != 0:
        return []
    return [l for l in out.splitlines() if l and not l.startswith(("commit ", "Date:"))]


def md_escape(s: str | int | float) -> str:
    """Escape pipe characters for markdown table cells."""
    return str(s).replace("|", "\\|")


def md_table(headers: list[str], rows: list[list[Any]]) -> str:
    """Render a markdown table from headers and rows."""
    lines = ["| " + " | ".join(str(h) for h in headers) + " |"]
    lines.append("|" + "|".join("---" for _ in headers) + "|")
    for row in rows:
        lines.append("| " + " | ".join(md_escape(c) for c in row) + " |")
    return "\n".join(lines)


def md_section(n: int, title: str) -> str:
    """Render a markdown ## section heading."""
    return f"\n## {n}. {title}\n"


def md_subsection(title: str) -> str:
    """Render a markdown ### subsection heading."""
    return f"\n### {title}\n"


def md_code(text: str, lang: str = "") -> str:
    """Render text in a markdown code block."""
    return f"```{lang}\n{text}\n```"


def read_nix(path: Path) -> str:
    """Read a .nix file, returning empty string on error."""
    try:
        return path.read_text(encoding="utf-8")
    except OSError:
        return ""


def parse_imports(text: str, base_dir: Path) -> list[Path]:
    """Extract imported .nix file paths relative to base_dir."""
    imports: list[Path] = []
    for m in re.finditer(
        r"""import\s+(?:\(?\s*)(\.\.?/[^'"\s;)]+)\.nix|"""
        r"""import\s+(?:\(?\s*)["'](\.\.?/[^"'\s;)]+)["']""",
        text,
    ):
        raw = (m.group(1) or m.group(2)).rstrip("/")
        if raw.startswith("."):
            full = (base_dir / raw).resolve()
            for candidate in [full, full.with_suffix(".nix")]:
                if candidate.exists() and candidate.suffix == ".nix":
                    imports.append(candidate)
                    break
    return imports


def parse_imports_from_tree(
    files: list[Path],
) -> tuple[dict[Path, list[Path]], dict[Path, int]]:
    """Return (fan_out: file -> imports, fan_in: file -> import_count)."""
    fan_out: dict[Path, list[Path]] = {}
    fan_in: Counter = Counter()
    for f in files:
        text = read_nix(f)
        deps = parse_imports(text, f.parent)
        fan_out[f] = deps
        for d in deps:
            fan_in[d] += 1
    return fan_out, dict(fan_in)
