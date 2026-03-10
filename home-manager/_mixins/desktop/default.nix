{
  catppuccinPalette,
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
in
{
  # Import the DE specific configuration; each compositor gates itself internally
  imports = [
    ./apps
  ];

}
