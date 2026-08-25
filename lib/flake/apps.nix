{
  context,
}:

let
  inherit (context)
    representative
    defaultSystem
    runtime
    angstShell
    hmSwitchTool
    pkgs
    ;

  mkApp = program: {
    type = "app";
    inherit program;
  };

  vmApp = pkgs.writeShellApplication {
    name = "vm";
    runtimeInputs = [ runtime.vmTool ];
    text = ''
      exec ${runtime.vmTool}/bin/vm "$@"
    '';
  };
in
{
  apps.${defaultSystem} = {
    vm = mkApp "${vmApp}/bin/vm";
    shell = mkApp "${angstShell}/bin/angst-shell";
    hm-switch = mkApp "${hmSwitchTool}/bin/hm-switch";
    angst = mkApp "${runtime.angstCli.bin}";
    render = mkApp "${runtime.apps.render}";
    watch = mkApp "${runtime.apps.watch}";
    check = mkApp "${runtime.apps.check}";
    lint-themes = mkApp "${runtime.apps.lint-themes}";
    lint-desktop = mkApp "${runtime.apps.lint-desktop { system = defaultSystem; }}";
    lint-shell = mkApp "${runtime.apps.lint-shell { system = defaultSystem; }}";
    analyze = mkApp "${runtime.apps.analyze}";
    analyze-to-file = mkApp "${runtime.apps.analyze-to-file}";
  }
  // (
    if representative != null then
      {
        ssh =
          let
            target = representative.username;
          in
          mkApp "${runtime.apps.ssh-deploy { username = target; }}";
      }
    else
      { }
  );
}
