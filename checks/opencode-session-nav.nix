{
  pkgs,
}:

pkgs.runCommand "check-opencode-session-nav"
  {
    nativeBuildInputs = [ pkgs.bun ];
  }
  ''
    export HOME=$TMPDIR/home
    mkdir -p "$HOME" work/checks work/domains/agents/opencode/config/tui-plugins
    cp ${./opencode-session-nav.test.ts} work/checks/opencode-session-nav.test.ts
    cp ${../domains/agents/opencode/config/tui-plugins/session-nav.ts} work/domains/agents/opencode/config/tui-plugins/session-nav.ts
    cd work
    bun test checks/opencode-session-nav.test.ts
    touch $out
  ''
