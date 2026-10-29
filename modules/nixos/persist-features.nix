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
    "display.gpu" = [
      {
        dir = ".cache/mesa_shader_cache";
      }
      {
        dir = ".cache/nvidia";
      }
      {
        dir = ".nv/GLCache";
      }
      {
        dir = ".nv/ComputeCache";
      }
      {
        dir = ".nv/OptiXCache";
      }
    ];
    "gamedev.blender" = [
      {
        dir = ".config/blender";
        name = "blender";
        durable = true;
      }
    ];
    "games.epic" = [
      {
        dir = ".config/heroic";
        name = "heroic";
        durable = true;
      }
      {
        dir = ".config/legendary";
        name = "legendary";
        durable = true;
      }
      {
        dir = "Games/Heroic";
        name = "heroic-games";
        durable = true;
      }
    ];
    "chat.discord" = [
      {
        dir = ".config/discord";
        name = "discord";
        durable = true;
      }
      {
        dir = ".local/state/angst/discord-voice";
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
    "remote.stream" = [
      {
        dir = ".config/sunshine";
        name = "sunshine";
        durable = true;
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
