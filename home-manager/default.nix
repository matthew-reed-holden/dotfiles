{
  config,
  inputs,
  isWorkstation,
  lib,
  outputs,
  pkgs,
  stateVersion,
  username,
  ...
}:
let
  inherit (pkgs.stdenv) isDarwin isLinux;
in
{
  imports = [
    inputs.catppuccin.homeModules.catppuccin
    inputs.nix-index-database.hmModules.nix-index
  ];

  xdg.enable = true;
  xdg.configHome = "/Users/holdem3/.config";

  catppuccin = {
    accent = "blue";
    flavor = "mocha";
    alacritty.enable = config.programs.alacritty.enable;
    bat.enable = config.programs.bat.enable;
    fish.enable = config.programs.fish.enable;
    fzf.enable = config.programs.fzf.enable;
    gh-dash.enable = config.programs.gh.extensions.gh-dash;
    kitty.enable = true;
    micro.enable = config.programs.micro.enable;
    starship.enable = config.programs.starship.enable;
    yazi.enable = config.programs.yazi.enable;
  };


  home = {
    inherit stateVersion;
    inherit username;

    enableNixpkgsReleaseCheck = true;

    homeDirectory = if isDarwin then "/Users/${username}" else "/home/${username}";
    

    file = {
      "${config.xdg.configHome}/fastfetch/config.jsonc".text =
        builtins.readFile ./_mixins/configs/fastfetch.jsonc;
      "${config.xdg.configHome}/borders/bordersrc".text = builtins.readFile ./_mixins/configs/bordersrc;
      "${config.xdg.configHome}/aerospace/aerospace.toml".text =
        builtins.readFile ./_mixins/configs/aerospace.toml;
      "${config.xdg.configHome}/yazi/keymap.toml".text =
        builtins.readFile ./_mixins/configs/yazi-keymap.toml;
      "${config.xdg.configHome}/ghostty/config".text = builtins.readFile ./_mixins/configs/ghostty-config;
      ".hidden".text = ''snap'';
    };

    preferXdgDirectories = true;

    packages =
      with pkgs;
      [
        cpufetch # Terminal CPU info
        fastfetch # Modern Unix system info
        ipfetch # Terminal IP info
        onefetch # Terminal git project info
        micro
        rustmission # Modern Unix Transmission client
        rsync # Copy files in style
        starship # Blazing fast rust powered shell prompt
      ]
      ++ lib.optionals isLinux [
        ramfetch
      ]
      ++ lib.optionals isDarwin [
        m-cli
        nh
        coreutils
      ];
    sessionVariables = {
      EDITOR = "nvim";
      SYSTEMD_EDITOR = "nvim";
      VISUAL = "nvim";
    };
  };

  fonts.fontconfig.enable = true;

  # Workaround home-manager bug
  # - https://github.com/nix-community/home-manager/issues/2033
  news = {
    display = "silent";
    entries = lib.mkForce [ ];
  };

  nixpkgs = {
    overlays = [
      # Add overlays your own flake exports (from overlays and pkgs dir):
      outputs.overlays.additions
      outputs.overlays.modifications
      outputs.overlays.unstable-packages
    ];
    config = {
      allowUnfree = true;
    };
  };

  nix = {
    package = pkgs.nixVersions.latest;
  };

  programs = {
    alacritty = {
      enable = true;
    };

    bat = {
      enable = true;
      config = {
        style = "plain";
      };
    };

    dircolors = {
      enable = true;
      enableBashIntegration = true;
      enableFishIntegration = true;
      enableZshIntegration = true;
    };

    direnv = {
      enable = true;
      enableZshIntegration = true;
      nix-direnv.enable = true;
    };

    eza = {
      enable = true;
      enableBashIntegration = true;
      enableFishIntegration = true;
      enableZshIntegration = true;
      extraOptions = [
        "--group-directories-first"
        "--header"
      ];
      git = true;
      icons = "auto";
    };

    fd = {
      enable = true;
    };

    fzf = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;
      enableFishIntegration = true;
    };

    gh = {
      enable = true;
      extensions = with pkgs; [
        gh-dash
        gh-markdown-preview
      ];
      settings = {
        editor = "micro";
        git_protocol = "ssh";
        prompt = "enabled";
      };
    };

    home-manager.enable = true;

    jq.enable = true;

    kitty = {
      enable = true;
      shellIntegration.enableZshIntegration = true;
      font = {
        name = "Fira Code Mono";
        package = pkgs.nerd-fonts.fira-code;
        size = 10;
      };
      keybindings = {
        "kitty_mod+l" = "next_tab";
        "kitty_mod+h" = "previous_tab";
        "kitty_mod+m" = "toggle_layout stack";
        "kitty_mod+z" = "toggle_layout stack";
        "kitty_mod+enter" = "launch --location=split --cwd=current";
        "kitty_mod+v" = "launch --location=vsplit --cwd=current";
        "kitty_mod+minus" = "launch --location=hsplit --cwd=currentt";
        "kitty_mod+left" = "neighboring_window left";
        "kitty_mod+right" = "neighboring_window right";
        "kitty_mod+up" = "neighboring_window up";
        "kitty_mod+down" = "neighboring_window down";
        "kitty_mod+r" = "show_scrollback";
      };
      settings = {
        cursor_trail = 3;
        cursor = "none";
        kitty_mod = "cmd+shift";
        scrollback_lines = 10000;
        touch_scroll_multiplier = 2.0;
        copy_on_select = true;
        enable_audio_bell = false;
        remember_window_size = true;
        initial_window_width = 1600;
        initial_window_height = 1000;
        hide_window_decorations = true;
        tab_bar_style = "powerline";
        tab_separator = " ";
        enabled_layouts = "Splits,Stack";
        dynamic_background_opacity = true;
        tab_title_template = "{title}{fmt.bold}{'  ' if num_windows > 1 and layout_name == 'stack' else ''}";
      };
    };

    kubecolor = {
      enable = true;
      enableAlias = true;
    };

    lazygit = {
      enable = true;
    };

    nix-index.enable = true;

    ripgrep = {
      arguments = [
        "--colors=line:style:bold"
        "--max-columns-preview"
        "--smart-case"
      ];
      enable = true;
    };

    starship = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;
      # https://github.com/etrigan63/Catppuccin-starship
    };

    yazi = {
      enable = true;
      enableBashIntegration = true;
      enableFishIntegration = true;
      enableZshIntegration = true;
      settings = {
        manager = {
          show_hidden = false;
          show_symlink = true;
          sort_by = "natural";
          sort_dir_first = true;
          sort_sensitive = false;
          sort_reverse = false;
        };
      };
    };

    zoxide = {
      enable = true;
      enableBashIntegration = true;
      enableFishIntegration = true;
      enableZshIntegration = true;
      # Replace cd with z and add cdi to access zi
      options = [ "--cmd cd" ];
    };

    vscode = {
      enable = true;
    };


    zsh = {
      autocd = true;
      autosuggestion = {
        enable = true;
      };
      completionInit = ''
        autoload -U compinit && compinit
      '';
      dotDir = "${config.xdg.configHome}/zsh";
      enable = true;
      enableCompletion = true;
      enableVteIntegration = true;
      envExtra = ''
        export DOTFILES="${config.xdg.configHome}"

        ### ASDF ####
        #############

        export ASDF_CONFIG_FILE="${config.xdg.configHome}/asdf/.asdfrc"

        #### PYTHON ####
        ###############

        ### JETBRAINS ###
        #################

        export FLEET_PROPERTIES_FILE="${config.xdg.configHome}/jetbrains/fleet/fleet.properties"

        ###### GO #######
        #################
        export GOPATH="$HOME/.go"

        ##### DOTNET #######
        ####################
        export DOTNET_ROOT="/usr/local/share/dotnet"
        export DOTNET_TOOLS="$DOTNET_ROOT/tools"

        #### NODE #######
        #################

        export ENV="$DOTFILES/pnpm"

        #### KUBE ######
        ###############
        export KUBECONFIG="$DOTFILES/kube/config"

      '';
      history = {
        append = true;
        expireDuplicatesFirst = true;
        extended = true;
        ignoreAllDups = true;
        ignoreDups = true;
        save = 10000;
      };
      historySubstringSearch = {
        enable = true;
      };
      # Extra commands that should be added to .zshrc before compinit.
      initContent = lib.mkOrder 550 ''
        ### HOMEBREW ###
        ################
        eval "$(/opt/homebrew/bin/brew shellenv)"

        ###### NVM ########
        ###################
         export NVM_DIR="$HOME/.nvm"
        [ -s "$HOMEBREW_PREFIX/opt/nvm/nvm.sh" ] && \. "$HOMEBREW_PREFIX/opt/nvm/nvm.sh" # This loads nvm
        [ -s "$HOMEBREW_PREFIX/opt/nvm/etc/bash_completion.d/nvm" ] && \. "$HOMEBREW_PREFIX/opt/nvm/etc/bash_completion.d/nvm" # This loads nvm bash_completion

        ###### PYENV ######
        ##################


        [[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
        eval "$(pyenv init - zsh)"
        eval "$(pyenv virtualenv-init - zsh)"

        #### SDKMAN ####
        ################

        export SDKMAN_DIR="$HOMEBREW_PREFIX/opt/sdkman-cli/libexec"
        [[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]] && source "$SDKMAN_DIR/bin/sdkman-init.sh"


        ###############
        ####JETBRAINS##

        export PATH="$PATH:$HOME/.jetbrains/bin"

        ####STREAMPIPES####
        ###################

        export PATH="$PATH:$HOME/Code/github/heisenbergoss/streampipes/installer/cli"

        ##### GOLANG #######
        ####################

        export PATH="$PATH:$GOPATH/bin"

        ##### DOTNET #######
        ####################
        export PATH="$PATH:$DOTNET_ROOT:$DOTNET_TOOLS"

        #### RUST ########
        #################

        export PATH="$HOME/.cargo/bin:$PATH"

        export PATH="$HOME/.local/bin:$PATH"
      '';
      # Commands that should be added to top of .zshrc.
      initExtraFirst = '''';
      # Extra commands that should be added to .zlogin.
      loginExtra = '''';
      # Extra commands that should be added to .zprofile.
      profileExtra = ''
        export PYENV_ROOT="$HOME/.pyenv"
      '';
      # Environment variables that will be set for zsh session.
      sessionVariables = {

      };
      # An attribute set that maps aliases (the top level attribute names in this option) to command strings or directly to build outputs.
      shellAliases = {

      };
      syntaxHighlighting = {
        enable = true;
      };


      zsh-abbr = {
        enable = true;
        abbreviations = { };
      };
    };
  };

  services = {
  };

}
