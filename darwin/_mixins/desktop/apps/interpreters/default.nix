{ pkgs, ... }:
{
  homebrew = {
    taps = [
      "steveyegge/beads"
    ];

    brews = [
      "bd"
      "biome"
      "llvm"
    ];

  };

  environment.systemPackages = with pkgs; [
    ansible
    ansible-lint
    bash-language-server
    coursier
    jdk
    jdk17
    jre8
    luajit_openresty
    scala
    scalafmt
    scalafix
    stylua
    texliveTeTeX
  ];
}
