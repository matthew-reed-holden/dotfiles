{
  config,
  inputs,
  lib,
  pkgs,
  stateVersion,
  ...
}:
let
  inherit (config.noughty) host;
  username = config.noughty.user.name;
  # Derive Apple locale strings from the keyboard locale.
  # "en_GB.UTF-8" -> "en_GB" (strip encoding suffix)
  # "en_GB" -> "en-GB" (Apple language tag uses hyphens)
  appleLocale = lib.head (lib.splitString "." host.keyboard.locale);
  appleLanguage = builtins.replaceStrings [ "_" ] [ "-" ] appleLocale;
in
{
  imports = [
    ../common
    ../lib/noughty
    inputs.determinate.darwinModules.default
    inputs.mac-app-util.darwinModules.default
    inputs.nix-homebrew.darwinModules.nix-homebrew
    inputs.nix-index-database.darwinModules.nix-index
    ./_mixins/desktop
    ./_mixins/features
    ./_mixins/scripts
  ];

  environment = {
    shells = [
      pkgs.zsh
    ];
    systemPackages = with pkgs; [
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
      nh
      mermaid-cli
      php
      plistwatch
    ];

    variables = {
      SHELL = "${pkgs.zsh}/bin/zsh";
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
    enableRosetta = if (pkgs.stdenv.hostPlatform.system == "aarch64-darwin") then true else false;
    autoMigrate = true;
    user = "${username}";
    mutableTaps = true;
  };

  determinateNix = {
    enable = true;
    customSettings = {
      experimental-features = "nix-command flakes";
      extra-experimental-features = "parallel-eval";
      # Disable global registry
      flake-registry = "";
      lazy-trees = true;
      eval-cores = 0; # Enable parallel evaluation across all cores
      # Workaround for NixOS/nix#1254; avoids HTTP/2 framing errors from CDN servers
      http2 = false;
      # Increase download parallelism for faster substitution
      max-substitution-jobs = 64;
      http-connections = 128;
      connect-timeout = 10;
      # Allow wheel users to set client-side Nix options (e.g. netrc-file
      # for FlakeHub Cache authentication via fh apply).
      trusted-users = [
        "root"
        "@admin"
      ];
      warn-dirty = false;
    };
  };

  # Prevent audio stutter and UI jank during builds.
  # The daemon's scheduling policy propagates to all build processes.
  nix.daemonProcessType = "Background";
  nix.daemonIOLowPriority = true;

  programs = {
    info.enable = false;
    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };
    zsh = {
      enable = true;
    };
  };

  # Enable TouchID for sudo authentication
  security.pam.services.sudo_local.touchIdAuth = true;

  system = {
    primaryUser = "${username}";
    inherit stateVersion;

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
        NSGlobalDomain = {
          AppleLanguages = [ appleLanguage ];
          AppleLocale = appleLocale;
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

      smb.NetBIOSName = host.name;

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
