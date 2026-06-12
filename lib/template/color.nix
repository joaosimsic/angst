{ lib }:

let
  hexValues = {
    "0" = 0;
    "1" = 1;
    "2" = 2;
    "3" = 3;
    "4" = 4;
    "5" = 5;
    "6" = 6;
    "7" = 7;
    "8" = 8;
    "9" = 9;
    "a" = 10;
    "b" = 11;
    "c" = 12;
    "d" = 13;
    "e" = 14;
    "f" = 15;
  };

  hexByte = hex: offset:
    let
      hi = lib.toLower (lib.substring offset 1 hex);
      lo = lib.toLower (lib.substring (offset + 1) 1 hex);
    in
    hexValues.${hi} * 16 + hexValues.${lo};

  toHexByte = value:
    let
      clamped = lib.min 255 (lib.max 0 value);
      hi = lib.div clamped 16;
      lo = lib.mod clamped 16;
      digits = [ "0" "1" "2" "3" "4" "5" "6" "7" "8" "9" "a" "b" "c" "d" "e" "f" ];
    in
    "${builtins.elemAt digits hi}${builtins.elemAt digits lo}";

  lightenHex = hex: delta:
    let
      byte = offset: toHexByte (hexByte hex offset + delta);
    in
    "${byte 0}${byte 2}${byte 4}";

  brighten = color: lightenHex color 24;
in
{
  inherit lightenHex brighten;
}
