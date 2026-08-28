{
  mkScript,
  angstCli,
 ...
}:
mkScript {
  name = "angst-render";
  text = ''
    exec ${angstCli.bin} render "$@"
  '';
}
