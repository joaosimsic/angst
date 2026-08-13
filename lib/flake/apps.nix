{
  context,
}:

let
  inherit (context)
    representative
    defaultSystem
    runtime
    vmOutputs
    shellTool
    ;

  mkApp = program: {
    type = "app";
    inherit program;
  };
in
{
  apps.${defaultSystem} = {
    vm = mkApp "${vmOutputs.packages.${defaultSystem}.wrapped}/bin/vm";
    shell = mkApp "${shellTool}/bin/shell";
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
