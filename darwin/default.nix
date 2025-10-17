{
  config,
  hostname,
  inputs,
  lib,
  outputs,
  pkgs,
  platform,
  username,
  ...
}:
{
  imports = [
    inputs.nix-homebrew.darwinModules.nix-homebrew
    inputs.nix-index-database.darwinModules.nix-index
    ./${hostname}
    ./_mixins/desktop
    ./_mixins/features
    ./_mixins/scripts
  ];

  # Only install the docs I use
  documentation.enable = true;
  documentation.doc.enable = false;
  documentation.info.enable = false;
  documentation.man.enable = true;

  environment = {
    shells = [
      pkgs.zsh
    ];
    systemPackages = with pkgs; [
      cargo
      git
      ghostscript
      grpc
      grpcui
      grpcurl
      grpc-tools
      grpc-gateway
      imagemagick
      lua
      libpq
      luajit
      m-cli
      mas
      mermaid-cli
      nix-output-monitor
      nvd
      php
      plistwatch
      rustup
      texliveTeTeX
      tetex
      sops
      wireshark
      wget
    ];

    variables = {
      EDITOR = "nvim";
      SYSTEMD_EDITOR = "nvim";
      VISUAL = "nvim";
    };
  };

  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "zap";
    };

  };

  nix-homebrew = {
    enable = true;
    enableRosetta = if (platform == "aarch64-darwin") then true else false;
    autoMigrate = true;
    user = "${username}";
    mutableTaps = true;
  };

  nixpkgs = {
    # Configure your nixpkgs instance
    config.allowUnfree = true;
    hostPlatform = lib.mkDefault "${platform}";
    overlays = [
      outputs.overlays.additions
      outputs.overlays.modifications
      outputs.overlays.unstable-packages
    ];
  };

  nix =
    let
      flakeInputs = lib.filterAttrs (_: lib.isType "flake") inputs;
    in
    {
      settings = {
        experimental-features = "flakes nix-command";
        # Disable global registry
        flake-registry = "";
        # Workaround for https://github.com/NixOS/nix/issues/9574
        nix-path = config.nix.nixPath;
        trusted-users = [
          "root"
          "${username}"
        ];
        warn-dirty = false;
      };
      enable = false;
      # Disable channels
      channel.enable = false;
      # Make flake registry and nix path match flake inputs
      registry = lib.mapAttrs (_: flake: { inherit flake; }) flakeInputs;
      nixPath = lib.mapAttrsToList (n: _: "${n}=flake:${n}") flakeInputs;
    };

  networking.hostName = hostname;
  networking.computerName = hostname;

  programs = {
    info.enable = false;
    nix-index-database.comma.enable = true;
    zsh = {
      enable = true;
    };
  };

  # Enable TouchID for sudo authentication
  security.pam.services.sudo_local.touchIdAuth = true;

  services = {
  };

  system = {
    primaryUser = "${username}";

    stateVersion = 6;
    # activationScripts run every time you boot the system or execute `darwin-rebuild`
    activationScripts = {
      nixos-needsreboot = {
        supportsDryActivation = true;
        text = "${
          lib.getExe inputs.nixos-needsreboot.packages.${pkgs.system}.default
        } \"$systemConfig\" || true";
      };

    };

    defaults = {
      CustomUserPreferences = {
        "com.apple.AdLib" = {
          allowApplePersonalizedAdvertising = false;
        };
        "com.apple.controlcenter" = {
          BatteryShowPercentage = true;
        };
        "com.apple.desktopservices" = {
          # Avoid creating .DS_Store files on network or USB volumes
          DSDontWriteNetworkStores = true;
          DSDontWriteUSBStores = true;
        };
        "com.apple.finder" = {
          AppleShowAllFiles = true;
          _FXSortFoldersFirst = true;
          _FXShowPosixPathInTitle = true;
          FXDefaultSearchScope = "SCcf"; # Search current folder by default
          FXPreferredViewStyl = "Nlsv";
          FXEnableExtensionChangeWarning = true;
          ShowExternalHardDrivesOnDesktop = true;
          ShowHardDrivesOnDesktop = false;
          ShowStatusBar = false;
          ShowMountedServersOnDesktop = true;
          ShowRemovableMediaOnDesktop = true;
        };
        # Prevent Photos from opening automatically
        "com.apple.ImageCapture".disableHotPlug = true;
        "com.apple.screencapture" = {
          location = "~/Pictures/Screenshots";
          type = "png";
        };

        "com.apple.SoftwareUpdate" = {
          AutomaticCheckEnabled = true;
          # Check for software updates daily, not just once per week
          ScheduleFrequency = 1;
          # Download newly available updates in background
          AutomaticDownload = 0;
          # Install System data files & security updates
          CriticalUpdateInstall = 1;
        };
        "com.apple.TimeMachine".DoNotOfferNewDisksForBackup = true;
        # Turn on app auto-update
        "com.apple.commerce".AutoUpdate = true;
        # Alfred press secretary enable
        "com.runningwithcrayons.Alfred" = {
          experimental = {
            pressecretary = true;
          };
        };
      };
      dock = {
        orientation = "left";
        mru-spaces = false;
        show-recents = false;
        tilesize = 48;
        # Disable hot corners
        wvous-bl-corner = 1;
        wvous-br-corner = 1;
        wvous-tl-corner = 1;
        wvous-tr-corner = 1;
      };

      finder = {
        _FXShowPosixPathInTitle = true;
        FXEnableExtensionChangeWarning = false;
        FXPreferredViewStyle = "Nlsv";
        AppleShowAllExtensions = true;
        AppleShowAllFiles = true;
        QuitMenuItem = true;
        ShowPathbar = true;
        ShowStatusBar = true;
      };
      LaunchServices = {
        LSQuarantine = false;
      };

      menuExtraClock = {
        ShowAMPM = false;
        ShowDate = 1; # Always
        Show24Hour = true;
        ShowSeconds = false;
      };

      NSGlobalDomain = {
        AppleICUForce24HourTime = true;
        AppleInterfaceStyle = "Dark";
        AppleShowAllExtensions = true;
        AppleInterfaceStyleSwitchesAutomatically = false;
        AppleMeasurementUnits = "Centimeters";
        AppleMetricUnits = 1;
        AppleTemperatureUnit = "Celsius";
        "com.apple.swipescrolldirection" = false;
        _HIHideMenuBar = true;
        InitialKeyRepeat = 15;
        KeyRepeat = 2;
        NSAutomaticCapitalizationEnabled = false;
        NSAutomaticDashSubstitutionEnabled = false;
        NSAutomaticPeriodSubstitutionEnabled = false;
        NSAutomaticQuoteSubstitutionEnabled = false;
        NSAutomaticSpellingCorrectionEnabled = true;
        NSNavPanelExpandedStateForSaveMode = true;
        NSNavPanelExpandedStateForSaveMode2 = true;
        NSWindowShouldDragOnGesture = true;
      };
      screensaver = {
        askForPassword = true;
        askForPasswordDelay = 300;
      };

      smb.NetBIOSName = hostname;

      SoftwareUpdate = {
        AutomaticallyInstallMacOSUpdates = false;
      };

      spaces = {
        spans-displays = false;
      };

      trackpad = {
        Clicking = true;
        TrackpadRightClick = true; # enable two finger right click
        TrackpadThreeFingerDrag = true; # enable three finger drag
      };
    };
  };
}
