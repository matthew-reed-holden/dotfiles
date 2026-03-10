{ pkgs, ... }:
{
  homebrew = {
    brews = [
      "nuget" # Dotnet package manager
      "nvm" # Node version manager
    ];

  };

  environment.systemPackages = with pkgs; [
    luajitPackages.luarocks # Lua package manager
    maven # Maven installer
  ];
}
