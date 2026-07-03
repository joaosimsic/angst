{ themesLib, themeName, homeDirectory, ... }:

let
  t = themesLib.get themeName;
in
[
  {
    path = "domains/http-client/posting/config/config.yaml";
    text = ''
      theme: angst
      load_user_themes: true
      theme_directory: "${homeDirectory}/.config/posting/themes"
      layout: horizontal
      response:
        prettify_json: true
        show_size_and_time: true
      heading:
        show_host: false
        show_version: false
      text_input:
        blinking_cursor: false
      collection_browser:
        show_on_startup: true
    '';
  }
  {
    path = "domains/http-client/posting/config/themes/angst.yaml";
    text = ''
      name: angst
      primary: '#${t.BLUE}'
      secondary: '#${t.MAGENTA}'
      accent: '#${t.BRIGHT}'
      foreground: '#${t.FG}'
      background: '#${t.BG}'
      surface: '#${t.SURFACE}'
      error: '#${t.ERROR}'
      success: '#${t.SUCCESS}'
      warning: '#${t.WARNING}'
    '';
  }
]
