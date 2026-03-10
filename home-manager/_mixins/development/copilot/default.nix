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
  copilot-cli = inputs.llm-agents.packages.${system}.copilot-cli;
in
{
  config = lib.mkIf (noughtyLib.userHasTag "developer") {
    home.packages = [ copilot-cli ];
  };
}
