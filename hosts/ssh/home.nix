{ lib, ... }: {
  imports = [ ../../common/home.nix ];

  nixpkgs.overlays = [
    (final: prev: {
      opencode = with final; stdenvNoCC.mkDerivation {
        pname = "opencode";
        version = prev.opencode.version;

        src = fetchurl {
          url = "https://github.com/anomalyco/opencode/releases/download/v${prev.opencode.version}/opencode-linux-x64-baseline.tar.gz";
          hash = "sha256-JshWl3IPExni13BD0n5ozRtAjWDRNcterJ8+CBfvazA=";
        };

        nativeBuildInputs = [ installShellFiles makeBinaryWrapper ];

        dontUnpack = true;
        dontConfigure = true;
        dontBuild = true;

        installPhase = ''
          runHook preInstall

          tar -xzf $src
          install -Dm755 opencode $out/bin/opencode
          wrapProgram $out/bin/opencode \
            --prefix PATH : ${lib.makeBinPath [ ripgrep ]} \
            --set OPENCODE_DISABLE_AUTOUPDATE true

          runHook postInstall
        '';

        postInstall = ''
          installShellCompletion --cmd opencode \
            --bash <($out/bin/opencode completion) \
            --zsh <(SHELL=/bin/zsh $out/bin/opencode completion)
        '';

        meta = prev.opencode.meta // {
          platforms = [ "x86_64-linux" ];
        };
      };
    })
  ];

  home.file.".profile" = {
    text = ''
      if [ -x "$(command -v nu)" ]; then
        exec nu -l
      fi
    '';
    force = true;
  };
}
