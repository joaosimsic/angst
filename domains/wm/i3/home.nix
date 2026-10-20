{
  config,
  lib,
  pkgs,
  store,
  ...
}:

let
  cfg = config.domains.wm.i3;

  swapScript = pkgs.writeShellApplication {
    name = "i3-swap-workspaces";
    runtimeInputs = [
      pkgs.i3
      pkgs.python3
    ];
    text = ''
      exec python3 - "$@" <<'PY'
      import json
      import subprocess
      import sys


      def i3(*args):
          return subprocess.run(["i3-msg", *args], capture_output=True, text=True)


      def i3_cmd(cmd, dry):
          if dry:
              print(cmd)
              return True
          proc = i3(cmd)
          out = proc.stdout.strip()
          ok = proc.returncode == 0
          if ok and out.startswith("["):
              try:
                  ok = all(bool(entry.get("success")) for entry in json.loads(out))
              except ValueError:
                  ok = False
          if not ok:
              print(f"i3-msg failed: {cmd}\n{out}", file=sys.stderr)
          return ok


      def direct_children(ws, key):
          if not ws:
              return []
          return [c["id"] for c in (ws.get(key) or [])]


      def main():
          args = sys.argv[1:]
          dry = "--dry-run" in args
          args = [a for a in args if a != "--dry-run"]
          a = int(args[0]) if len(args) > 0 else 1
          b = int(args[1]) if len(args) > 1 else 2

          proc = i3("-t", "get_tree")
          if proc.returncode != 0:
              print(proc.stderr, file=sys.stderr)
              sys.exit(1)
          tree = json.loads(proc.stdout)

          found = {}

          def walk(node):
              if node.get("type") == "workspace" and node.get("num") in (a, b):
                  found[node["num"]] = node
              for child in node.get("nodes", []) + node.get("floating_nodes", []):
                  walk(child)

          walk(tree)
          ws_a = found.get(a)
          ws_b = found.get(b)

          tiling_a = direct_children(ws_a, "nodes")
          tiling_b = direct_children(ws_b, "nodes")

          ok = True
          for x, y in zip(tiling_a, tiling_b):
              ok &= i3_cmd(f"[con_id={x}] swap container with con_id {y}", dry)
          for x in tiling_a[len(tiling_b):]:
              ok &= i3_cmd(f"[con_id={x}] move container to workspace number {b}", dry)
          for y in tiling_b[len(tiling_a):]:
              ok &= i3_cmd(f"[con_id={y}] move container to workspace number {a}", dry)
          for x in direct_children(ws_a, "floating_nodes"):
              ok &= i3_cmd(f"[con_id={x}] move container to workspace number {b}", dry)
          for y in direct_children(ws_b, "floating_nodes"):
              ok &= i3_cmd(f"[con_id={y}] move container to workspace number {a}", dry)
          sys.exit(0 if ok else 1)


      main()
      PY
    '';
  };
  cap = config.domains.capture.screenshot or { enable = false; };
  notif = config.domains.notifications or { enable = false; };
  audio = config.domains.kernel.audio or { enable = false; };
  player = config.domains.media.celluloid or { enable = false; };
  inherit (store) hasX11 hasNotifications;
  shouldBind = cfg.enable && (cap.enable or false) && hasX11;
  shouldBindNotif = cfg.enable && (notif.enable or false) && hasX11 && hasNotifications;
  shouldBindAudio = cfg.enable && (audio.enable or false) && hasX11;
  shouldBindPlayer = cfg.enable && (player.enable or false) && hasX11;
in
{
  config = lib.mkIf cfg.enable {
    home.packages = [ swapScript ];

    xdg.configFile = {
      "i3/screenshot.conf".text = lib.mkDefault (
        if shouldBind then
          ''
            bindsym Print exec --no-startup-id angst-screenshot-save fullscreen
            bindsym Shift+Print exec --no-startup-id angst-screenshot-copy region
            bindsym $mod+Shift+s exec --no-startup-id angst-screenshot-copy region
            bindsym $mod+Print exec --no-startup-id angst-screenshot-save window
          ''
        else
          ""
      );

      "i3/notifications.conf".text = lib.mkDefault (
        if shouldBindNotif then
          ''
            bindsym $mod+Shift+n exec --no-startup-id angst-notify dismiss
            bindsym $mod+Shift+m exec --no-startup-id angst-notify dismiss-all
            bindsym $mod+Control+n exec --no-startup-id angst-notify history
          ''
        else
          ""
      );

      "i3/audio.conf".text = lib.mkDefault (
        if shouldBindAudio then
          ''
            bindsym XF86AudioRaiseVolume exec --no-startup-id wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+
            bindsym XF86AudioLowerVolume exec --no-startup-id wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
            bindsym XF86AudioMute exec --no-startup-id wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
            bindsym XF86AudioMicMute exec --no-startup-id wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
            bindsym $mod+plus exec --no-startup-id wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+
            bindsym $mod+minus exec --no-startup-id wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
            bindsym $mod+m exec --no-startup-id wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
          ''
        else
          ""
      );

      "i3/media.conf".text = lib.mkDefault (
        if shouldBindPlayer then
          ''
            bindsym XF86AudioPlay exec --no-startup-id playerctl play-pause
            bindsym XF86AudioPause exec --no-startup-id playerctl play-pause
            bindsym XF86AudioStop exec --no-startup-id playerctl stop
            bindsym XF86AudioNext exec --no-startup-id playerctl next
            bindsym XF86AudioPrev exec --no-startup-id playerctl previous
            bindsym $mod+Control+space exec --no-startup-id playerctl play-pause
          ''
        else
          ""
      );
    };

    assertions = [
      {
        assertion = !shouldBind || config.domains.kernel.graphical.enable;
        message = "domains.wm.i3 screenshot bindings require domains.kernel.graphical to be enabled";
      }
      {
        assertion = !shouldBindNotif || config.domains.kernel.graphical.enable;
        message = "domains.wm.i3 notification bindings require domains.kernel.graphical to be enabled";
      }
      {
        assertion = !shouldBindAudio || config.domains.kernel.graphical.enable;
        message = "domains.wm.i3 audio bindings require domains.kernel.graphical to be enabled";
      }
      {
        assertion = !shouldBindPlayer || config.domains.kernel.graphical.enable;
        message = "domains.wm.i3 media bindings require domains.kernel.graphical to be enabled";
      }
    ];
  };
}
