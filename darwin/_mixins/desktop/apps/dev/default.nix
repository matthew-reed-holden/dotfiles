{ config, lib, pkgs, ... }:
let
  username = config.noughty.user.name;
in
{
  homebrew = {
    taps = [
      "oven-sh/bun"
    ];

    brews = [
      "oven-sh/bun/bun"
      "cocoapods"
      "git-flow"
      "jupyter"
      "jupyterlab"
      "neovim"
      "mono-libgdiplus"
      "pre-commit"
    ];

    casks = [
      "bruno"
      "ghostty"
      "git-credential-manager"
      "godot"
      "logisim-evolution"
      "zed"
    ];

  };

  environment.systemPackages = with pkgs; [
    dolt
    go
    gopls
    kubernetes-helm
    kubectl
    kubectx
    helm-ls
    helmfile
    helmsman
    helm-docs
    jq
    minikube
    prettierd
    prettier-plugin-go-template
    tenv
    terraformer
    terraform-ls
  ]
  ++ lib.optionals (username == "holdem3") [
    qemu
    vagrant
  ];
}
