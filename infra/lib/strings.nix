let
  hasSuffix =
    suffix: value:
    if !(builtins.isString suffix) || !(builtins.isString value) then
      false
    else
      let
        valueLength = builtins.stringLength value;
        suffixLength = builtins.stringLength suffix;
      in
      valueLength >= suffixLength
      && builtins.substring (valueLength - suffixLength) suffixLength value == suffix;

  stripSuffix =
    suffix: value:
    if hasSuffix suffix value then
      builtins.substring 0 (builtins.stringLength value - builtins.stringLength suffix) value
    else
      value;

  uniqueSorted =
    values:
    builtins.foldl' (
      sortedValues: value:
      if
        sortedValues == [ ] || builtins.elemAt sortedValues (builtins.length sortedValues - 1) != value
      then
        sortedValues ++ [ value ]
      else
        sortedValues
    ) [ ] (builtins.sort (left: right: left < right) values);

  isNonEmptyString = value: builtins.isString value && value != "";
in
{
  inherit
    hasSuffix
    isNonEmptyString
    stripSuffix
    uniqueSorted
    ;
}
