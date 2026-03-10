{ pkgs, ... }:
{
  homebrew = {
    brews = [
      "mas" # Mac App Store CLI
      "nuget" # Dotnet package manager
      "nvm" # Node version manager
    ];

    casks = [
      "jetbrains-toolbox" # Jetbrains IDE manager
    ];

  };

  environment.systemPackages = with pkgs; [
    luajitPackages.luarocks # Lua package manager
    maven # Maven installer
  ];
}
