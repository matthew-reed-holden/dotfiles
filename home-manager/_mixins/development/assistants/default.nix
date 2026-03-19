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

  # Package.json content for OpenCode plugin dependency
  # NOT managed as a Home Manager file — it must be writable at runtime
  # because `bun install` / `npm install` and OpenCode itself write to it.
  opencodePackageJsonContent = builtins.toJSON {
    dependencies = {
      "@opencode-ai/plugin" = "1.2.24";
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
      # Claude Code personal plugin
      // claudePluginManifest
      // claudeAgentFiles
      // claudeCommandFiles
      // claudeInstructionsFile;

    # Write package.json as a mutable file and install OpenCode plugin deps.
    # Must be a real file (not a Nix store symlink) because bun/npm and
    # OpenCode need write access at runtime.
    home.activation.installOpenCodePluginDeps = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      oc_dir="${configDir}/opencode"
      oc_pkg="$oc_dir/package.json"
      $DRY_RUN_CMD mkdir -p "$oc_dir"
      # Remove stale Nix store symlink if left over from a previous generation
      if [ -L "$oc_pkg" ]; then
        $DRY_RUN_CMD rm "$oc_pkg"
      fi
      if [ -z "''${DRY_RUN:-}" ]; then
        cat > "$oc_pkg" <<'PACKAGEJSON'
${opencodePackageJsonContent}
PACKAGEJSON
      fi
      export PATH="${config.home.profileDirectory}/bin:$PATH"
      if command -v bun >/dev/null 2>&1; then
        $DRY_RUN_CMD bun install --cwd "$oc_dir" 2>/dev/null || true
      elif command -v npm >/dev/null 2>&1; then
        $DRY_RUN_CMD npm install --prefix "$oc_dir" 2>/dev/null || true
      fi
    '';
  };
}
