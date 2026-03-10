{ pkgs, ... }:
{
  homebrew = {
    taps = [
      "anomalyco/tap"
      "oven-sh/bun"
    ];

    brews = [
      "bun"
      "cocoapods"
      "git-flow-avh"
      "jupyter"
      "jupyterlab"
      "neovim"
      "mono-libgdiplus"
      "opencode"
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
