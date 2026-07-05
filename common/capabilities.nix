{ ... }: {
  services.fstrim.enable = true;
  zramSwap.enable = true;

  capabilities.network.enable = true;
  capabilities.git.enable = true;
  capabilities.search.enable = true;
  capabilities.monitoring.enable = true;
  capabilities.container.enable = true;
}
