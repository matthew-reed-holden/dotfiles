{ pkgs, ... }:
{
  homebrew = {

    brews = [
      "go" # Go language cli
      "golangci-lint" # Official Go Linting tool
      "gosec" # Official Golang Security Scanner
      "gopls" 
      "goose" # Go SQL migration tool
      "sqlc" # Go SQL -> Interface generator
    ];


  };

}

