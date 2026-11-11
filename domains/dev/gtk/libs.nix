{
  pkgs,
}:

let
  runtime = with pkgs; [
    gtk4
    libadwaita
    glib
    pango
    cairo
    gdk-pixbuf
    graphene
    harfbuzz
  ];

  dev = with pkgs; [
    gtk4.dev
    libadwaita.dev
    glib.dev
    pango.dev
    cairo.dev
    gdk-pixbuf.dev
    graphene.dev
    harfbuzz.dev
    freetype.dev
    fontconfig.dev
    fribidi.dev
    libthai.dev
    libpng.dev
    vulkan-loader.dev
    wayland.dev
    libxkbcommon.dev
  ];
in
{
  inherit runtime dev;
}
