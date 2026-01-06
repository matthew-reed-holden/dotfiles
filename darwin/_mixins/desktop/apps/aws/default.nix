
{ pkgs, ... }:
{
  homebrew = {
    brews = [
      "awscli"
      "aws-sam-cli"
      "localstack/tap/localstack-cli"
    ];

    taps = [
      "localstack/tap"
    ];
  };
}
