{ pkgs, ... }:
{
  imports = [
    ./apps
  ];

  environment.systemPackages = with pkgs; [
    brave
  ];

  homebrew = {
    casks = [
      "blender"
      "docker-desktop"
      "orion"
      "tailscale-app"
      "shottr"
    ];
  };
}
