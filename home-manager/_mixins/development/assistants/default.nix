{
  config,
  inputs,
  lib,
  noughtyLib,
  ...
}:
let
  inherit (config.noughty) host;
  isDeveloper = noughtyLib.userHasTag "developer";
  configDir = config.xdg.configHome;
  homeDir = config.home.homeDirectory;

  # Import the composition engine
  compose = import ./compose.nix { inherit lib; };

  # ── OpenCode composed content ──────────────────────────────────────
  opencodeAgents = compose.composeAgents "opencode";
  opencodeCommands = compose.composeCommands "opencode";
  opencodeInstructions = compose.composeInstructions "opencode";

  # ── Claude Code composed content ───────────────────────────────────
  claudeAgents = compose.composeAgents "claude";
  claudeCommands = compose.composeCommands "claude";
  claudeInstructions = compose.composeInstructions "claude";

  # ── Superpowers source from flake input ────────────────────────────
  superpowersSrc = inputs.superpowers;

  # ── OpenCode file entries ──────────────────────────────────────────

  # Personal agents -> ~/.config/opencode/agents/<name>.md
  opencodeAgentFiles = lib.mapAttrs' (
    name: content: lib.nameValuePair "${configDir}/opencode/agents/${name}.md" { text = content; }
  ) opencodeAgents;

  # Personal commands -> ~/.config/opencode/commands/<name>.md
  opencodeCommandFiles = lib.mapAttrs' (
    name: content: lib.nameValuePair "${configDir}/opencode/commands/${name}.md" { text = content; }
  ) opencodeCommands;

  # Global instructions -> ~/.config/opencode/AGENTS.md
  opencodeInstructionsFile = {
    "${configDir}/opencode/AGENTS.md".text = opencodeInstructions;
  };

  # Superpowers: full source -> ~/.config/opencode/superpowers/
  # force = true because this replaces the manually-installed git repo.
  opencodeSuperpowersSource = {
    "${configDir}/opencode/superpowers" = {
      source = superpowersSrc;
      force = true;
    };
  };

  # Superpowers: plugin symlink -> ~/.config/opencode/plugins/superpowers.js
  # Points into the Nix-managed superpowers source.
  opencodeSuperpowersPlugin = {
    "${configDir}/opencode/plugins/superpowers.js".source =
      "${superpowersSrc}/.opencode/plugins/superpowers.js";
  };

  # Superpowers: skills symlink -> ~/.config/opencode/skills/superpowers
  # force = true because this replaces the manually-created symlink.
  opencodeSuperpowersSkills = {
    "${configDir}/opencode/skills/superpowers" = {
      source = "${superpowersSrc}/skills";
      force = true;
    };
  };

  # Package.json for OpenCode plugin dependency
  # force = true because this replaces the manually-created file.
  opencodePackageJson = {
    "${configDir}/opencode/package.json" = {
      text = builtins.toJSON {
        dependencies = {
          "@opencode-ai/plugin" = "1.2.24";
        };
      };
      force = true;
    };
  };

  # ── Claude Code file entries ───────────────────────────────────────
  # Personal plugin lives at ~/.claude/plugins/repos/personal/
  claudePluginBase = "${homeDir}/.claude/plugins/repos/personal";

  # Plugin manifest
  claudePluginManifest = {
    "${claudePluginBase}/.claude-plugin/plugin.json".text = builtins.toJSON {
      name = "personal";
      description = "Personal agents and commands managed by Nix";
      version = "1.0.0";
      author = {
        name = config.noughty.user.name;
      };
    };
  };

  # Personal agents -> ~/.claude/plugins/repos/personal/agents/<name>.md
  claudeAgentFiles = lib.mapAttrs' (
    name: content: lib.nameValuePair "${claudePluginBase}/agents/${name}.md" { text = content; }
  ) claudeAgents;

  # Personal commands -> ~/.claude/plugins/repos/personal/commands/<name>.md
  claudeCommandFiles = lib.mapAttrs' (
    name: content: lib.nameValuePair "${claudePluginBase}/commands/${name}.md" { text = content; }
  ) claudeCommands;

  # Global instructions -> ~/.claude/CLAUDE.md
  claudeInstructionsFile = {
    "${homeDir}/.claude/CLAUDE.md".text = claudeInstructions;
  };
in
{
  config = lib.mkIf isDeveloper {
    home.file =
      # OpenCode personal assistants
      opencodeAgentFiles
      // opencodeCommandFiles
      // opencodeInstructionsFile
      # OpenCode superpowers
      // opencodeSuperpowersSource
      // opencodeSuperpowersPlugin
      // opencodeSuperpowersSkills
      // opencodePackageJson
      # Claude Code personal plugin
      // claudePluginManifest
      // claudeAgentFiles
      // claudeCommandFiles
      // claudeInstructionsFile;

    # Run bun/npm install for the OpenCode plugin dependency after files are written
    home.activation.installOpenCodePluginDeps = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ -f "${configDir}/opencode/package.json" ]; then
        export PATH="${config.home.profileDirectory}/bin:$PATH"
        if command -v bun >/dev/null 2>&1; then
          $DRY_RUN_CMD bun install --cwd "${configDir}/opencode" 2>/dev/null || true
        elif command -v npm >/dev/null 2>&1; then
          $DRY_RUN_CMD npm install --prefix "${configDir}/opencode" 2>/dev/null || true
        fi
      fi
    '';
  };
}
