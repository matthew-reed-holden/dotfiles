{ pkgs, ... }:
{
  homebrew = {
    brews = [
      "awscli"
      "docker"
      "docker-completion"
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
      "sf-symbols"
      "ghostty"
      "postman"
      "warp"
      "atomicjar/tap/testcontainers-desktop" # test containers desktop
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
