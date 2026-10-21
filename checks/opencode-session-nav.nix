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
    cp ${../domains/agents/opencode/config/tui-plugins/vim-core.ts} work/domains/agents/opencode/config/tui-plugins/vim-core.ts
    cp ${../domains/agents/opencode/config/tui-plugins/vim-mode.ts} work/domains/agents/opencode/config/tui-plugins/vim-mode.ts
    cp ${../domains/agents/opencode/config/tui-plugins/vim-prompt.ts} work/domains/agents/opencode/config/tui-plugins/vim-prompt.ts
    cp ${../domains/agents/opencode/config/tui-plugins/vim-indicator.tsx} work/domains/agents/opencode/config/tui-plugins/vim-indicator.tsx
    cd work
    bun test checks/opencode-session-nav.test.ts
    bun build domains/agents/opencode/config/tui-plugins/vim-indicator.tsx \
      --target=bun \
      --outfile=vim-indicator.js \
      --external solid-js \
      --external '@opentui/solid/jsx-runtime' \
      --external '@opentui/solid/jsx-dev-runtime' \
      --external '@opencode-ai/plugin/tui'
    touch $out
  ''
