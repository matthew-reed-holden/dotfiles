{ pkgs, ... }:
{
  homebrew = {
    brews = [
      "openssl"
      "readline"
      "xz"
      "zlib"
      "tcl-tk@8"
      "libb2"
      "gpg"
      "gawk"
    ];
    casks = [
      "obsidian"
      "slack"
    ];

  };

  environment.systemPackages = with pkgs; [
    inetutils # provides telnet, ftp, etc.
  ];
}
