1: # angst — Pure Flake Architecture
2: 
3: angst is a fully pure Nix flake. No `--impure`, no env vars, no gitignored config files. Every command is deterministic: same commit → same system. Machines are disposable — clone the repo and build.
4: 
5: ## Philosophy
6: 
7: **Disposability.** A host is a directory in git. Wipe the disk, reinstall NixOS, `nixos-rebuild switch --flake .#nixos`, and you're back where you were. Nothing lives outside the repo except for the SSH key (identity) and browser profiles (convenience). Even those are deliberate, declared, and re-bindable.
8: 
9: **Purity.** The flake is a function of `git ls-files` only. `builtins.getEnv`, `builtins.currentTime`, and friends return nothing. `nix flake check` works bare. `nixos-rebuild list-generations` and `--rollback` are reliable. CI Just Works.
10: 
11: **Tracked config, encrypted secrets.** Machine identity (hostname, username, theme, profiles, monitors, toolchains) lives in plain Nix in `hosts/<hostname>/default.nix` — version-controlled, diffable, reviewable. Secrets (master password, DB credentials, API tokens) live in a shared `hosts/secrets.yaml` — sops-encrypted, decrypted at activation via the user's SSH key.
12: 
13: **Zero ceremony.** Adding a machine is `mkdir hosts/<name>` + write `default.nix`. The flake auto-discovers hosts. No flake.nix edits, no `--override-input`, no env vars. Commands are bare:
14: 
15: ```bash
16: sudo nixos-rebuild switch --flake .#nixos
17: home-manager switch --flake .#joao@nixos
18: home-manager switch --flake .#joao@linux
19: nix flake check
20: nix develop
21: nix run .#vm -- --host nixos start
22: ```
23: 
24: ## Directory structure
25: 
26: ```
27: angst/
28: ├── flake.nix                   # auto-discovers hosts/ directory
29: ├── hosts/
30: │   ├── secrets.yaml            # shared sops secrets, encrypted to all hosts
31: │   ├── nixos/                  # NixOS host
32: │   │   ├── default.nix         #   machine identity (tracked, plain text)
33: │   │   ├── hardware.nix        #   nixos-generate-config output (tracked)
34: │   │   └── disk.nix            #   disko layout (optional, tracked)
35: │   ├── linux/                  # non-NixOS (home-manager) host
36: │   │   └── default.nix
37: │   └── ci/                     # CI test host (minimal, no secrets)
38: │       └── default.nix
39: ├── lib/
40: │   ├── read-config.nix         # pure function: config attrset → cfg
41: │   ├── flake/outputs.nix       # iterates hosts → nixosConfigurations + homeConfigurations
42: │   └── build/
43: │       ├── mkNixos.nix         # NixOS system builder (impermanence, sops, hardware)
44: │       └── mkHome.nix          # home-manager builder (sops)
45: ├── profiles/                   # composable profile sets (base, desktop, server, vm, etc.)
46: ├── toolchains/                 # auto-discovered toolchain definitions
47: ├── domains/                    # auto-discovered application domain modules
48: ├── themes/                     # auto-discovered theme definitions
49: └── .sops.yaml                  # age public keys (one per machine)
50: ```
51: 
52: One shared `hosts/secrets.yaml` for all hosts. A host can override by adding its own `hosts/<hostname>/secrets.yaml`, which takes precedence over the shared file. Per-host secrets files are optional — most hosts share the same secrets.
53: 
54: ## How it works
55: 
56: ### Host auto-discovery
57: 
58: `flake.nix` scans `hosts/` with `builtins.readDir`. Every subdirectory is a host (files like `secrets.yaml` are skipped — only directories count). The host's `default.nix` is imported, enriched by `lib/read-config.nix` (defaults, domain scanning, toolchain resolution, theme indexing), and passed to `lib/flake/outputs.nix`, which builds `nixosConfigurations.<hostname>` for NixOS hosts and `homeConfigurations.<user>@<hostname>` for all hosts.
59: 
60: Adding a machine:
61: 
62: ```bash
63: mkdir hosts/laptop
64: cp hosts/nixos/default.nix hosts/laptop/default.nix
65: # edit hosts/laptop/default.nix — change hostname, monitors, profiles, etc.
66: # create hosts/laptop/hardware.nix (nixos-generate-config)
67: git add hosts/laptop
68: ```
69: 
70: No flake.nix edits. The new host appears in `nixosConfigurations.laptop`.
71: 
72: ### Config → cfg pipeline
73: 
74: ```
75: hosts/<hostname>/default.nix  (plain Nix attrset, tracked)
76:     │
77:     ▼
78: lib/read-config.nix           (pure function)
79:     │  applies defaults
80:     │  scans domains/ themes/ toolchains/
81:     │  resolves profiles
82:     │
83:     ▼
84: cfg                            (enriched attrset)
85:     │
86:     ├──► mkNixos.nix  →  nixosConfigurations.<hostname>
87:     └──► mkHome.nix   →  homeConfigurations.<user>@<hostname>
88: ```
89: 
90: `read-config.nix` is completely pure — it takes a config attrset and returns enriched cfg. No `builtins.getEnv`, no `builtins.currentTime`, no filesystem reads outside the flake source.
91: 
92: ### Secrets with sops-nix
93: 
94: Secrets live in a shared `hosts/secrets.yaml`, encrypted to every machine's age key. A host-specific `hosts/<hostname>/secrets.yaml` can override the shared file (takes precedence if present). Otherwise, all hosts read from `hosts/secrets.yaml`.
95: 
96: Decryption key: the user's `~/.ssh/id_ed25519` on every machine. Each machine generates its own key, but all keys share the same passphrase — the master password stored in the secrets file. `ssh-to-age` derives an age public key from the SSH key's public half.
97: 
98: |                 | NixOS                       | non-NixOS                  |
99: |-----------------|-----------------------------|----------------------------|
100: | Source          | `~/.ssh/id_ed25519`         | `~/.ssh/id_ed25519`        |
101: | Conversion      | `ssh-to-age`                | `ssh-to-age`               |
102: | Generated by    | User, per machine           | User, per machine          |
103: | Passphrase      | Master password (same everywhere)      |
104: | Survives rebuilds | Yes (on `/persist`)        | Yes (host OS manages)      |
105: 
106: On NixOS, activation copies `~/.ssh/id_ed25519` to `/persist/etc/ssh/ssh_host_ed25519`, so the same key serves as both user identity and server host identity. One key, one passphrase, everywhere.
107: 
108: Encryption model:
109: 
110: ```
111: hosts/secrets.yaml  (single file)
112:     │ encrypted to:
113:     ├── age1...aaa   (desktop)
114:     ├── age1...bbb   (laptop)
115:     └── age1...ccc   (server)
116: ```
117: 
118: `.sops.yaml` lists all age keys. Adding a machine means appending its key and running `sops updatekeys`. Removing a machine means deleting its key line and running `sops updatekeys` — that key can no longer decrypt.
119: 
120: ### SSH key enforcement at activation
121: 
122: On every `switch`, after sops decrypts the master password, home-manager activation scripts verify and enforce:
123: 
124: 1. **Key exists.** `~/.ssh/id_ed25519` must exist. If missing, activation warns — the user must run bootstrap on this machine.
125: 
126: 2. **Passphrase matches.** `ssh-keygen -y -P "$password" -f ~/.ssh/id_ed25519` must succeed. If the key has no passphrase or a different one, activation sets it with `ssh-keygen -p`. This means changing the master password in `hosts/secrets.yaml` and switching applies the new passphrase to every machine's key.
127: 
128: 3. **NixOS: host key matches.** If `/persist/etc/ssh/ssh_host_ed25519` content differs from `~/.ssh/id_ed25519`, activation copies the user key into place.
129: 
130: ### Opt-in impermanence
131: 
132: NixOS hosts can declare `persist.enable = true` to run on tmpfs `/`. The root filesystem is wiped on every reboot. Only explicitly declared paths survive:
133: 
134: ```
135: /           (tmpfs, wiped on reboot)
136: /nix        (persistent partition — binary cache, no recompilation)
137: /boot       (persistent partition)
138: /persist    (persistent partition — deliberate state)
139:     ├── etc/ssh/                host identity + sops key
140:     ├── etc/machine-id          stable machine ID
141:     └── home/<user>/
142:         ├── .mozilla/           Firefox sessions, cookies, accounts
143:         ├── .config/google-chrome/  Chromium
144:         └── .local/share/keyrings/   libsecret passwords
145: ```
146: 
147: Hosts with `persist.enable = false` use conventional filesystems. Non-NixOS hosts (`type = "home-manager"`) don't get impermanence at all — the host OS manages the filesystem.
148: 
149: ## Host config reference
150: 
151: ### `hosts/<hostname>/default.nix` (NixOS)
152: 
153: ```nix
154: {
155:   type = "nixos";          # "nixos" | "home-manager"
156:   system = "x86_64-linux";
157:   hostname = "nixos";
158:   username = "joao";
159:   theme = "miasma";
160:   profiles = ["base" "desktop" "development"];
161:   toolchains = "*";          # "*" for all, or ["bash" "nix" "php"] for minimal
162:   repoPath = "proj/angst";   # relative path from $HOME to this checkout
163: 
164:   monitors = {
165:     primary = {
166:       name = "DP-1";
167:       resolution = "1920x1080";
168:       refreshRate = 144;
169:       position = "0x0";
170:     };
171:   };
172: 
173:   db.connections = { };
174:   nixos = { keyboardLayout = "br-abnt2"; };
175:   home = { };
176:   env = { EDITOR = "nvim"; BROWSER = "firefox"; };
177:   shell = "";               # login shell name ("" = skip validation)
178: 
179:   sshAgent = {
180:     enable = true;
181:     keys = ["~/.ssh/id_ed25519"];
182:   };
183:   ssh = { };
184: 
185:   # Only meaningful for type = "nixos"
186:   persist = {
187:     enable = true;           # false → conventional filesystem
188:     root = "/persist";
189:     homeDirs = [
190:       ".mozilla"
191:       ".config/google-chrome"
192:       ".local/share/keyrings"
193:     ];
194:   };
195: }
196: ```
197: 
198: ### `hosts/<hostname>/default.nix` (home-manager)
199: 
200: ```nix
201: {
202:   type = "home-manager";      # produces only homeConfigurations
203:   system = "x86_64-linux";
204:   hostname = "linux";
205:   username = "joao";
206:   theme = "miasma";
207:   profiles = ["base" "desktop" "development"];
208:   toolchains = "*";
209:   repoPath = "proj/angst";
210: 
211:   monitors = { };             # safe to leave empty — i3 auto-detects
212: 
213:   db.connections = { };
214:   home = { };
215:   env = { EDITOR = "nvim"; BROWSER = "firefox"; };
216:   shell = "";
217: 
218:   sshAgent = {
219:     enable = true;
220:     keys = ["~/.ssh/id_ed25519"];
221:   };
222:   ssh = { };
223: 
224:   # No persist, nixos, hardware.nix, disk.nix — those are NixOS-only.
225: }
226: ```
227: 
228: ### `hosts/secrets.yaml`
229: 
230: Shared secrets, encrypted to all hosts via sops.
231: 
232: ```yaml
233: password: "master-password"       # plaintext — SSH passphrase + system login
234: db:
235:   connections:
236:     dev:
237:       password: "db-password"
238: env:
239:   GITHUB_TOKEN: "ghp_..."
240: ```
241: 
242: The `password` field is the master password: used as the SSH key passphrase and as the system login password. For NixOS, a SHA-512 hash is derived at activation time (`mkpasswd -m sha-512 "$password"`) so it never appears as plaintext in a config file.
243: 
244: ## Bootstrap (one-time per machine)
245: 
246: ```bash
247: # 1. Generate SSH key with the master password as passphrase
248: ssh-keygen -t ed25519 -N "<master-passwd>" -f ~/.ssh/id_ed25519
249: 
250: # 2. Derive age key and enroll this machine in sops
251: ssh-to-age < ~/.ssh/id_ed25519.pub
252: # → prints: age1...unique-to-this-machine
253: 
254: # Add the age key to .sops.yaml, then re-encrypt secrets to include it
255: sops updatekeys hosts/secrets.yaml
256: git add .sops.yaml && git commit -m "enroll <hostname> in secrets"
257: 
258: # 3. Unlock key for this session and apply
259: ssh-add ~/.ssh/id_ed25519
260: home-manager switch --flake .#joao@<hostname>      # non-NixOS
261: sudo nixos-rebuild switch --flake .#<hostname>     # NixOS
262: ```
263: 
264: On NixOS, the first `switch` copies `~/.ssh/id_ed25519` to `/persist/etc/ssh/ssh_host_ed25519`, so sshd and sops-nix use the same identity.
265: 
266: After bootstrap: no ceremony. `nixos-rebuild switch` or `home-manager switch` encrypts, deploys, and verifies the SSH key automatically.
267: 
268: ## Non-NixOS (home-manager) hosts
269: 
270: Home-manager hosts have `type = "home-manager"` and produce only `homeConfigurations."<user>@<hostname>"`. They share the same profiles, toolchains, theme, domains, and secrets as NixOS hosts.
271: 
272: Fields and files ignored for home-manager hosts:
273: 
274: - `persist` — the host OS manages the filesystem
275: - `nixos` — NixOS-specific system config (keyboard layout, etc.)
276: - `hardware.nix`, `disk.nix` — NixOS hardware declaration
277: 
278: All non-NixOS distros are treated identically — Arch, Debian, Mint, Fedora, etc. The host OS manages the kernel, drivers, and system packages. home-manager manages user configuration, dotfiles, toolchains, and secrets. Prerequisites on the host:
279: 
280: - Nix (any installation method: official installer, nix-portable, distro package)
281: - home-manager (via nix or as a standalone)
282: - `~/.ssh/id_ed25519` (generated during bootstrap)
283: 
284: ## Everyday usage
285: 
286: ```bash
287: # Apply changes
288: sudo nixos-rebuild switch --flake .#nixos
289: home-manager switch --flake .#joao@nixos
290: home-manager switch --flake .#joao@linux
291: 
292: # Update flake inputs
293: nix flake update
294: sudo nixos-rebuild switch --flake .#nixos
295: 
296: # Run checks
297: nix flake check
298: 
299: # VM testing
300: nix run .#vm -- start          # uses NIX_DEFAULT_TARGET_HOST
301: NIX_DEFAULT_TARGET_HOST=thonkpad nix run .#vm -- start
302: 
303: # Dev shell (neovim, all toolchains, vm tools)
304: nix develop
305: 
306: # Minimal safe shell (neovim + toolchains, no qemu/ssh agent)
307: nix develop .#safe
308: 
309: # Domain config rendering
310: angst render --host nixos
311: angst watch   --host nixos
312: ```
313: 
314: ## Rekeying secrets
315: 
316: `.sops.yaml` is the authoritative list of which machines can decrypt:
317: 
318: ```yaml
319: creation_rules:
320:   - path_regex: hosts/.*/secrets\.yaml$
321:     age: |
322:       age1...   # desktop
323:       age1...   # laptop
324:       age1...   # server
325: ```
326: 
327: **Add a machine:**
328: 
329: ```bash
330: # On the new machine:
331: ssh-keygen -t ed25519 -N "<master-passwd>" -f ~/.ssh/id_ed25519
332: ssh-to-age < ~/.ssh/id_ed25519.pub
333: # Append the age key to .sops.yaml
334: sops updatekeys hosts/secrets.yaml
335: git commit -am "enroll <hostname>"
336: ```
337: 
338: **Remove a machine:**
339: 
340: ```bash
341: # Remove its age1... line from .sops.yaml
342: sops updatekeys hosts/secrets.yaml
343: git commit -am "revoke <hostname>"
344: ```
345: 
346: **Rotate a machine's key:**
347: 
348: ```bash
349: # Regenerate key on the machine (or change passphrase with ssh-keygen -p)
350: ssh-keygen -t ed25519 -N "<master-passwd>" -f ~/.ssh/id_ed25519
351: ssh-to-age < ~/.ssh/id_ed25519.pub
352: # Replace old age1... line in .sops.yaml with new one
353: sops updatekeys hosts/secrets.yaml
354: git commit -am "rotate <hostname> key"
355: ```
356: 
357: `sops updatekeys` re-encrypts the data key to exactly the keys listed in `.sops.yaml`. Removed keys can no longer decrypt.
358: 
359: ## CI
360: 
361: CI uses the `hosts/ci/` host — a minimal NixOS config with one toolchain, base profile, no secrets. No `cp local/config.nix.example` step needed. The flake evaluates purely and deterministically.
362: 
363: ## Design constraints
364: 
365: - **`read-config.nix` is pure.** It takes config, returns cfg. No side effects, no env reads, no filesystem access outside the flake source.
366: - **Host config is tracked in git.** Machine identity is version-controlled. Changing your theme or adding a profile is a commit.
367: - **Secrets are encrypted, not hidden.** sops-encrypted files are safe to track. Decryption happens at activation, never at eval time.
368: - **One key, one password, all hosts.** Every machine generates its own `~/.ssh/id_ed25519` with the same master password. sops encrypts to all of them. Changing the password in secrets propagates to every machine's key passphrase at next switch.
369: - **The flake is a closed function.** Every input comes from git. Nothing depends on CWD, env vars, or which machine you're on. This is what makes `nix flake check` work, rollback reliable, and CI deterministic.
370: - **Hosts auto-discoverable.** `builtins.readDir` means new hosts appear without touching `flake.nix`. No registration, no boilerplate.
371: - **Non-NixOS hosts are first-class.** `type = "home-manager"` hosts get the same structure, same secrets decryption, same outputs. They just don't get hardware config or impermanence.
372: - **SSH key enforced declaratively.** Activation scripts verify key existence, passphrase match, and host key parity. What git says, the machine becomes.
373: 