{
  config,
  inputs,
  lib,
  noughtyLib,
  ...
}:
let
  inherit (config.noughty) host;
  system = host.platform;
  opencode = inputs.llm-agents.packages.${system}.opencode;
in
{
  config = lib.mkIf (noughtyLib.userHasTag "developer") {
    home.packages = [ opencode ];
  };
}
