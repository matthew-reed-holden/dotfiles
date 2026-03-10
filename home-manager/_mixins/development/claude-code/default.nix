{
  config,
  inputs,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  system = host.platform;
  # On Darwin, use pkgs.unstable.claude-code (better integration with macOS);
  # on Linux, use the llm-agents package (pre-built via Numtide cache).
  claude-code =
    if host.is.darwin then
      pkgs.unstable.claude-code
    else
      inputs.llm-agents.packages.${system}.claude-code;
in
{
  config = lib.mkIf (noughtyLib.userHasTag "developer") {
    home.packages = [ claude-code ];
  };
}
