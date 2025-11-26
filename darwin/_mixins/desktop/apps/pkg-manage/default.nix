{ pkgs, ... }:
{
  homebrew = {
    brews = [
      "nuget" # Dotnet package manager
      "nvm" # Node version manager
    ];

    casks = [
      "jetbrains-toolbox" # Jetbrains IDE manager
    ];

    taps = [
      "sdkman/tap" # SDKMAN tap
    ];

  };

  environment.systemPackages = with pkgs; [
    luajitPackages.luarocks # Lua package manager
    maven # Maven installer
  ];
}
