{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  mcpSopsFile = ../../../../secrets/mcp.yaml;

  # Transform programs.mcp.servers into Zed's context_servers format
  # Stdio: { name = { command = { path = "cmd"; args = [...]; env = {...}; }; }; }
  # Remote: { name = { url = "..."; headers = {...}; }; }
  transformToZedContextServer = name: server:
    if server ? command then {
      name = name;
      value = {
        command = {
          path = server.command;
          args = server.args or [ ];
        } // (lib.optionalAttrs (server ? env) { env = server.env; });
      };
    } else if server ? url then {
      name = name;
      value = {
        url = server.url;
      } // (lib.optionalAttrs (server ? headers) { headers = server.headers; });
    } else
      null;

  zedContextServers =
    let
      transformed = lib.mapAttrsToList transformToZedContextServer config.programs.mcp.servers;
      filtered = builtins.filter (x: x != null) transformed;
    in
    lib.listToAttrs filtered;

  # Transform programs.mcp.servers into Copilot CLI's format
  # Copilot: { servers = { name = { type = "stdio"; command = "cmd"; args = [...]; env = {...}; }; }; }
  # Remote servers get wrapped via npx mcp-remote
  transformToCopilotServer = name: server:
    if server ? command then {
      name = name;
      value = {
        type = "stdio";
        command = server.command;
        args = server.args or [ ];
      } // (lib.optionalAttrs (server ? env) { env = server.env; });
    } else if server ? url then {
      name = name;
      value = {
        type = "stdio";
        command = "${pkgs.nodejs}/bin/npx";
        args = [ "-y" "mcp-remote" server.url ];
      };
    } else
      null;

  copilotMcpServers =
    let
      transformed = lib.mapAttrsToList transformToCopilotServer config.programs.mcp.servers;
      filtered = builtins.filter (x: x != null) transformed;
    in
    lib.listToAttrs filtered;
in
{
  config = lib.mkIf (noughtyLib.userHasTag "developer") {
    # ── Centralized MCP server definitions ────────────────────────────
    programs.mcp = {
      enable = true;
      servers = {
        # Servers without secrets
        nixos = {
          command = "${pkgs.unstable.mcp-nixos}/bin/mcp-nixos";
        };
        cloudflare = {
          url = "https://docs.mcp.cloudflare.com/mcp";
        };
        exa = {
          url = "https://mcp.exa.ai/mcp";
        };
        next-devtools = {
          command = "${pkgs.nodejs}/bin/npx";
          args = [ "-y" "next-devtools-mcp@latest" ];
        };
        chrome-devtools = {
          command = "${pkgs.nodejs}/bin/npx";
          args = [ "-y" "chrome-devtools-mcp@latest" "--no-usage-statistics" ];
        };
        playwright = {
          command = "${pkgs.nodejs}/bin/npx";
          args = [ "-y" "@playwright/mcp@latest" ];
        };
        sequential-thinking = {
          command = "${pkgs.nodejs}/bin/npx";
          args = [ "-y" "@modelcontextprotocol/server-sequential-thinking" ];
        };
        postgres = {
          command = "${pkgs.nodejs}/bin/npx";
          args = [ "-y" "@modelcontextprotocol/server-postgres" ];
          env = {
            POSTGRES_CONNECTION_STRING = "{env:POSTGRES_CONNECTION_STRING}";
          };
        };
        # Servers with secrets — use {env:VAR} for agents that support it;
        # sops exports the env vars via shell init below
        github = {
          command = "${pkgs.nodejs}/bin/npx";
          args = [ "-y" "@modelcontextprotocol/server-github" ];
          env = {
            GITHUB_PERSONAL_ACCESS_TOKEN = "{env:GITHUB_PERSONAL_ACCESS_TOKEN}";
          };
        };
        firecrawl = {
          command = "${pkgs.nodejs}/bin/npx";
          args = [ "-y" "firecrawl-mcp" ];
          env = {
            FIRECRAWL_API_KEY = "{env:FIRECRAWL_API_KEY}";
          };
        };
        context7 = {
          url = "https://mcp.context7.com/mcp";
          headers = {
            Authorization = "Bearer {env:CONTEXT7_API_KEY}";
          };
        };
        jina = {
          url = "https://mcp.jina.ai/v1?exclude_tools=deduplicate_strings,expand_query,parallel_search_arxiv,parallel_search_ssrn,parallel_search_web,show_api_key,search_arxiv,search_jina_blog,search_ssrn,search_web";
          headers = {
            Authorization = "Bearer {env:JINA_API_KEY}";
          };
        };
      };
    };

    # ── sops secrets ──────────────────────────────────────────────────
    sops = {
      age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
      defaultSopsFile = mcpSopsFile;
      defaultSopsFormat = "yaml";

      secrets = {
        CONTEXT7_API_KEY = { };
        FIRECRAWL_API_KEY = { };
        GITHUB_PERSONAL_ACCESS_TOKEN = { };
        JINA_API_KEY = { };
      };
    };

    # ── Export secrets as env vars for agents ──────────────────────────
    programs.zsh.initContent = lib.mkOrder 600 ''
      # Export MCP secrets from sops
      export CONTEXT7_API_KEY=$(cat ${config.sops.secrets.CONTEXT7_API_KEY.path} 2>/dev/null || echo "")
      export FIRECRAWL_API_KEY=$(cat ${config.sops.secrets.FIRECRAWL_API_KEY.path} 2>/dev/null || echo "")
      export GITHUB_PERSONAL_ACCESS_TOKEN=$(cat ${config.sops.secrets.GITHUB_PERSONAL_ACCESS_TOKEN.path} 2>/dev/null || echo "")
      export JINA_API_KEY=$(cat ${config.sops.secrets.JINA_API_KEY.path} 2>/dev/null || echo "")
    '';

    # ── OpenCode: uses enableMcpIntegration from programs.mcp ─────────
    programs.opencode.enableMcpIntegration = true;

    # ── Zed: inject context_servers for stdio MCP servers ─────────────
    programs.zed-editor = lib.mkIf config.programs.zed-editor.enable {
      userSettings = {
        context_servers = zedContextServers;
      };
    };

    # ── Copilot CLI: write mcp config file ────────────────────────────
    xdg.configFile."github-copilot/mcp.json".text = builtins.toJSON {
      mcpServers = copilotMcpServers;
    };
  };
}
