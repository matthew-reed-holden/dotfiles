{
  description = "Heisenbergs incredibly uncertain nix-darwin and Home Manager Configuration";
  inputs = {
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";
    fh.url = "https://flakehub.com/f/DeterminateSystems/fh/*";

    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nix-darwin.url = "github:LnL7/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";
    nixos-needsreboot.url = "https://flakehub.com/f/wimpysworld/nixos-needsreboot/0.2.5.tar.gz";
    nixos-needsreboot.inputs.nixpkgs.follows = "nixpkgs";
    catppuccin.url = "github:catppuccin/nix";

    disko.url = "https://flakehub.com/f/nix-community/disko/1.11.0.tar.gz";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    nixos-hardware.url = "https://flakehub.com/f/NixOS/nixos-hardware/*";

    nix-index-database.url = "github:Mic92/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";

    catppuccin-vsc.url = "https://flakehub.com/f/catppuccin/vscode/*";
    catppuccin-vsc.inputs.nixpkgs.follows = "nixpkgs";

    vscode-server.url = "github:nix-community/nixos-vscode-server";
    vscode-server.inputs.nixpkgs.follows = "nixpkgs";

    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
    nix-vscode-extensions.inputs.nixpkgs.follows = "nixpkgs";

    sops-nix.url = "https://flakehub.com/f/Mic92/sops-nix/0.1.887.tar.gz";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    nix-jetbrains-plugins.url = "github:theCapypara/nix-jetbrains-plugins";
    nix-jetbrains-plugins.inputs.nixpkgs.follows = "nixpkgs";

  };

  outputs =
    {
      self,
      nix-darwin,
      nixpkgs,
      ...
    }@inputs:
    let
      inherit (self) outputs;
      # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
      stateVersion = "24.11";
      helper = import ./lib { inherit inputs outputs stateVersion; };
    in
    {
      # home-manager build --flake $HOME/.config
      # home-manager switch -b backup --flake $HOME/.config
      # nix run nixpkgs#home-manager -- switch -b backup --flake "${HOME}/.config
      homeConfigurations = {
        "holdem3" = helper.mkHome {
          username = "holdem3";
          hostname = "C002108230";
          platform = "aarch64-darwin";
          desktop = "aqua";
        };

        "matthewholden" = helper.mkHome {
          username = "matthewholden";
          hostname = "Matthews-MacBook-Pro-2";
          platform = "aarch64-darwin";
          desktop = "aqua";
        };
      };

      #nix run nix-darwin -- switch --flake ~/Zero/nix-config
      #nix build .#darwinConfigurations.{hostname}.config.system.build.toplevel
      darwinConfigurations = {
        C002108230 = helper.mkDarwin {
          username = "holdem3";
          hostname = "C002108230";
        };

        "Matthews-MacBook-Pro-2" = helper.mkDarwin {
          username = "matthewholden";
          hostname = "Matthews-MacBook-Pro-2";
        };
      };

      # Custom packages and modifications, exported as overlays
      overlays = import ./overlays { inherit inputs; };
      # Custom packages; acessible via 'nix build', 'nix shell', etc
      packages = helper.forAllSystems (system: import ./pkgs nixpkgs.legacyPackages.${system});
      # Formatter for .nix files, available via 'nix fmt'
      formatter = helper.forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-rfc-style);
    };
}
