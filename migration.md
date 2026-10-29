# Migration: mint → work

Mint box `mint` becomes NixOS host `work` (`hosts/personal/work`). Full wipe of `/dev/sda`. One-way.

Box: `i5-7400`, `Intel HD 630` + `NVIDIA GT 710 (legacy_470)`, `Realtek` ethernet only (no wifi), `sda 111,8G`, `15Gi` RAM, monitors `HDMI-0` + `VGA-0` at `1920x1080@60`, `br-abnt2`, `America/Sao_Paulo`.

Host: profiles `base desktop development design embedded game-dev office obs vpn` (no `gaming`), `toolchains = "*"`, theme `miasma`, persist root `/state` + dataRoot `/home/durable`; `secrets.password = "main"` uses the same flat pool entry as `nixos`.

## A. Pre-boot (on Mint)

```bash
just build work
```

Expect no output, exit 0. Full `nixos-system-work` closure builds (slow first time; `nvidia-kernel-modules-470` objtool warnings are normal).

```bash
rsync -a ~/projects ~/Documents ~/Pictures ~/.ssh ~/.secrets ~/ftp ~/proj ~/go /mnt/backup/mint-home/
ls /mnt/backup/mint-home/
```

External disk needs ~80G free (`/` currently 77G used).

```bash
cp ~/.config/age/keys.txt ~/.config/age/work-keys.txt /mnt-keys/
ls /mnt-keys/
```

Small USB stick, any FAT32. Keep this stick apart from backup disk.

```bash
git bundle create /mnt-keys/angst.bundle --all
```

Installer has none of your SSH keys; bundle carries the committed `hosts/personal/work` declaration.

Flash graphical NixOS ISO (25.11+) to a second USB stick. Plug ethernet cable (box has no wifi). Know your login: the `main` password; without the personal age key the fallback is `changeme`.

## B. Installer (NixOS ISO terminal)

```bash
ping -c2 cache.nixos.org
lsblk -o NAME,SIZE,TYPE,LABEL
ls /sys/firmware/efi
```

Need network ok, `sda 111,8G` present, efi dir exists. If efi missing, reboot in UEFI mode (not legacy/CSM).

```bash
sudo mount -o ro /dev/sdX1 /mnt-keys
ls /mnt-keys
```

Expect `keys.txt work-keys.txt angst.bundle`. Replace `sdX1` with keys-stick partition from `lsblk`.

```bash
git clone /mnt-keys/angst.bundle ~/angst && cd ~/angst
git log --oneline -1
ls hosts/personal/work/
```

Expect log `87100f7` (or newer `work` commit), files `default.nix hardware.nix`.

```bash
sudo nix --extra-experimental-features 'nix-command flakes' run .#install-nixos -- --full-disk --disk /dev/sda --flake .#work --identity /mnt-keys --state-size 30G --yes
```

You must type `/dev/sda` when prompted to confirm erasing it. This destroys Linux Mint and all data on that disk; there is no undo. `--yes` skips only the later `YES` prompt.

Made layout: `ESP 1G partlabel boot` + `swap 8G` + `state 30G` + `data rest`, labels `boot`/`swap`/`state`/`data`. Mounts `tmpfs /mnt`, `ESP→/mnt/boot`, `data→/mnt/home`, `state→/mnt/state`, bind `/mnt/home/nix→/mnt/nix`, durable `/mnt/home/durable`, keys seeded to `/mnt/home/durable/age/`. Then `nixos-install --flake .#work --impure`. Takes 10–40 min.

```bash
sudo umount /mnt-keys
sudo reboot
```

Unplug ISO + keys sticks during reboot.

## C. First boot (work)

systemd-boot menu → top `work` entry (hold Space at boot if menu hidden).

Login: user `joao`, `main` password. Keys missing → `changeme`; restore keys to `/home/durable/age/` (0600, owned `joao`) and reboot to apply `main`.

```bash
findmnt / /home /home/joao /state /nix
ls -la ~/.ssh/ ~/.config/age/ ~/.secrets/
nvidia-smi
xrandr --listmonitors
systemctl --failed
systemctl status angst-bootstrap-secrets angst-provision-ssh-key --no-pager
ls ~/projects/
```

Expect tmpfs `/` + `/home/joao`, `/state` + `/home` on disk, both `.age` keys, provisioned `id_ed25519` + `work_ed25519`, `~/.secrets/opencode-go-key` + `cursor-api-key`, GT 710 in `nvidia-smi`, 2 monitors, no failed units, projects cloned via scope keys on first `angst projects sync` (needs network + provider access).

Tune monitors if names differ from decl (`HDMI-0`/`VGA-0`): edit `hosts/personal/work/default.nix`, then:

```bash
sudo nixos-rebuild switch --flake .#work
```

i3 reads `monitors.conf` at session start — relog after switch. Compare real hardware:

```bash
sudo nixos-generate-config --show-hardware-config > /tmp/hw.nix
diff /tmp/hw.nix hosts/personal/work/hardware.nix
```

Merge anything missing (e.g. extra kernel modules), then switch again.

## D. Fix table

| Command | When |
|---|---|
| At boot menu press `e`, append `nomodeset`, boot | Black screen from Nvidia |
| Delete `services.xserver.videoDrivers` + `hardware.nvidia` block in `hosts/personal/work/default.nix`, then `sudo nixos-rebuild switch --flake .#work` | GT 710 driver fails (falls back to Intel HD 630) |
| `cp /mnt-keys/keys.txt /mnt-keys/work-keys.txt /home/durable/age/ && chmod 600 /home/durable/age/*.txt` | Booted on `changeme` fallback, no keys |
| Pick older generation in systemd-boot | Any bad switch, instant rollback |
| `journalctl -u angst-bootstrap-secrets --no-pager` | Only applies when the host declares `secrets.password` |
| `just build work` on Mint/live repo before reinstalling | Validate decl changes without touching running system |

Secrets rules: never commit `*.agekey`, `*.dec`, or plaintext passwords. Age identity lives at `/home/durable/age/keys.txt` (+ `work-keys.txt`), survives reinstalls on data partition. Details: `openwiki/secrets.md`. Install runbook: `openwiki/operations.md`.
