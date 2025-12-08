{ pkgs, ... }:
{
  homebrew = {
    brews = [
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
    jdk23
    jre8
    luajit_openresty
    scala
    scalafmt
    scalafix
    stylua
    texliveTeTeX
  ];
}
