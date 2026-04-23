# Linux home-manager entrypoint.
#
# Intentionally minimal: the starting point for gradually migrating
# user-space on Arch (and other non-NixOS Linux hosts) to Nix. Each
# addition goes in with a reason, not by bulk-importing from Darwin.
{
  config,
  stateVersion,
  ...
}:
{
  imports = [
    ../../lib/noughty
  ];

  home = {
    inherit stateVersion;
    username = config.noughty.user.name;
    homeDirectory = "/home/${config.noughty.user.name}";
    sessionPath = [ "$HOME/.local/bin" ];
  };

  programs.home-manager.enable = true;

  programs.bash = {
    enable = true;
    package = null;
    enableCompletion = false;
    shellAliases = {
      ls = "ls --color=auto";
      grep = "grep --color=auto";
    };
    initExtra = ''
      eval "$(/usr/bin/starship init bash)"
      . /usr/share/nvm/init-nvm.sh
    '';
  };

  # Pattern 3 for starship: programs.starship would install nix's starship
  # alongside pacman's (its package option isn't nullable). Hand-wire it
  # instead — config file via xdg, init via bash.initExtra above.
  xdg.configFile."starship.toml".source = ./starship.toml;

  programs.ghostty = {
    enable = true;
    package = null;
    systemd.enable = false;
    settings = {
      theme = "catppuccin-mocha";
      font-size = 10;
      shell-integration = "detect";
      shell-integration-features = "cursor,sudo,title,path";
    };
  };
}
