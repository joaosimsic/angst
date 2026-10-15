# Persistence policy. Each feature declares the paths it owns; only features
# that are actually enabled contribute. Hosts declare no dirs themselves.
#
# Durable entries land on `persist.dataRoot` (bind mount) when the host sets
# one, and fall back to the impermanence root otherwise. Entries without
# `durable` always go to the impermanence root.
#
# `name` is the directory under `persist.dataRoot` that backs the bind mount.
{
  features = {
    "agents.opencode" = [
      {
        dir = ".local/share/opencode";
        name = "opencode";
        durable = true;
      }
      {
        dir = ".cache/opencode";
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
      # Fontconfig's cache otherwise lives in tmpfs `~/.cache` and is rebuilt
      # by the first font client after every boot — rofi feels laggy there.
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
