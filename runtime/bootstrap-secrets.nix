{
  mkScript,
  pkgs,
  goAngst,
}:
{
  username,
  sopsPath,
}:
mkScript {
  name = "angst-bootstrap-secrets";
  runtimeInputs = with pkgs; [
    coreutils
    mkpasswd
    shadow
  ];
  text = ''
    exec ${goAngst}/bin/angst set-password-hash --username "${username}" --sops-path "${sopsPath}"
  '';
}