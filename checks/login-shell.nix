{
  self,
  pkgs,
}:

let
  invalidConfig = self.homeConfigurations.login-shell-invalid;

  valid =
    pkgs.writeText "login-shell-valid-check" "skipped (system paths not resolvable in pure eval)";

  invalid =
    let
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
