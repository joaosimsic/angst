{
  config,
  lib,
  ...
}:

let
  cfg = config.domains.office.libreoffice;
  mimes = import ./mime.nix;

  officeMimes =
    lib.genAttrs mimes.writer (_: "writer.desktop")
    // lib.genAttrs mimes.calc (_: "calc.desktop")
    // lib.genAttrs mimes.impress (_: "impress.desktop");
in
{
  config = lib.mkIf cfg.enable {
    xdg.mimeApps = {
      enable = true;
      defaultApplications = officeMimes;
      associations.added = officeMimes;
    };
  };
}
