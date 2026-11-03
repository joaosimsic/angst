# secrets/ stub

Placeholder layout only. No values. No ciphertext. No behavior.

Mirrors old shape for future `systems/secrets` owner:
- `secrets/passwd/` per-host master material
- `secrets/apps/<scope>/<slug>` app slugs
- `secrets/ssh/` scope keys

Files here end in `.placeholder` and hold only
`PLACEHOLDER-DO-NOT-USE`. Later `.age` (values stay encrypted) plus `.pub`.
Inventory rule: `infra/contracts/secret-ref/default.nix` reads basenames only
(`builtins.readDir`, presence-only, values never read). A `SecretRef { ref }`
resolves iff `ref` names a file here. Provisioning lives in future
`systems/secrets`, not here.
