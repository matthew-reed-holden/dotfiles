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
    # Point SSH (and ssh-keygen, used by git for SSH commit signing) at
    # the 1Password agent socket. Without this set, git -S / ssh-add
    # can't find the agent despite ~/.ssh/config's IdentityAgent hint,
    # because ssh-keygen doesn't read ssh_config.
    sessionVariables.SSH_AUTH_SOCK = "$HOME/.1password/agent.sock";
  };

  programs.home-manager.enable = true;

  # Pattern 3 for zsh: programs.zsh.package isn't nullable (same trap as
  # starship), so hand-write .zsh{env,rc} to keep pacman's /usr/bin/zsh
  # authoritative.

  # .zshenv runs on every zsh invocation (login, non-login, interactive,
  # non-interactive). Home-manager normally wires session vars through
  # ~/.profile when programs.bash is enabled; with bash removed we have
  # to source hm-session-vars.sh ourselves or PATH / LOCALE_ARCHIVE are
  # missing in fresh shells.
  home.file.".zshenv".text = ''
    . ${config.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh
  '';

  home.file.".zshrc".text = ''
    # History — keeping ~/.histfile so existing command history persists.
    HISTFILE=~/.histfile
    HISTSIZE=1000
    SAVEHIST=1000

    bindkey -e

    # Completion (pacman's /usr/share/zsh/site-functions is on FPATH by default)
    autoload -Uz compinit
    compinit

    # NVM ships bash-style completion — enable bash-compat in zsh. Must
    # follow compinit.
    autoload -U +X bashcompinit
    bashcompinit

    alias ls='ls --color=auto'
    alias grep='grep --color=auto'

    # Ghostty shell integration (no-op outside ghostty)
    if [[ -n "''${GHOSTTY_RESOURCES_DIR}" ]]; then
      builtin source "''${GHOSTTY_RESOURCES_DIR}/shell-integration/zsh/ghostty-integration"
    fi

    # NVM (pacman 0.40.4 at /usr/share/nvm/)
    . /usr/share/nvm/init-nvm.sh

    eval "$(/usr/bin/starship init zsh)"

    # zsh-autosuggestions (pacman). Registers zle widgets used below.
    source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh

    # Catppuccin Mocha theme for syntax-highlighting — sets
    # ZSH_HIGHLIGHT_HIGHLIGHTERS and ZSH_HIGHLIGHT_STYLES. Must come
    # BEFORE the main plugin or the styles are ignored.
    source ${config.xdg.configHome}/zsh/catppuccin-mocha.zsh

    # zsh-syntax-highlighting (pacman). Per upstream docs this must be
    # the LAST thing sourced — it wraps every zle widget currently
    # defined.
    source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
  '';

  # Pattern 3 for starship: programs.starship would install nix's starship
  # alongside pacman's (its package option isn't nullable). Hand-wire it
  # instead — config file via xdg, init via .zshrc above.
  xdg.configFile."starship.toml".source = ./starship.toml;

  # Catppuccin Mocha theme for zsh-syntax-highlighting. The plugin
  # modules (programs.zsh.autosuggestion / .syntaxHighlighting) aren't
  # usable here: they're sub-options of programs.zsh (which we can't
  # enable without installing a duplicate zsh), hardcode nix packages,
  # and autosuggestion has no package option at all. Pattern 3 — drop
  # the theme into ~/.config/zsh/ and source it from .zshrc.
  xdg.configFile."zsh/catppuccin-mocha.zsh".source =
    ./zsh-syntax-highlighting-catppuccin-mocha.zsh;

  # Git — pattern 3 (programs.git.package isn't nullable). Identity,
  # modern defaults, and SSH commit signing via 1Password's agent using
  # id_github. HTTPS credential helper (1Password CLI) TBD — add when
  # the op:// path for a GitHub PAT is confirmed.
  xdg.configFile."git/config".source = ./gitconfig;

  # Allowed signers for `git log --show-signature` verification.
  xdg.configFile."git/allowed_signers".source = ./git-allowed-signers;

  programs.ghostty = {
    enable = true;
    package = null;
    systemd.enable = false;
    settings = {
      theme = "Catppuccin Mocha";
      font-size = 10;
      shell-integration = "detect";
      shell-integration-features = "cursor,sudo,title,path";
    };
  };
}
