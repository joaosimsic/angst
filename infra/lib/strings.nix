let
  hasSuffix =
    suffix: str:
    let
      strLen = builtins.stringLength str;
      suffixLen = builtins.stringLength suffix;
    in
    builtins.isString str && strLen >= suffixLen && builtins.substring (strLen - suffixLen) suffixLen str == suffix;

  stripSuffix =
    suffix: str:
    if hasSuffix suffix str then
      builtins.substring 0 (builtins.stringLength str - builtins.stringLength suffix) str
    else
      str;

  stripSuffixes = suffixes: str: builtins.foldl' (acc: suffix: stripSuffix suffix acc) str suffixes;

  uniqueSorted =
    xs:
    builtins.foldl' (
      acc: x:
      if acc == [ ] || builtins.elemAt acc (builtins.length acc - 1) != x then acc ++ [ x ] else acc
    ) [ ] (builtins.sort builtins.lessThan xs);
in
{
  inherit
    hasSuffix
    stripSuffix
    stripSuffixes
    uniqueSorted
    ;
}
