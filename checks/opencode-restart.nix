{
  pkgs,
}:

pkgs.runCommand "check-opencode-restart"
  {
    nativeBuildInputs = [ pkgs.bun ];
  }
  ''
    export HOME=$TMPDIR/home
    mkdir -p "$HOME" work/checks work/domains/agents/opencode/config/plugins
    cp ${./opencode-restart.test.ts} work/checks/opencode-restart.test.ts
    cp ${../domains/agents/opencode/config/plugins/restart.ts} work/domains/agents/opencode/config/plugins/restart.ts
    cd work
    bun test checks/opencode-restart.test.ts
    touch $out
  ''
