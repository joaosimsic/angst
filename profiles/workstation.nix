{ pkgs, domains, ... }:

{
  imports = [
    domains.terminal.ghostty
  ]
}
