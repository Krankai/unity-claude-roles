<#
.SYNOPSIS
    role-guard — Claude Code PreToolUse hook that enforces the unity-claude-roles rules.

.DESCRIPTION
    Registered in the project's .claude/settings.json for two matchers:
      - Edit|Write|NotebookEdit   -> file mode  (file rules, README "File rules")
      - mcp__unity-mcp__.*        -> MCP mode   (capabilities, README "Unity MCP rules")

    Claude Code sends the tool call as JSON on stdin. The script:
      - exits 0 (silently) to allow the call
      - exits 2 with a message on stderr to block it; Claude sees the message

    It fails closed: if the input or the tool map can't be read, the call is blocked.

    Written for Windows PowerShell 5.1 (the "powershell" hook shell); also runs on PowerShell 7.

    To change a rule, edit the tables in the RULES section. The logic below them doesn't need
    to change.

.NOTES
    Shell commands (Bash/PowerShell tools) are not checked here. They're covered by the shell
    rule and "permissions.ask" in the project's .claude/settings.json.
#>

$ErrorActionPreference = 'Stop'

# =================================================================================================
# RULES
# =================================================================================================

# agent_type -> role. Anything not listed (your own session, built-in agents) is "main".
$RoleByAgentType = @{
    'game-designer'      = 'designer'
    'game-developer'     = 'developer'
    'technical-director' = 'director'
}

$AllRoles = @('designer', 'developer', 'director', 'main')

# File rules — checked top-down, first match wins (README "File rules").
# Paths are project-relative, forward slashes, compared case-insensitively.
# In patterns, '*' matches any characters including '/'.
#   Patterns : wildcard patterns for the relative path
#   Special  : 'outside' (target is outside the project) or 'unity-asset' (Unity YAML asset)
#   Allow    : roles that may edit
#   Hint     : what to do instead when blocked
$FileRules = @(
    @{ Id = 1;  Name = 'outside the project folder'; Special = 'outside'
       Allow = @()
       Hint  = 'Only files inside the project may be edited.' }
    @{ Id = 2;  Name = '.meta file'; Patterns = @('*.meta')
       Allow = @()
       Hint  = 'Unity creates and owns .meta files. Never edit them.' }
    @{ Id = 3;  Name = 'generated file'
       Patterns = @('library/*', 'temp/*', 'obj/*', 'logs/*', 'usersettings/*', 'packages/packages-lock.json')
       Allow = @()
       Hint  = 'Unity generates this. Never edit it.' }
    @{ Id = 4;  Name = 'Claude configuration'
       Patterns = @('.claude/*', 'claude.md', 'claude.local.md')
       Allow = @()
       Hint  = 'Only the owner edits these, by hand. Describe the change in your report.' }
    @{ Id = 5;  Name = 'guide project tier (tech stack)'
       Patterns = @('guidelines/agents.md', 'guidelines/unitycustominstructions/*')
       Allow = @('director')
       Hint  = 'Send a Request to technical-director.' }
    @{ Id = 6;  Name = 'guide'; Patterns = @('guidelines/*')
       Allow = @()
       Hint  = 'The guide is read-only. Add a Guideline Proposal to your report instead.' }
    @{ Id = 7;  Name = 'packages / project settings'
       Patterns = @('packages/manifest.json', 'projectsettings/*')
       Allow = @('developer', 'director', 'main')
       Hint  = 'Send a Package Request to technical-director.' }
    @{ Id = 8;  Name = 'design patch'; Patterns = @('assets/editor/designpatches/*')
       Allow = @('designer', 'developer', 'main')
       Hint  = 'Design patches belong to game-designer and game-developer.' }
    @{ Id = 9;  Name = 'graph asset'
       Patterns = @('*.shadergraph', '*.shadersubgraph', '*.vfx')
       Allow = @('designer', 'developer', 'main')
       Hint  = 'Graph assets belong to game-designer and game-developer (for now).' }
    @{ Id = 10; Name = 'Unity asset'; Special = 'unity-asset'
       Allow = @()
       Hint  = 'Unity assets are never written as files. Use Unity MCP, a design patch, or the Editor.' }
    @{ Id = 11; Name = 'code'
       Patterns = @('*.cs', '*.asmdef', '*.asmref', '*.shader', '*.hlsl', '*.cginc', '*.compute')
       Allow = @('developer', 'main')
       Hint  = 'Write a Feature Spec, Tool Request or Change Request for game-developer.' }
    @{ Id = 12; Name = 'data file'
       Patterns = @('assets/*.json', 'assets/*.csv', 'assets/*.tsv', 'assets/*.data')
       Allow = @('designer', 'developer', 'main')
       Hint  = 'Data files belong to game-designer and game-developer.' }
    @{ Id = 13; Name = 'design docs'; Patterns = @('docs/design/*')
       Allow = @('designer', 'developer', 'main')
       Hint  = 'Design docs belong to game-designer and game-developer.' }
    @{ Id = 14; Name = 'requests'; Patterns = @('docs/requests/*')
       Allow = $AllRoles
       Hint  = '' }
    @{ Id = 15; Name = 'tech docs / repo config'
       Patterns = @('docs/tech/*', '.gitignore', '.gitattributes', '.mcp.json')
       Allow = @('developer', 'director', 'main')
       Hint  = 'Send a Request to technical-director.' }
    @{ Id = 16; Name = 'other file'; Patterns = @('*')
       Allow = @('developer', 'main')
       Hint  = 'Send a Change Request to game-developer.' }
)

# Unity asset types. A file counts as a Unity asset (rule 10) if it has one of these extensions,
# or if it exists and starts with "%YAML".
$UnityAssetExtensions = @(
    '.unity', '.prefab', '.asset', '.mat', '.controller', '.overridecontroller', '.anim', '.mask',
    '.mixer', '.physicmaterial', '.physicsmaterial2d', '.spriteatlas', '.lighting', '.playable',
    '.signal', '.rendertexture', '.terrainlayer', '.preset'
)

# Unity MCP capabilities (README "Unity MCP rules").
$McpCapabilities = @{
    'M1'  = @{ Name = 'read';                           Allow = $AllRoles;                             Hint = '' }
    'M2'  = @{ Name = 'scene building';                 Allow = @('designer', 'developer', 'main');   Hint = 'Ask game-designer or game-developer.' }
    'M3'  = @{ Name = 'asset editing';                  Allow = @('designer', 'developer', 'main');   Hint = 'Ask game-designer or game-developer.' }
    'M4'  = @{ Name = 'scene create/open/save';         Allow = @('designer', 'developer', 'main');   Hint = 'Ask game-designer or game-developer.' }
    'M5'  = @{ Name = 'delete, move or rename assets';  Allow = @('developer', 'main');               Hint = 'Write a Change Request instead.' }
    'M6'  = @{ Name = 'script editing';                 Allow = @('developer', 'main');               Hint = 'Write a Change Request for game-developer.' }
    'M7'  = @{ Name = 'run arbitrary code';             Allow = @('developer', 'main');               Hint = 'Write a Change Request for game-developer.' }
    'M8'  = @{ Name = 'designer tools';                 Allow = @('designer', 'developer', 'main');   Hint = 'Ask game-designer or game-developer.' }
    'M9'  = @{ Name = 'other menu items and tools';     Allow = @('developer', 'main');               Hint = 'Only Tools/Design/ menu items and Design_* tools are allowed. Write a Tool Request.' }
    'M10' = @{ Name = 'project/Editor settings, packages'; Allow = @('developer', 'director', 'main'); Hint = 'Send a Request to technical-director.' }
    'M11' = @{ Name = 'builds';                         Allow = @('director', 'main');                Hint = 'Send a Request to technical-director.' }
    'M12' = @{ Name = 'Play Mode and tests';            Allow = $AllRoles;                             Hint = '' }
    'M13' = @{ Name = 'tool not in the tool map';       Allow = @('main');                             Hint = 'Ask the owner to add this tool to hooks/mcp-tool-map.json.' }
}

$DesignMenuPrefix = 'Tools/Design/'
$DesignToolPrefix = 'Design_'
$McpToolPrefix    = 'mcp__unity-mcp__'

# MCP targets must pass these file rules (README: no role reaches the guide, .claude, .meta files
# or generated folders through MCP).
$McpTargetRuleIds = @(1, 2, 3, 4, 5, 6)

# =================================================================================================
# LOGIC
# =================================================================================================

function Block([string] $Message) {
    [Console]::Error.WriteLine("Blocked by role-guard: $Message")
    exit 2
}

function Test-Allowed($Allow, [string] $Role) {
    return @($Allow) -contains $Role
}

function Get-Prop($Object, [string] $Name) {
    # Case-insensitive property read on a JSON object; $null if missing.
    if ($null -eq $Object -or [string]::IsNullOrEmpty($Name)) { return $null }
    $p = $Object.PSObject.Properties[$Name]
    if ($null -eq $p) { return $null }
    return $p.Value
}

function Resolve-Target([string] $ProjectDir, [string] $Path) {
    # Returns @{ Outside = bool; Relative = 'lowercase/path/for/matching'; Display = 'Original/Case/Path'; Full = 'native path' }
    $full = $Path
    if (-not [IO.Path]::IsPathRooted($full)) { $full = Join-Path $ProjectDir $full }
    $full = [IO.Path]::GetFullPath($full)

    $root = [IO.Path]::GetFullPath($ProjectDir).TrimEnd('\', '/')
    $fullN = $full.Replace('\', '/')
    $rootN = $root.Replace('\', '/') + '/'

    if (-not $fullN.StartsWith($rootN, [StringComparison]::OrdinalIgnoreCase)) {
        return @{ Outside = $true; Relative = $fullN.ToLowerInvariant(); Display = $fullN; Full = $full }
    }
    $relative = $fullN.Substring($rootN.Length)
    return @{ Outside = $false; Relative = $relative.ToLowerInvariant(); Display = $relative; Full = $full }
}

function Test-UnityAsset($Target) {
    $ext = [IO.Path]::GetExtension($Target.Relative)
    if ($UnityAssetExtensions -contains $ext) { return $true }
    if (Test-Path -LiteralPath $Target.Full -PathType Leaf) {
        $stream = $null
        try {
            $stream = [IO.File]::OpenRead($Target.Full)
            $buffer = New-Object byte[] 5
            $read = $stream.Read($buffer, 0, 5)
            return ($read -eq 5 -and [Text.Encoding]::ASCII.GetString($buffer) -eq '%YAML')
        }
        finally { if ($stream) { $stream.Dispose() } }
    }
    return $false
}

function Find-FileRule($Target, $RuleIds) {
    foreach ($rule in $FileRules) {
        if ($RuleIds -and -not ($RuleIds -contains $rule.Id)) { continue }
        $match = $false
        switch ($rule.Special) {
            'outside'     { $match = $Target.Outside }
            'unity-asset' { $match = (-not $Target.Outside) -and (Test-UnityAsset $Target) }
            default {
                if (-not $Target.Outside) {
                    foreach ($pattern in $rule.Patterns) {
                        if ($Target.Relative -like $pattern) { $match = $true; break }
                    }
                }
            }
        }
        if ($match) { return $rule }
    }
    return $null
}

function Assert-FileRule([string] $Role, [string] $AgentLabel, $Target, $RuleIds, [string] $Action) {
    $rule = Find-FileRule $Target $RuleIds
    if ($null -eq $rule) { return }   # only possible when checking a subset of rules
    if (-not (Test-Allowed $rule.Allow $Role)) {
        $msg = "$AgentLabel can't $Action $($Target.Display) (file rule $($rule.Id): $($rule.Name))."
        if ($rule.Hint) { $msg += " $($rule.Hint)" }
        Block $msg
    }
}

function Get-McpCapability($Map, [string] $ShortName, $ToolInput) {
    # Returns @{ Capability = 'Mx'; Detail = 'text for messages' }
    $entry = Get-Prop $Map.tools $ShortName

    if ($null -eq $entry) {
        if ($ShortName.StartsWith($DesignToolPrefix, [StringComparison]::Ordinal)) {
            return @{ Capability = 'M8'; Detail = $ShortName }
        }
        return @{ Capability = 'M13'; Detail = $ShortName }
    }

    if ($entry -is [string]) { return @{ Capability = $entry; Detail = $ShortName } }

    # Menu-item tool: Tools/Design/* -> M8, anything else -> M9
    $menuParam = Get-Prop $entry 'menuParam'
    if ($menuParam) {
        $menuPath = [string](Get-Prop $ToolInput $menuParam)
        if ($menuPath.StartsWith($DesignMenuPrefix, [StringComparison]::OrdinalIgnoreCase)) {
            return @{ Capability = 'M8'; Detail = "menu item '$menuPath'" }
        }
        return @{ Capability = 'M9'; Detail = "menu item '$menuPath'" }
    }

    # Generic custom-tool runner: Design_* -> M8, anything else -> M9
    $customParam = Get-Prop $entry 'customToolParam'
    if ($customParam) {
        $customName = [string](Get-Prop $ToolInput $customParam)
        if ($customName.StartsWith($DesignToolPrefix, [StringComparison]::Ordinal)) {
            return @{ Capability = 'M8'; Detail = "custom tool '$customName'" }
        }
        return @{ Capability = 'M9'; Detail = "custom tool '$customName'" }
    }

    # Multi-action tool: look up the action value; unknown actions -> M13
    $actionParam = Get-Prop $entry 'actionParam'
    if ($actionParam) {
        $action = [string](Get-Prop $ToolInput $actionParam)
        $capability = Get-Prop (Get-Prop $entry 'actions') $action
        if ($capability -is [string]) {
            return @{ Capability = $capability; Detail = "$ShortName (action '$action')" }
        }
        return @{ Capability = 'M13'; Detail = "$ShortName (unmapped action '$action')" }
    }

    $fixed = Get-Prop $entry 'capability'
    if ($fixed -is [string]) { return @{ Capability = $fixed; Detail = $ShortName } }

    return @{ Capability = 'M13'; Detail = "$ShortName (invalid map entry)" }
}

# ---- Read the hook input -------------------------------------------------------------------------

# Read and write UTF-8, so non-ASCII paths survive on Windows PowerShell 5.1.
try { [Console]::InputEncoding = New-Object Text.UTF8Encoding $false } catch { }
try { [Console]::OutputEncoding = New-Object Text.UTF8Encoding $false } catch { }

try {
    $raw = [Console]::In.ReadToEnd()
    $hook = $raw | ConvertFrom-Json
}
catch {
    Block 'could not read the hook input, so the call was blocked for safety.'
}

$toolName  = [string](Get-Prop $hook 'tool_name')
$toolInput = Get-Prop $hook 'tool_input'
$agentType = [string](Get-Prop $hook 'agent_type')

# Plugin-scoped names look like "plugin:agent"; only the last part is the role name.
if ($agentType.Contains(':')) { $agentType = $agentType.Substring($agentType.LastIndexOf(':') + 1) }
$role = $RoleByAgentType[$agentType]
if (-not $role) { $role = 'main' }
$agentLabel = if ($role -eq 'main') { 'this session' } else { $agentType }

$projectDir = $env:CLAUDE_PROJECT_DIR
if ([string]::IsNullOrEmpty($projectDir)) { $projectDir = [string](Get-Prop $hook 'cwd') }
if ([string]::IsNullOrEmpty($projectDir)) {
    Block 'could not determine the project folder, so the call was blocked for safety.'
}

# ---- File mode -------------------------------------------------------------------------------------

if (@('Edit', 'Write', 'NotebookEdit') -contains $toolName) {
    $path = [string](Get-Prop $toolInput 'file_path')
    if (-not $path) { $path = [string](Get-Prop $toolInput 'notebook_path') }
    if (-not $path) { Block "$toolName call has no file path, so it was blocked for safety." }

    try { $target = Resolve-Target $projectDir $path }
    catch { Block "could not resolve the path '$path', so the call was blocked for safety." }

    Assert-FileRule $role $agentLabel $target $null 'edit'
    exit 0
}

# ---- MCP mode --------------------------------------------------------------------------------------

if ($toolName.StartsWith($McpToolPrefix, [StringComparison]::Ordinal)) {
    $shortName = $toolName.Substring($McpToolPrefix.Length)

    $mapPath = Join-Path $PSScriptRoot 'mcp-tool-map.json'
    try { $map = Get-Content -LiteralPath $mapPath -Raw -Encoding UTF8 | ConvertFrom-Json }
    catch { Block "could not read hooks/mcp-tool-map.json, so the Unity MCP call was blocked for safety." }
    if ($null -eq (Get-Prop $map 'tools')) {
        Block "hooks/mcp-tool-map.json has no 'tools' section, so the Unity MCP call was blocked for safety."
    }

    $result = Get-McpCapability $map $shortName $toolInput
    $capability = $McpCapabilities[$result.Capability]
    if ($null -eq $capability) {
        Block "the tool map gives $shortName an unknown capability '$($result.Capability)'. Ask the owner to fix hooks/mcp-tool-map.json."
    }
    if (-not (Test-Allowed $capability.Allow $role)) {
        $msg = "$agentLabel can't use $($result.Detail) ($($result.Capability): $($capability.Name))."
        if ($capability.Hint) { $msg += " $($capability.Hint)" }
        Block $msg
    }

    # Targets: every path parameter must pass the protected-path rules (1-6).
    $entry = Get-Prop $map.tools $shortName
    $pathParams = $null
    if ($null -ne $entry -and -not ($entry -is [string])) { $pathParams = Get-Prop $entry 'pathParams' }
    if ($null -eq $pathParams) { $pathParams = Get-Prop $map 'pathParams' }

    foreach ($param in @($pathParams)) {
        if (-not $param) { continue }
        foreach ($value in @(Get-Prop $toolInput $param)) {
            if ($value -isnot [string] -or [string]::IsNullOrWhiteSpace($value)) { continue }
            try { $target = Resolve-Target $projectDir $value }
            catch { Block "could not resolve the path '$value', so the call was blocked for safety." }
            Assert-FileRule $role $agentLabel $target $McpTargetRuleIds 'reach'
        }
    }
    exit 0
}

# Any other tool isn't this guard's business.
exit 0