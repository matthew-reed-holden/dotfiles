{ pkgs, ... }:
{
  imports = [
    ./apps
  ];

  environment.systemPackages = with pkgs; [ ];
}
