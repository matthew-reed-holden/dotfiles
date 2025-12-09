{ pkgs, ... }:
{
  homebrew = {
    brews = [
      "cocoapods"
      "docker"
      "docker-completion"
      "git-flow-avh"
      "jupyter"
      "jupyterlab"
      "neovim"
      "nowplaying-cli"
      "mono-libgdiplus"
      "pre-commit"
      "switchaudio-osx"
    ];

    casks = [
      "git-credential-manager"
      "godot"
      "ghostty"
      "logisim-evolution"
      "sf-symbols"
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
