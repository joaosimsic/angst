{ themesLib, themeName }:

let
  t = themesLib.get themeName;
  p = t.palette;

  theme = builtins.toJSON {
    theme = {
      primary = "#${p.accent.base}";
      secondary = "#${p.foreground.variant}";
      accent = "#${p.accent.base}";
      error = "#${t.ansi.error}";
      warning = "#${t.ansi.warn}";
      success = "#${t.ansi.success}";
      info = "#${t.ansi.info}";
      text = "#${p.foreground.variant}";
      textMuted = "#${p.dim}";
      background = "#${p.background.base}";
      backgroundPanel = "#${p.background.variant}";
      backgroundElement = "#${p.background.variant}";
      border = "#${p.foreground.base}";
      borderActive = "#${p.accent.base}";
      borderSubtle = "#${p.accent.base}";
      diffAdded = "#${p.background.base}";
      diffRemoved = "#${p.background.base}";
      diffContext = "#${p.background.variant}";
      diffHunkHeader = "#${p.foreground.base}";
      diffHighlightAdded = "#${p.background.variant}";
      diffHighlightRemoved = "#${p.background.variant}";
      diffAddedBg = "#${t.ansi.success}";
      diffRemovedBg = "#${t.ansi.error}";
      diffContextBg = "#${p.background.variant}";
      diffLineNumber = "#${p.foreground.variant}";
      diffAddedLineNumberBg = "#${t.ansi.success}";
      diffRemovedLineNumberBg = "#${t.ansi.error}";
      markdownText = "#${p.foreground.variant}";
      markdownHeading = "#${p.accent.base}";
      markdownLink = "#${p.foreground.variant}";
      markdownLinkText = "#${p.accent.base}";
      markdownCode = "#${p.surface.variant}";
      markdownBlockQuote = "#${p.dim}";
      markdownEmph = "#${p.accent.base}";
      markdownStrong = "#${p.foreground.variant}";
      markdownHorizontalRule = "#${p.accent.base}";
      markdownListItem = "#${p.accent.base}";
      markdownListEnumeration = "#${p.accent.base}";
      markdownImage = "#${p.foreground.variant}";
      markdownImageText = "#${p.accent.base}";
      markdownCodeBlock = "#${p.foreground.variant}";
      syntaxComment = "#${p.dim}";
      syntaxKeyword = "#${p.accent.base}";
      syntaxFunction = "#${p.foreground.variant}";
      syntaxVariable = "#${p.foreground.variant}";
      syntaxString = "#${p.foreground.variant}";
      syntaxNumber = "#${p.accent.base}";
      syntaxType = "#${p.foreground.base}";
      syntaxOperator = "#${p.foreground.base}";
      syntaxPunctuation = "#${p.foreground.base}";
    };
  };

  tuiConfig = builtins.toJSON {
    theme = "angst";
    "$schema" = "https://opencode.ai/tui.json";
    keybinds = {
      messages_half_page_up = "ctrl+u";
      messages_half_page_down = "ctrl+d";
    };
  };

  opencodeConfig = builtins.toJSON {
    "$schema" = "https://opencode.ai/config.json";
    model = "opencode-go/deepseek-v4-pro";
    provider = {
      opencode-go = {
        options = {
          apiKey = "{file:~/.secrets/opencode-go-key}";
        };
      };
    };
    lsp = {
      nixd = {
        command = [ "nixd" ];
        extensions = [ ".nix" ];
      };
      "lua-ls" = {
        command = [ "lua-language-server" ];
        extensions = [ ".lua" ];
      };
      rust = {
        command = [ "rust-analyzer-mux" ];
        extensions = [ ".rs" ];
        initialization = {
          "rust-analyzer".check.command = "clippy";
          "rust-analyzer".inlayHints.chainingHints.enable = true;
          "rust-analyzer".inlayHints.parameterHints.enable = true;
          "rust-analyzer".inlayHints.typeHints.enable = true;
        };
      };
      gopls = {
        command = [ "gopls" "-remote=unix;/run/user/1000/gopls.sock" ];
        extensions = [ ".go" ];
      };
      pyright = {
        command = [ "pyright-langserver" "--stdio" ];
        extensions = [ ".py" ];
      };
      typescript = {
        command = [ "typescript-language-server" "--stdio" ];
        extensions = [ ".ts" ".tsx" ];
      };
      javascript = {
        command = [ "typescript-language-server" "--stdio" ];
        extensions = [ ".js" ".jsx" ".mjs" ".cjs" ];
      };
      html = {
        command = [ "vscode-html-language-server" "--stdio" ];
        extensions = [ ".html" ];
      };
      css = {
        command = [ "vscode-css-language-server" "--stdio" ];
        extensions = [ ".css" ".scss" ".less" ];
      };
      json = {
        command = [ "vscode-json-language-server" "--stdio" ];
        extensions = [ ".json" ".jsonc" ];
      };
      "yaml-ls" = {
        command = [ "yaml-language-server" "--stdio" ];
        extensions = [ ".yaml" ".yml" ];
      };
      bash = {
        command = [ "bash-language-server" "start" ];
        extensions = [ ".sh" ".bash" ];
      };
      markdown = {
        command = [ "marksman" "server" ];
        extensions = [ ".md" ];
      };
      jdtls = {
        command = [ "jdt-language-server" ];
        extensions = [ ".java" ];
      };
      "php intelephense" = {
        disabled = true;
      };
      php = {
        command = [ "phpactor" "language-server" ];
        extensions = [ ".php" ];
      };
      dockerfile = {
        command = [ "docker-langserver" "--stdio" ];
        extensions = [ "Dockerfile" ];
      };
      terraform = {
        command = [ "terraform-ls" "serve" ];
        extensions = [ ".tf" ".tfvars" ];
      };
      "clojure-lsp" = {
        command = [ "clojure-lsp" ];
        extensions = [ ".clj" ".cljs" ".cljc" ".edn" ];
      };
      xml = {
        command = [ "lemminx" ];
        extensions = [ ".xml" ".xsd" ".xsl" ".xslt" ];
      };
      clangd = {
        command = [ "clangd" ];
        extensions = [ ".c" ".h" ".cpp" ".hpp" ".cc" ".hh" ".cxx" ".hxx" ];
      };
      vue = {
        command = [ "vue-language-server" "--stdio" ];
        extensions = [ ".vue" ];
      };
      toml = {
        command = [ "taplo" "lsp" "stdio" ];
        extensions = [ ".toml" ];
      };
      hls = {
        command = [ "haskell-language-server-wrapper" "--lsp" ];
        extensions = [ ".hs" ".lhs" ];
      };
    };
  };
in
[
  {
    path = "domains/agents/opencode/config/tui.json";
    text = tuiConfig;
  }
  {
    path = "domains/agents/opencode/config/themes/angst.json";
    text = theme;
  }
  {
    path = "domains/agents/opencode/config/opencode.jsonc";
    text = opencodeConfig;
  }
]
