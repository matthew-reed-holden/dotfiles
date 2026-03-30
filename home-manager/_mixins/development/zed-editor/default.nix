{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
in
{
  config = lib.mkIf (noughtyLib.userHasTag "developer") {
    catppuccin.zed.enable = config.programs.zed-editor.enable;

    programs.zed-editor = {
      enable = true;
      extensions = [
        "ansible"
        "astro"
        "biome"
        "catppuccin"
        "catppuccin-icons"
        "dockerfile"
        "editorconfig"
        "git-firefly"
        "graphql"
        "helm"
        "ini"
        "java"
        "justfile"
        "lua"
        "make"
        "nginx"
        "nix"
        "proto"
        "scss"
        "sql"
        "swift"
        "terraform"
        "toml"
        "zig"
      ];
      package = if host.is.darwin then null else pkgs.unstable.zed-editor;
      userSettings = {
        auto_update = false;
        base_keymap = "VSCode";
        buffer_font_family = "FiraCode Nerd Font Mono";
        buffer_font_size = 12;
        buffer_font_weight = 400;
        ui_font_family = "Work Sans";
        ui_font_size = 16;
        ui_font_weight = 400;
        agent_buffer_font_size = 12;
        agent_ui_font_size = 13;
        cursor_shape = "block";
        tab_size = 2;
        telemetry = {
          diagnostics = false;
          metrics = false;
        };
        terminal = {
          copy_on_select = true;
          cursor_shape = "block";
          font_family = "FiraCode Nerd Font Mono";
          font_size = 13;
        };
      };
    };
  };
}
