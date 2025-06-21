{
  lib,
  pkgs,
  username,
  ...
}:
let
  installFor = [ "matthewholden" ];
in
lib.mkIf (lib.elem username installFor) {
  environment.systemPackages = with pkgs; [
  ];

  homebrew = {
    casks = [
      "shottr"
      #      "blender"
    ];
  };
}
