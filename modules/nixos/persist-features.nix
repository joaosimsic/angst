{
  features = {
    "agents.opencode" = [
      {
        dir = ".local/share/opencode";
        name = "opencode";
        durable = true;
      }
      {
        dir = ".local/state/opencode";
        name = "opencode-state";
        durable = true;
      }
      {
        dir = ".cache/opencode";
      }
    ];
    "editor.nvim" = [
      {
        dir = ".local/share/nvim";
        name = "nvim";
        durable = true;
      }
      {
        dir = ".local/state/nvim";
        name = "nvim-state";
        durable = true;
      }
    ];
    "security.age" = [
      {
        dir = ".config/age";
        name = "age";
        durable = true;
        neededForBoot = true;
      }
    ];
    "browser.firefox" = [
      {
        dir = ".mozilla";
        name = "mozilla";
        durable = true;
      }
    ];
    "browser.google-chrome" = [
      {
        dir = ".config/google-chrome";
        name = "google-chrome";
        durable = true;
      }
    ];
    "chat.discord" = [
      {
        dir = ".config/discord";
        name = "discord";
        durable = true;
      }
    ];
    "git.code" = [
      {
        dir = ".config/git";
        name = "git";
        durable = true;
      }
    ];
    "git.projects" = [
      {
        dir = "projects";
        name = "projects";
        durable = true;
      }
    ];
    "kernel.graphical" = [
      {
        dir = ".local/share/keyrings";
        name = "keyrings";
        durable = true;
      }
      {
        dir = ".cache/fontconfig";
      }
    ];
    "shell.nushell" = [
      {
        dir = ".local/share/nushell";
        name = "nushell";
        durable = true;
      }
    ];
    "toolchain:rust" = [
      {
        dir = ".cargo";
        name = "cargo";
        durable = true;
      }
    ];
  };
}
