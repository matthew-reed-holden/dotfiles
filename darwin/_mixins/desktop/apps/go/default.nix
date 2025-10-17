{ pkgs, ... }:
{
  homebrew = {

    brews = [
      "go"
      "golangci-lint"
      "gosec"
      "gopls"
      "sqlc"
    ];


  };

}

