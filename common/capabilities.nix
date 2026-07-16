_: {
  services.fstrim.enable = true;
  zramSwap.enable = true;

  capabilities = {
    network.enable = true;
    git.enable = true;
    search.enable = true;
    monitoring.enable = true;
    container.enable = true;
  };
}
