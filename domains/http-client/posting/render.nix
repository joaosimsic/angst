{
  themesLib,
  themeName,
  homeDirectory,
  ...
}:

let
  t = themesLib.get themeName;
  p = t.palette;
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
      primary: '#${p.surface.base}'
      secondary: '#${p.accent.variant}'
      accent: '#${p.foreground.variant}'
      foreground: '#${p.foreground.base}'
      background: '#${p.background.base}'
      surface: '#${p.background.variant}'
      error: '#${t.ansi.error}'
      success: '#${t.ansi.success}'
      warning: '#${t.ansi.warn}'
    '';
  }
]
