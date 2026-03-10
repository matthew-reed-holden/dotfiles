{ pkgs, ... }:
{
  homebrew = {
    taps = [
      "oven-sh/bun"
    ];

    brews = [
      "oven-sh/bun/bun"
      "cocoapods"
      "git-flow-avh"
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
    ];

  };

  environment.systemPackages = with pkgs; [
    kubernetes-helm
    kubectl
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
  ];
}
