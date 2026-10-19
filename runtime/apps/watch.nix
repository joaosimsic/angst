{
  mkScript,
  angstCli,
}:
mkScript {
  name = "angst-watch";
  text = ''
    exec ${angstCli.bin} watch "$@"
  '';
}
