{
  lib,
  pkgs,
  username,
  ...
}:
let
  installFor = [ "holdem3" ];
in
lib.mkIf (lib.elem username installFor) {
  environment.systemPackages = with pkgs; [
  ];

  homebrew = {
    casks = [
      "shottr"
      "blender"
    ];
  };
}
