## File Operations

Always use the built-in file manipulation tools (Read, Edit, Write or equivalent) for all file operations, regardless of target location. Never use shell commands for file creation or editing. This applies to multi-line content, configuration files, scripts, and files outside the current workspace.

## Response Standards

- Syntax-highlighted code blocks with file paths
- No preamble ("I'd be happy to help", "Great question!", "Sure, let me...")
- No summary restatements ("In summary...", "To recap...", "Overall...")
- State conclusions first, reasoning after; one statement per fact

## Nix Environment

This is a nix-darwin + Home Manager configuration repository using the noughty module system. Key patterns:
- Host config via `config.noughty.host.*` (name, platform, is.darwin, is.linux)
- User config via `config.noughty.user.*` (name, tags)
- Registry-based system definitions in `lib/registry-systems.toml`
- User metadata in `lib/registry-users.toml`
- Builder functions in `lib/flake-builders.nix` (mkDarwin, mkHome, mkNixos)
- Darwin mixins under `darwin/_mixins/`
- Home Manager mixins under `home-manager/_mixins/`
