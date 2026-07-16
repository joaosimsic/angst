{ ... }: {
  imports = [ ../toolchains ];
  domains = {
    shell.nushell.enable = true;
    shell.starship.enable = true;
    terminal.zellij.enable = true;
    llm.opencode.enable = true;
    llm.cursor-cli.enable = true;
    editor.nvim.enable = true;
    files.yazi.enable = true;
    sql-client.sqlit.enable = true;
    http-client.posting.enable = true;
    git.lazygit.enable = true;
  };
}
