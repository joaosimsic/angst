let
  frequencies = [
    22.40
    27.80
    34.51
    42.82
    53.14
    65.95
    81.83
    101.55
    126.00
    156.38
    194.06
    240.81
    298.834
    370.834
    460.182
    571.057
    708.647
    879.387
    1091.26
    1354.19
    1680.47
    2085.35
    2587.79
    3211.29
    3985.01
    4945.15
    6136.63
    7615.17
    9449.96
    11726.8
    14552.2
    18058.4
  ];

  gains = [
    0.0
    0.0
    0.0
    0.0
    0.0
    0.0
    0.0
    0.0
    0.0
    0.0
    0.0
    0.0
    0.0
    0.0
    0.0
    0.0
    0.0
    (-0.99)
    (-1.89)
    (-2.38)
    (-3.04)
    (-3.29)
    (-3.29)
    (-2.63)
    (-2.96)
    (-2.63)
    (-2.14)
    (-2.63)
    (-2.55)
    (-2.63)
    (-3.12)
    (-3.12)
  ];

  mkBand = i: {
    type = "Bell";
    mode = "RLC (BT)";
    slope = "x1";
    solo = false;
    mute = false;
    gain = builtins.elemAt gains i;
    frequency = builtins.elemAt frequencies i;
    q = 4.36;
    width = 4.0;
  };

  bands = builtins.listToAttrs (
    builtins.genList (i: {
      name = "band${toString i}";
      value = mkBand i;
    }) 32
  );
in
{
  blocklist = [ ];

  plugins_order = [
    "equalizer#0"
    "bass_enhancer#0"
  ];

  "equalizer#0" = {
    bypass = false;
    input-gain = 0.0;
    output-gain = 0.0;
    mode = "IIR";
    decramp = "Off";
    split-channels = false;
    balance = 0.0;
    pitch-left = 0.0;
    pitch-right = 0.0;
    num-bands = 32;
    left = bands;
    right = bands;
  };

  "bass_enhancer#0" = {
    bypass = false;
    input-gain = 0.0;
    output-gain = 1.0;
    amount = 1.9;
    harmonics = 4.0;
    scope = 100.0;
    floor = 10.0;
    blend = 4.0;
    floor-active = true;
  };
}
