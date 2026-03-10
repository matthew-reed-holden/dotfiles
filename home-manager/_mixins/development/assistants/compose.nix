{ lib }:
let
  # Read a file, stripping trailing whitespace
  readFile = path: lib.trim (builtins.readFile path);

  # Compose with YAML frontmatter: ---\n{header}\n---\n\n{body}\n
  composeWithFrontmatter = header: body: "---\n${header}\n---\n\n${body}\n";

  # Discover directories in a path
  discoverDirs =
    path:
    if builtins.pathExists path then
      lib.filterAttrs (_name: type: type == "directory") (builtins.readDir path)
    else
      { };

  # Base path for all assistant files
  basePath = ./.;

  # ============ AGENTS ============

  agentDirs = discoverDirs (basePath + "/agents");

  composeAgent =
    platform: agentName:
    let
      agentPath = basePath + "/agents/${agentName}";
      prompt = readFile (agentPath + "/prompt.md");
      description = readFile (agentPath + "/description.txt");
      header = readFile (agentPath + "/header.${platform}.yaml");
      headerWithDescription = "description: \"${description}\"\n${header}";
    in
    composeWithFrontmatter headerWithDescription prompt;

  composeAgents = platform: lib.mapAttrs (name: _: composeAgent platform name) agentDirs;

  # ============ COMMANDS ============

  # Discover commands for a specific agent
  discoverAgentCommands = agentName: discoverDirs (basePath + "/agents/${agentName}/commands");

  # Discover standalone commands
  standaloneCommandDirs = discoverDirs (basePath + "/commands");

  composeCommand =
    platform: agentName: cmdName:
    let
      cmdPath =
        if agentName != null then
          basePath + "/agents/${agentName}/commands/${cmdName}"
        else
          basePath + "/commands/${cmdName}";
      prompt = readFile (cmdPath + "/prompt.md");
      description = readFile (cmdPath + "/description.txt");
      rawHeader = readFile (cmdPath + "/header.${platform}.yaml");
      header = "description: \"${description}\"\n${rawHeader}";
      useTask = lib.hasInfix "use-task: true" rawHeader;
    in
    if platform == "claude" && agentName != null && useTask then
      composeWithFrontmatter header ''
        Use the Task tool to launch the ${agentName} agent for the following task:

        ${prompt}''
    else if platform == "claude" && agentName != null then
      composeWithFrontmatter header "@${agentName}\n\n${prompt}"
    else
      composeWithFrontmatter header prompt;

  composeCommands =
    platform:
    let
      agentCommands = lib.foldlAttrs (
        acc: agentName: _:
        let
          cmdDirs = discoverAgentCommands agentName;
          cmds = lib.mapAttrs (cmdName: _: composeCommand platform agentName cmdName) cmdDirs;
        in
        acc // cmds
      ) { } agentDirs;
      standaloneCmds = lib.mapAttrs (
        cmdName: _: composeCommand platform null cmdName
      ) standaloneCommandDirs;
    in
    agentCommands // standaloneCmds;

  # ============ GLOBAL INSTRUCTIONS ============

  composeInstructions =
    platform:
    let
      instructionsPath = basePath + "/instructions";
      header = readFile (instructionsPath + "/header.${platform}.yaml");
      body = readFile (instructionsPath + "/global.md");
    in
    composeWithFrontmatter header body;

in
{
  inherit
    composeAgents
    composeAgent
    composeCommands
    composeCommand
    composeInstructions
    agentDirs
    standaloneCommandDirs
    discoverAgentCommands
    ;
}
