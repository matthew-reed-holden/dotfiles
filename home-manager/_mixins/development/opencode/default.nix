{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  inherit (pkgs.stdenv.hostPlatform) system;
  # Use the pre-built binary from numtide's llm-agents.nix flake.
  # This avoids upstream source build issues entirely.
  opencodePackage = inputs.llm-agents.packages.${system}.opencode;
in
{
  home = {
    packages = lib.optionals host.is.workstation [
      pkgs.opencode-desktop
    ];
    shellAliases = {
      oc-rosey = "opencode --agent rosey --continue";
    };
  };

  programs = {
    opencode = {
      enable = true;
      package = opencodePackage;
    };
    vscode = lib.mkIf config.programs.vscode.enable {
      profiles.default = {
        extensions = [ ];
      };
    };
    zed-editor = lib.mkIf config.programs.zed-editor.enable {
      extensions = [
        "opencode"
      ];
      userSettings = {
        agent_servers = {
          OpenCode = {
            type = "custom";
            command = "opencode";
            args = [ "acp" ];
            env = { };
          };
        };
      };
    };
  };

  xdg.configFile."opencode/tui.json".text = builtins.toJSON {
    "$schema" = "https://opencode.ai/tui.json";
    theme = "catppuccin";
    tui = {
      diff_style = "stacked";
      scroll_acceleration = {
        enabled = true;
      };
    };

  };
}
