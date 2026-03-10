{ pkgs, ... }:
{
  imports = [
    ./apps
  ];

  homebrew = {
    casks = [
      "blender"
      "docker-desktop"
      "tailscale-app"
      "shottr"
    ];
  };
}
