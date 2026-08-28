{
  mkScript,
  pkgs,
  goAngst,
 ...
}:
{
  username,
  agePath,
  ageKey,
}:
mkScript {
  name = "angst-bootstrap-secrets";
  runtimeInputs = with pkgs; [
    coreutils
    mkpasswd
    shadow
    age
  ];
  text = ''
    exec ${goAngst}/bin/angst set-password-hash --username "${username}" --age-path "${agePath}" --age-key "${ageKey}"
  '';
}
