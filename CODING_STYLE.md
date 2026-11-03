# Coding style

Mandatory for all Go and Nix in this repository.

Applies to new and modified code. Do not copy nearby violations. If existing code
conflicts with this document, follow this document and refactor the code you
touch. Do not reformat unrelated code.

## Universal rules

### Guard clauses

Handle invalid or terminal cases first and return or throw early. Do not wrap the
happy path in `else`.

```go
// Bad
if err != nil {
    return err
} else {
    return use(value)
}

// Good
if err != nil {
    return err
}
return use(value)
```

Use `switch` for multi-way dispatch instead of long `if / else if / else` chains.

### Indentation

Maximum 3 indentation levels inside a function. The function body counts as level
1. At level 4, extract a helper or add a guard.

```go
// Bad: 4 levels
func handle(items []Item) error {
    for _, item := range items {
        if item.Valid {
            if item.Ready {
                process(item)
            }
        }
    }
    return nil
}

// Good: guard first, flat body
func handle(items []Item) error {
    for _, item := range items {
        if !item.Valid || !item.Ready {
            continue
        }
        process(item)
    }
    return nil
}
```

Same limit for Nix.

### Blank lines

Put one blank line between independent statements and statement groups. Omit it
only when the lines form one action, such as a declaration and its immediate
validation, a call and its result check, or a sequence of guard clauses for the
same condition.

Independent non-declaration statements are separate groups. Do not run unrelated
calls, assignments, or returns together.

Small, closely related declarations may be stacked without blank lines. A
declaration that spans multiple lines or holds a large expression, such as an
embedded code block, must stand as its own group.

```go
// Bad
absolutePath := engine.Worktree.Abs(relativePath)
expression := fmt.Sprintf(`...embedded code block...`, Quote(absolutePath))
output, err := engine.run(..., expression)

// Good
absolutePath := engine.Worktree.Abs(relativePath)

expression := fmt.Sprintf(`...embedded code block...`, Quote(absolutePath))

output, err := engine.run(..., expression)
if err != nil {
    return Exports{}, err
}
```

```go
// Bad
scanner.scanImports(tokens, &result)
scanner.scanAliases(tokens, &result)
scanner.scanReferences(tokens, &result)

// Good
scanner.scanImports(tokens, &result)

scanner.scanAliases(tokens, &result)

scanner.scanReferences(tokens, &result)
```

```go
// Good: small related declarations may stack
worktree := repo.Worktree{Root: root}
files, err := worktree.TrackedFiles("*.nix")
if err != nil {
    return err
}
```

```nix
# Good: related binding stays with its use
let
  raw = builtins.readFile path;
  data = builtins.fromJSON raw;
in
data
```

### File size

Keep Go files at or below about 150 lines. Split by responsibility when a file
exceeds the limit; do not split mechanically. Test files follow the same limit.

### Names

Use descriptive names. No single-letter names except `i`, `j`, `k` as loop
indices, and `err`, `ok`, `_`.

Receivers and parameters must be descriptive.

```go
// Bad
func (a analyzer) exportUsed(file string, info *fileInfo, private bool, name string) bool

// Good
func (analyzer analyzer) exportUsed(file string, info *fileInfo, private bool, name string) bool
```

Use `context.Context` as `ctx`. Do not use `ctx` for ordinary data.

### Descriptive names over short names

A function or variable must be understandable without the full context of its
declaration file. Choose the domain word over the abbreviation, even when the
short name is convenient. The name must still make sense at every call site and
when read in isolation.

Do not use names such as `a`, `b`, `x`, `s`, `v`, `r`, `e`, `f`, `m`, `acc`, or
`ctx` for ordinary data. `ctx` is reserved for `context.Context`. The only
allowed short names are the loop indices `i`, `j`, `k`, `err`, `ok`, and `_`.

```nix
# Bad: meaning only exists inside this file
sortEntries = builtins.sort (a: b: a.slug < b.slug || (a.slug == b.slug && a.file < b.file));

# Good: readable at the use site
sortEntries = builtins.sort (
  left: right: left.slug < right.slug || (left.slug == right.slug && left.file < right.file)
);
```

```go
// Bad
func (a analyzer) exportUsed(file string, info *fileInfo, private bool, name string) bool

// Good
func (analyzer analyzer) exportUsed(file string, info *fileInfo, private bool, name string) bool
```

Do not abbreviate a name that carries domain meaning: prefer
`renderDiagnosticLine` to `renderDiagnosticFn`, `walkDirectoryTree` to `walkGo`,
and `secretInventoryModule` to `inventoryMod`.

### No code comments

Do not add comments to production code. Names and structure must explain the
code. No file headers, phase plans, history, or restatements.

### Test comments

Test files are the only exception. A test comment may explain a non-obvious
fixture or scenario. Keep it to 2 lines and explain why, not what.

Generated files may keep the standard generated-file marker.

## Go rules

### Sets

Do not use `map[string]bool` as a set. Use `map[string]struct{}` or a named set
type. If the bool carries meaning, use a struct field or a named type.

```go
// Bad
files := map[string]bool{}
files[path] = true
if files[path] { ... }

// Good
files := map[string]struct{}{}
files[path] = struct{}{}
if _, ok := files[path]; ok { ... }
```

### Slices

Preallocate when the length is known. Do not grow with append in a loop.

```go
// Bad
var out []Violation
for _, file := range files {
    out = append(out, check(file)...)
}

// Good
out := make([]Violation, 0, len(files))
for _, file := range files {
    out = append(out, check(file)...)
}
```

Prefer `slices` and `maps` helpers over manual loops.

```go
// Bad
names := make([]string, 0, len(entries))
for name := range entries {
    names = append(names, name)
}
sort.Strings(names)

// Good
names := slices.Sorted(maps.Keys(entries))
```

### Control flow

No `else` after `return`. No nested `if / else`.

```go
// Bad
if private {
    return inside(source)
} else if info.ModuleRoot != "" {
    return !inside(source)
} else {
    return true
}

// Good
switch {
case private:
    return inside(source)
case info.ModuleRoot != "":
    return !inside(source)
default:
    return true
}
```

### Return spacing

Put one blank line before a `return` unless it is the first statement in a block
or immediately follows another `return`.

```go
// Bad
if err != nil {
    return err
}
return value

// Good
if err != nil {
    return err
}

return value
```

```go
// Bad
result := compute()
return result

// Good
result := compute()

return result
```

### Errors

Wrap errors with `%w`. Keep messages lowercase and specific.

```go
// Bad
return fmt.Errorf("git ls-files: %s", msg)

// Good
return fmt.Errorf("git ls-files: %w", err)
```

## Nix rules

### No Result emulation

Do not build a Result type or pass success and failure values through the
codebase. No `ok`, `err`, `isOk`, `isErr`, `mapOk`, `andThen`, `withContext`,
`collect`, `unwrap`, or `_result`.

Validate at the boundary. Return the value on success. Throw on invalid input.

```nix
# Bad
check = cond: e: if cond then ok true else err e;
result = check valid value;
in
if result.ok then result.value else throw result.error.message

# Good
if !valid then
  throw "module: value must be valid"
else
  value
```

### No bare asserts

Do not use `assert` for input validation. Do not assign a check to `_` and assert
it later.

```nix
# Bad
assert builtins.isAttrs data;
let
  _ = checkShape ctx checks;
in
assert _;
{ inherit data; }

# Good
if !builtins.isAttrs data then
  throw "logger: `data` must be an attrset"
else
  { inherit data; }
```

### No point-free style

Name lambda parameters and function arguments. Do not rely on partial
application when it hides intent.

```nix
# Bad
builtins.all builtins.isString packages
builtins.concatStringsSep "\n" (builtins.map renderDiagnosticFn diags)
builtins.map (r: r.value) results

# Good
builtins.all (package: builtins.isString package) packages
builtins.concatStringsSep "\n" (builtins.map (diagnostic: renderDiagnostic diagnostic) diagnostics)
builtins.map (result: result.value) results
```

### Control flow

No long `if / else if / else` chains. Use attrset dispatch or a helper.

```nix
# Bad
if kind == "file" then
  handleFile value
else if kind == "directory" then
  handleDirectory value
else if kind == "symlink" then
  handleSymlink value
else
  throw "unknown kind"

# Good
handlers = {
  file = handleFile;
  directory = handleDirectory;
  symlink = handleSymlink;
};
in
handlers.${kind} value
```

Guard checks are allowed:

```nix
if !(builtins.isList diags) then
  throw "logger: expected a list of diagnostics"
else if diags == [ ] then
  null
else
  throw (render diags)
```

### Expressions

Extract long inline `if` expressions and string concatenations into `let`
bindings.

```nix
# Bad
"ts=${v.ts} level=${v.level} code=${v.code} scope=${v.scope} host=${v.host} phase=${v.phase} message=${v.message} data=${builtins.toJSON (v.data or { })}"

# Good
let
  data = builtins.toJSON (event.data or { });
  line = "ts=${event.ts} level=${event.level} code=${event.code} scope=${event.scope} host=${event.host} phase=${event.phase} message=${event.message} data=${data}";
in
line
```

### Error context

Do not use `//` to merge error context. Build the full attrset explicitly.

```nix
# Bad
error = result.error // {
  context = context // result.error.context;
};

# Good
error = {
  kind = result.error.kind;
  message = result.error.message;
  context = context // result.error.context;
  causes = result.error.causes;
};
```

### Imports and exports

Keep `inherit` blocks small and grouped by source module. Do not re-export a
large facade in one wall.

```nix
# Bad
inherit
  a
  b
  c
  d
  e
  f
  g
  h
  ;

# Good
inherit (codesModule)
  checkLogCode
  logCodes
  ;
inherit (levelsModule)
  checkLogLevel
  logLevels
  ;
```

## Review checklist

- No `else` after `return`.
- No `if / else if / else` chains.
- No 4th indentation level.
- Independent statements and statement groups separated by blank lines.
- Multi-line or large declarations stand alone; only small related declarations stack.
- Kept together only for one action: declaration + validation, call + result check, or one guard sequence.
- No `map[string]bool` as a set.
- No append loop when the length is known.
- No single-letter names outside loop indices and `err` / `ok`.
- No Result emulation in Nix.
- No bare `assert` validation in Nix.
- No point-free Nix that hides intent.
- No long inline Nix expressions.
- No `//` error merging.
- No comments in production code; test comments max 2 lines.
- Names understandable without opening their declaration file.
- Blank line before a non-leading `return`.
