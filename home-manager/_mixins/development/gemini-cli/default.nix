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
  gemini-cli = inputs.llm-agents.packages.${system}.gemini-cli;
in
{
  config = lib.mkIf (noughtyLib.userHasTag "developer") {
    home.packages = [ gemini-cli ];
  };
}
