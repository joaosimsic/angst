{ ... }: {
  imports = [ ../toolchains ];
  domains.shell.nushell.enable = true;
  domains.shell.starship.enable = true;
  domains.terminal.zellij.enable = true;
  domains.editor.nvim.enable = true;
  domains.files.yazi.enable = true;
  domains.sql-client.sqlit.enable = true;
  domains.http-client.posting.enable = true;
}
