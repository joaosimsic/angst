{
  pkgs,
}:

pkgs.runCommand "check-opencode-attention"
  {
    nativeBuildInputs = [ pkgs.bun ];
  }
  ''
    export HOME=$TMPDIR/home
    mkdir -p "$HOME" work/checks work/domains/agents/opencode/config/plugins
    cp ${./opencode-attention.test.ts} work/checks/opencode-attention.test.ts
    cp ${../domains/agents/opencode/config/plugins/attention.ts} work/domains/agents/opencode/config/plugins/attention.ts
    cd work
    bun test checks/opencode-attention.test.ts
    touch $out
  ''
