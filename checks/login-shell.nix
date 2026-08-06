{
  self,
  cfg,
  pkgs,
}:

# The login-shell build-time validation uses `builtins.pathExists` against real
# filesystem paths, which only works under `--impure` eval (pathExists returns
# false for system paths in pure eval). These checks evaluate the test home
# configurations and assert the expected outcome.
#
# - Under pure eval (plain `nix flake check`) the pathExists-based assertion
#   cannot distinguish valid from invalid shells, so the valid case is skipped.
#   Run `nix flake check --impure` (the repo's `check` app does this) to fully
#   verify.
let
  pureEval = builtins.getEnv "PWD" == "";

  validConfig = self.homeConfigurations.login-shell-valid;
  invalidConfig = self.homeConfigurations.login-shell-invalid;

  valid = let
    res = builtins.tryEval validConfig.config.assertions;
  in
  if pureEval then
    pkgs.writeText "login-shell-valid-check" "skipped (pure eval; run with --impure)"
  else if res.success then
    pkgs.writeText "login-shell-valid-check" "ok"
  else
    throw "expected shell 'sh' to pass login-shell validation, got: ${builtins.toJSON res.value}";

  invalid = let
    res = builtins.tryEval invalidConfig.config.assertions;
  in
  if res.success then
    throw "expected shell '__angst_nonexistent_shell__' to fail login-shell validation"
  else
    pkgs.writeText "login-shell-invalid-check" "ok";
in
{
  inherit valid invalid;
}
