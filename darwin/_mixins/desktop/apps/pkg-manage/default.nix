{ pkgs, ... }:
{
  homebrew = {
    brews = [
      "nuget" # Dotnet package manager
      "nvm" # Node version manager
      "pyenv" # Python environment manager
      "pyenv-virtualenv" # Python virtualenv manager
      "sdkman-cli" # Managing sdks
      "uv" # Python package manager build on rust
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
