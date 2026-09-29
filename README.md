# unity-claude-roles

Role subagents for Unity projects in Claude Code: **game-designer**, **game-developer**,
**technical-director**. Conventions are *not* defined here. They come from each project's copy of
a Unity style guide repo (the "guide") at `Guidelines/`. This repo defines only who does what,
and what each role may touch.

## Repositories

This README uses placeholders for both repos. **When integrating into an actual project, the
owner replaces them with the real values** before running any command below:

| Placeholder | Meaning | Example |
|---|---|---|
| `<guide-repo-url>` | Git URL of the style guide repo | `https://github.com/<owner>/<guide-repo>` |
| `<guide-branch>` | Branch of the guide to use | `main` |
| `<roles-repo-url>` | Git URL of this roles repo | `https://github.com/<owner>/<roles-repo>` |
| `<roles-branch>` | Branch of this repo to use | `main` |

The guide must follow the expected layout: `AGENTS.md`, `UnityCustomInstructions/` and
`UnityReferenceGuides/` at its root.

## Contents

| Path | Purpose |
|---|---|
| `game-designer.md`, `game-developer.md`, `technical-director.md` | The role agents |
| `hooks/role-guard.ps1` | Enforces the file rules and Unity MCP rules below |
| `hooks/mcp-tool-map.json` | Maps each Unity MCP tool to a capability; filled in per MCP version |
| `templates/` | Files copied into a project at setup, and templates for project docs |

## Project setup

1. Create the Unity project (Unity 6 or later). Check **Project Settings → Editor → Asset
   Serialization = Force Text** (the default), so agents can read assets as text.
2. Initialise git and add a Unity `.gitignore`.
3. Add the guide (replace the placeholders first, see "Repositories"):
   `git subtree add --prefix=Guidelines <guide-repo-url> <guide-branch> --squash`
4. Add the roles:
   `git subtree add --prefix=.claude/agents/unity-roles <roles-repo-url> <roles-branch> --squash`
5. Copy the templates:
   - `templates/CLAUDE.project.md` → `CLAUDE.md` (project root). Fill in the project name and
     the guide placeholders (`<guide-repo-url>`, `<guide-branch>`).
   - `templates/settings.project.json` → `.claude/settings.json`
6. Create the folders: `Docs/Design/Features/`, `Docs/Design/ToolRequests/`, `Docs/Requests/`,
   `Docs/Tech/`, `Assets/Editor/DesignPatches/`.
7. Open Claude Code in the project root and **accept the workspace trust prompt**.
   The guard doesn't run until you do.
8. Ask **technical-director** to fill in the tech stack, including whether this project uses
   Unity MCP.
9. Copy `templates/tool-request-design-patch.md` to
   `Docs/Design/ToolRequests/DesignPatchTool.md`. Ask **game-designer** to fill it in, then
   **game-developer** to build the tool for this project.

## Updating

- Roles: `git subtree pull --prefix=.claude/agents/unity-roles <roles-repo-url> <roles-branch> --squash`
- Guide: `git subtree pull --prefix=Guidelines <guide-repo-url> <guide-branch> --squash`

Use the same repo URLs and branches the project was set up with.

Each project stays on the version it last pulled. Updating one project never changes another.

## Roles

| Role | Owns |
|---|---|
| game-designer | Mechanics, balancing, specs, level design. Builds and tunes scenes, prefabs and assets in the Editor; edits design data. Never code. |
| game-developer | All code, including Editor tools for the designer. Can also do anything the designer can. |
| technical-director | Per-project tech stack, packages and plugins, Unity MCP setup, build setup (template), build-size analysis (template). |

## Changing Unity assets

No agent writes Unity YAML files (scenes, prefabs, ScriptableObjects, …) with file tools.
Agents may read them. The guide requires changes to go through the Editor. There are three ways:

- **Unity MCP**, when the project uses it. This is the main way: the designer and developer
  build levels and change values in the live Editor. See "Unity MCP rules".
- **Design patches**, the fallback when the project doesn't use Unity MCP or the Editor is
  closed. Each project builds its own Design Patch tool, specified in
  `Docs/Design/ToolRequests/DesignPatchTool.md`. Patch files always go in
  `Assets/Editor/DesignPatches/`.
- **Data files** (`.json` / `.csv`), for tables. How each file reaches the game depends on the
  tool or plugin chosen per project.

Tools the developer builds for the designer are marked by name: menu items under
`Tools/Design/`, and custom Unity MCP tools named `Design_*`.

## File rules

Checked by the guard on every file edit. Rows are checked top-down; the first match wins.
"Main" is your own session and any agent that isn't one of the three roles.

| # | Path | Designer | Developer | Director | Main |
|---|---|---|---|---|---|
| 1 | Anything outside the project folder | ✗ | ✗ | ✗ | ✗ |
| 2 | `*.meta` | ✗ | ✗ | ✗ | ✗ |
| 3 | `Library/` `Temp/` `obj/` `Logs/` `UserSettings/` `Packages/packages-lock.json` | ✗ | ✗ | ✗ | ✗ |
| 4 | `.claude/**`, root `CLAUDE.md` | ✗ | ✗ | ✗ | ✗ |
| 5 | Guide project tier: `Guidelines/AGENTS.md`, `Guidelines/UnityCustomInstructions/**` | ✗ | ✗ | ✓ | ✗ |
| 6 | Rest of `Guidelines/**` | ✗ | ✗ | ✗ | ✗ |
| 7 | `Packages/manifest.json`, `ProjectSettings/**` | ✗ | ✓ ¹ | ✓ | ✓ ¹ |
| 8 | Design patches: `Assets/Editor/DesignPatches/**` | ✓ | ✓ | ✗ | ✓ |
| 9 | Graph assets: `*.shadergraph` `*.shadersubgraph` `*.vfx` | ✓ ³ | ✓ ³ | ✗ | ✓ |
| 10 | Unity YAML assets (scenes, prefabs, ScriptableObjects, materials, …) ² | ✗ | ✗ | ✗ | ✗ |
| 11 | Code: `*.cs` `*.asmdef` `*.asmref` `*.shader` `*.hlsl` `*.cginc` `*.compute` | ✗ | ✓ | ✗ | ✓ |
| 12 | Data in `Assets/`: `*.json` `*.csv` `*.tsv` `*.data` | ✓ | ✓ | ✗ | ✓ |
| 13 | `Docs/Design/**` | ✓ | ✓ | ✗ | ✓ |
| 14 | `Docs/Requests/**` | ✓ | ✓ | ✓ | ✓ |
| 15 | `Docs/Tech/**`, `.gitignore`, `.gitattributes`, `.mcp.json` | ✗ | ✓ | ✓ | ✓ |
| 16 | Anything else | ✗ | ✓ | ✗ | ✓ |

¹ Allowed, but a Package Request to technical-director is strongly preferred.
² Detected by the file's `%YAML` header, or by a Unity asset extension for new files.
  Use Unity MCP, a design patch, or the Editor instead.
³ Temporary. These move to a future technical-artist role.

Rows 2–6 and 10 are yours to change by hand.

## Unity MCP rules

Apply when the project uses the official Unity MCP (server name `unity-mcp`). Unity approves the
Claude Code client once and can't tell roles apart, so these rules are the only role separation.
The guard enforces them using `hooks/mcp-tool-map.json`.

| # | Capability | Designer | Developer | Director | Main |
|---|---|---|---|---|---|
| M1 | Read: inspect scenes, GameObjects, components and assets; read the Console | ✓ | ✓ | ✓ | ✓ |
| M2 | Scene building: create, delete, move GameObjects; add or remove components; set values | ✓ | ✓ | ✗ | ✓ |
| M3 | Asset editing: set ScriptableObject, material and prefab values; create prefabs and assets | ✓ | ✓ | ✗ | ✓ |
| M4 | Scenes: create, open, save | ✓ | ✓ | ✗ | ✓ |
| M5 | Delete, move or rename assets in the project | ✗ ⁴ | ✓ ⁵ | ✗ | ✓ |
| M6 | Scripts: create, edit, delete C# | ✗ | ✓ | ✗ | ✓ |
| M7 | Run arbitrary code in the Editor | ✗ | ✓ ⁵ | ✗ | ✓ |
| M8 | Designer tools: menu items under `Tools/Design/`, custom tools named `Design_*` | ✓ | ✓ | ✗ | ✓ |
| M9 | Any other menu item or custom tool | ✗ | ✓ ⁵ | ✗ | ✓ |
| M10 | Project and Editor settings, packages | ✗ | ✓ ¹ | ✓ | ✓ |
| M11 | Builds (details later) | ✗ | ✗ | ✓ | ✓ |
| M12 | Play Mode and tests | ✓ | ✓ | ✓ | ✓ |
| M13 | Any tool not yet in the tool map | ✗ | ✗ | ✗ | ✓ |

⁴ Write a Change Request instead.
⁵ Only when named explicitly, item by item, in the approved plan.

The file rules still apply to MCP targets: no role reaches `Guidelines/`, `.claude/`, `.meta`
files or generated folders through MCP either.

Behavior rules for all roles:

1. **Plan.** Every plan lists the MCP capabilities it will use. Deletions (M5), code execution
   (M7) and other menu items or tools (M9) are listed individually.
2. **Shared Editor.** You and the agent use the same open Editor. Before changing a scene, check
   it has no unsaved changes that aren't the agent's. If it does, stop and report.
3. **Save only your own changes.** Never save a scene or prefab the agent didn't change. Save
   what it did change at the end of the apply step, and list it in the report.
4. **No Editor, no workaround.** If MCP isn't connected, use design patches or report back.
   Never fall back to writing YAML.
5. **Unknown tools are blocked.** A new or unmapped MCP tool is blocked for every role until it's
   added to the tool map (M13).

## Shell rule

- Roles avoid the shell. They use it only when there's no other way.
- When they do, the plan must list each shell command and why it's needed, under a separate
  **"Shell usage (needs your approval)"** heading.
- Shell commands run only after the owner explicitly approves that shell usage. As a second
  check, the project settings make Claude Code ask you before every shell command.
- The guard can't check what a shell command does; your approval is the check.
- The designer has no shell.

## How the roles work

- **Plan, then apply.** A role returns a plan and stops. Your main session shows you the plan and
  resumes the role only after you approve. Subagents can't ask you questions directly.
- **Requests between roles** go in `Docs/` using the templates:
  - Feature Spec: designer → developer
  - Tool Request: designer → developer
  - Change or Package Request: any role → the owning role
  - Guideline Proposal: any role → you
- **Guideline Proposals** are the only way conventions change. You apply them in the guide repo
  as a separate update, then pull it into projects.
- **No role runs `git commit` or `git push`.** The technical-director's `git subtree add` commits
  by itself; it's a shell command, so it needs your approval like any other.