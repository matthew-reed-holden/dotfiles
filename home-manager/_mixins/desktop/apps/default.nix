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
  imports = [
    ./browsers
    ./chat
    ./music
    ./notes
    ./office
    ./terminal
    ./utilities
  ];

}
