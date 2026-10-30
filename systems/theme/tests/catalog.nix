{ lib, themeSys }:

let
  inherit (import ./assert.nix { inherit lib; })
    assertEq
    assertTrue
    ;

  ids = map (entry: entry.id) themeSys.entries;
  sortedIds = lib.sort lib.lessThan ids;
in
[
  (assertTrue "catalog has no diagnostics" (themeSys.diagnostics == [ ]))
  (assertEq "catalog entries are sorted by ID" sortedIds ids)
  (assertEq "catalog index keys match entries" (lib.attrNames themeSys.index) ids)
  (assertTrue "catalog entries are validated" (
    lib.all (entry: lib.isAttrs entry.value && entry.value ? palette) themeSys.entries
  ))
]
