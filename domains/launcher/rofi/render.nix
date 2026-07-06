{
  themesLib,
  themeName,
  fontFamily,
  ...
}:

let
  t = themesLib.get themeName;
in
[
  {
    path = "domains/launcher/rofi/config/config.rasi";
    text = ''
      configuration {
          modi: "drun,run";
          show-icons: false;
          font: "${fontFamily} 11";
          drun-display-format: "{name}";
          kb-secondary-copy: "";
          kb-cancel: "Escape,Control+c,Control+bracketleft";
      }

      @theme "~/.config/rofi/theme.rasi"
    '';
  }
  {
    path = "domains/launcher/rofi/config/theme.rasi";
    text = ''
      * {
          bg:       #${t.BLACK};
          fg:       #${t.BASE};
          accent:   #${t.BRIGHT};
          subtle:   #${t.SUBTLE};

          background-color: transparent;
          text-color:       @fg;
          border-color:     @accent;
      }

      window {
          background-color: transparent;
          border:           0px;
          border-radius:    0px;
          width:            500px;
          padding:          0px;
      }

      mainbox {
          background-color: transparent;
          children:         [ inputbar, listview ];
          spacing:          0px;
          padding:          0px;
      }

      inputbar {
          background-color: @bg;
          border:           1px;
          border-color:     @accent;
          border-radius:    6px;
          padding:          8px 12px;
          margin:           0px 0px 4px 0px;
          children:         [ entry ];
      }

      entry {
          background-color: transparent;
          text-color:       @fg;
          placeholder-color: @subtle;
          placeholder:      "";
          cursor-width:     8px;
      }

      listview {
          background-color: @bg;
          border:           1px;
          border-color:     @accent;
          border-radius:    6px;
          padding:          4px 0px;
          margin:           0px;
          lines:            12;
          columns:          1;
          fixed-height:     true;
          scrollbar:        false;
      }

      element {
          background-color: transparent;
          text-color:       @fg;
          padding:          4px 12px;
          border-radius:    0px;
      }

      element selected.normal {
          background-color: @accent;
          text-color:       @bg;
      }

      element selected.active {
          background-color: @accent;
          text-color:       @bg;
      }

      element alternate.normal {
          background-color: transparent;
          text-color:       @fg;
      }

      element normal.normal {
          background-color: transparent;
          text-color:       @fg;
      }

      element-text {
          background-color: transparent;
          text-color:       inherit;
          highlight:        none;
      }

      element-icon {
          background-color: transparent;
          size:             16px;
          margin:           0px 8px 0px 0px;
      }
    '';
  }
]
