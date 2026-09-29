# Pilot checklist

Verify the roles on a real pilot project before relying on them. Tick each item; note anything
that fails under "Findings" at the bottom, fix it in this repo, then re-test (section 7).

Status: pre-pilot (v0.1). Nothing below has been verified on a real project yet.

---

## 0. Before you start

- [ ] Roles repo is pushed; you know its URL and branch.
- [ ] You know the guide repo URL and branch.
- [ ] A throwaway Unity 6 project exists (6.3 LTS; ideally a second one on 6.6 for section 5).
- [ ] Quick guard check on Windows PowerShell 5.1 (no Unity needed). From this repo's folder:
      ```powershell
      '{"tool_name":"Edit","tool_input":{"file_path":"C:\\tmp\\proj\\Assets\\A.cs"},"agent_type":"game-designer","cwd":"C:\\tmp\\proj"}' | powershell -NoProfile -ExecutionPolicy Bypass -File .\hooks\role-guard.ps1; $LASTEXITCODE
      ```
      Expected: a "Blocked by role-guard … file rule 11: code" message, then `2`.

## 1. Set up the pilot project

Follow README → Project setup, replacing `<guide-repo-url>`, `<guide-branch>`,
`<roles-repo-url>`, `<roles-branch>` with the real values.

- [ ] Asset Serialization is Force Text.
- [ ] `Guidelines/` subtree added.
- [ ] `.claude/agents/unity-roles/` subtree added.
- [ ] `CLAUDE.md` copied from the template; project name and guide placeholders filled in.
- [ ] `.claude/settings.json` copied from the template.
- [ ] Doc and patch folders created.
- [ ] Workspace trust prompt accepted in Claude Code.

## 2. Claude Code mechanics (Windows)

| # | Check | Expected | If it fails |
|---|---|---|---|
| 2.1 | Run `/agents` or type `@` | Exactly three role agents: game-designer, game-developer, technical-director. No README, checklist or templates listed as agents. | A file may start with `---`; remove the frontmatter. |
| 2.2 | Ask the main session to edit `CLAUDE.md` | Blocked by role-guard (file rule 4) | Hook not running: check 2.3–2.5. |
| 2.3 | Hook form `"shell": "powershell"` is accepted | No settings error on startup | Replace with `"command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"%CLAUDE_PROJECT_DIR%\\.claude\\agents\\unity-roles\\hooks\\role-guard.ps1\""` (or the form the docs require) and remove `"shell"`. |
| 2.4 | `CLAUDE_PROJECT_DIR` is set for hooks | Guard finds the project folder | Guard falls back to `cwd` automatically; only a problem if messages say "could not determine the project folder". |
| 2.5 | Execution policy | Script runs | Use the `-ExecutionPolicy Bypass` command form. |
| 2.6 | Before accepting trust (fresh clone) | Guard does not run | Expected behaviour; just confirm. |
| 2.7 | Guard sees role names | A designer edit to a `.cs` file is blocked with "game-designer can't edit …" | If the message says "this session", `agent_type` differs: log it and update `$RoleByAgentType`. |
| 2.8 | Guide import | Ask any role "what Unity version and UI system does this project use?" → answers from `Guidelines/` | Check the `@Guidelines/AGENTS.md` line in `CLAUDE.md`. |
| 2.9 | Guide links | A role asked about UniTask reads `Guidelines/UnityReferenceGuides/UnityUniTaskInstructions.md` | Add a clearer path note to `CLAUDE.md`. |
| 2.10 | Shell prompt | Any shell command triggers a permission prompt | Check `permissions.ask` in `.claude/settings.json`, and that you aren't in bypass mode. |
| 2.11 | Calling a role | `@agent-game-designer …` runs the designer; `claude --agent game-designer` makes the session the designer | — |
| 2.12 | Resume after plan | "Approved, continue with game-designer" resumes the same agent and applies the plan | Ask Claude for the agent ID and resume by ID. |

## 3. Guard: blocks (each must be refused with a useful message)

- [ ] Designer edits a `.cs` file → file rule 11.
- [ ] Designer writes a new `.prefab` file → file rule 10.
- [ ] Developer edits an existing `.unity` file as text → file rule 10.
- [ ] Any role edits a `.meta` file → file rule 2.
- [ ] Developer edits `Guidelines/UnityStyleGuide.md` → file rule 6.
- [ ] Developer edits `Guidelines/UnityCustomInstructions/UnityTechStack.md` → file rule 5.
- [ ] Technical-director edits a `.cs` file → file rule 11.
- [ ] Any role edits `.claude/settings.json` → file rule 4.
- [ ] Any role writes outside the project folder (e.g. `..\x.txt`) → file rule 1.
- [ ] Designer edits `ProjectSettings/TagManager.asset` → file rule 7.

## 4. Guard: allowed (each must go through)

- [ ] Designer edits a `.json` / `.csv` in `Assets/`.
- [ ] Designer writes a file in `Assets/Editor/DesignPatches/`.
- [ ] Designer edits a `.shadergraph` file.
- [ ] Designer writes to `Docs/Design/` and `Docs/Requests/`.
- [ ] Developer edits a `.cs` file.
- [ ] Technical-director edits `UnityTechStack.md` and `Packages/manifest.json` (Editor closed).

## 5. Unity MCP (only if the project will use it)

### 5.1 Set up
- [ ] Install `com.unity.ai.assistant` (docs: 6000.0.76f1, 6.3, or later).
- [ ] Create `.mcp.json` from the template. Windows relay path per the docs:
      `%USERPROFILE%\.unity\relay\relay_win.exe`, args `["--mcp"]`. Confirm it exists.
- [ ] Accept the Claude Code client in Project Settings → AI → Unity MCP.
- [ ] `/mcp` in Claude Code shows `unity-mcp` connected.

### 5.2 Record the real tool list
In each Unity version you use (6.3 LTS and 6.6), from Project Settings → AI → Unity MCP → Tools or `/mcp`:
- [ ] Exact tool names. The docs are inconsistent: `Unity_ManageScene` vs `Unity.ManageScene`.
- [ ] For multi-action tools: the action parameter name and its values.
- [ ] Which parameters hold file paths (for `pathParams`).
- [ ] Differences between 6.3 LTS and 6.6. One lead: a changelog note ties `RunCommand` to Unity 6.5+.

### 5.3 Starting point for the tool map (from the package 2.0 API docs, unverified for 2.11+)

| Tool | Proposed capability |
|---|---|
| ReadConsole, GetSHA, ResourceTools, ValidateScript, ManageScriptCapabilities | M1 |
| ManageGameObject | find/get → M1; create/modify/delete/components → M2 |
| ManageScene | hierarchy → M1; load/save/create → M4 |
| ManageAsset | info/search → M1; create/modify → M3; delete/move/rename → M5 |
| ManageEditor | state → M1; play/pause/stop → M12; tags/layers/settings → M10 |
| ManageMenuItem | list/exists/refresh → M1; execute → M8 (`Tools/Design/…`) or M9 |
| ImportExternalModel | M9 |
| ManageScript, CreateScript, DeleteScript, ApplyTextEdits, ScriptApplyEdits, ManageShader | M6 |
| RunCommand | M7 |

### 5.4 Guard change needed before MCP goes live
- [ ] `ManageMenuItem` combines an action with a menu path. The guard currently handles either an
      action-based tool or a menu tool, not both. Extend `role-guard.ps1` so an action can hand
      off to the `Tools/Design/` check, and add tests.
- [ ] Fill in `hooks/mcp-tool-map.json`, commit to the roles repo.

### 5.5 MCP tests
- [ ] Designer reads a scene hierarchy (M1) → allowed.
- [ ] Designer creates a GameObject and adds a component (M2) → allowed.
- [ ] Designer deletes an asset (M5) → blocked.
- [ ] Designer runs `Tools/Design/…` menu item (M8) → allowed; any other menu item (M9) → blocked.
- [ ] Designer uses a script tool (M6) or RunCommand (M7) → blocked.
- [ ] Any role calls a tool missing from the map (M13) → blocked.
- [ ] Any MCP call targeting `Guidelines/` or a `.meta` file → blocked.
- [ ] Shared Editor: with unsaved changes of yours in a scene, the designer stops and reports.

## 6. End-to-end flows (plan → approve → apply → report)

- [ ] Designer: small level edit via Unity MCP (or a data-file change if no MCP).
- [ ] Designer + developer: fill in `DesignPatchTool.md`, developer builds the tool, designer
      applies one patch; a patch with one bad change is rejected as a whole (all or nothing).
- [ ] Designer writes a Tool Request; developer builds a `Tools/Design/…` tool; designer uses it.
- [ ] Technical-director: add one package end to end, including the tech stack record.
- [ ] A role spots a guide issue and returns a Guideline Proposal instead of working around it.
- [ ] A plan that needs the shell lists it under "Shell usage (needs your approval)", and runs
      only after approval.

## 7. Update path

- [ ] Fix any findings in the roles repo, push.
- [ ] `git subtree pull` into the pilot project; changes arrive; re-run the failed checks.
- [ ] Update "Status" at the top of this file (e.g. "verified on pilot, <date>").

## Findings

| # | Check | What happened | Fix |
|---|---|---|---|
| | | | |