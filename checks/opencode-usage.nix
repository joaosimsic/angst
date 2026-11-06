{
  pkgs,
}:

pkgs.runCommand "check-opencode-usage"
  {
    nativeBuildInputs = [ pkgs.bun ];
  }
  ''
    export HOME=$TMPDIR/home
    mkdir -p "$HOME" work/checks work/domains/agents/opencode/config/tui-plugins
    cp ${./opencode-usage.test.ts} work/checks/opencode-usage.test.ts
    cp ${../domains/agents/opencode/config/tui-plugins/usage.tsx} work/domains/agents/opencode/config/tui-plugins/usage.tsx
    cp ${../domains/agents/opencode/config/tui-plugins/usage-api.ts} work/domains/agents/opencode/config/tui-plugins/usage-api.ts
    cp ${../domains/agents/opencode/config/tui-plugins/usage-format.ts} work/domains/agents/opencode/config/tui-plugins/usage-format.ts
    cp ${../domains/agents/opencode/config/tui-plugins/usage-models.ts} work/domains/agents/opencode/config/tui-plugins/usage-models.ts
    cd work
    bun test checks/opencode-usage.test.ts
    bun build domains/agents/opencode/config/tui-plugins/usage.tsx \
      --target=bun \
      --outfile=usage.js \
      --external solid-js \
      --external '@opentui/solid/jsx-runtime' \
      --external '@opentui/solid/jsx-dev-runtime' \
      --external '@opencode-ai/plugin/tui'
    touch $out
  ''
