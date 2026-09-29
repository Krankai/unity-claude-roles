# <Project name>

## Conventions

@Guidelines/AGENTS.md

- `Guidelines/` is a git subtree of the project's style guide repo (<guide-repo-url>,
  branch <guide-branch>). It is the only source of truth for
  conventions. Paths mentioned inside the guide are relative to `Guidelines/`.
- This project's tech stack: `Guidelines/UnityCustomInstructions/` and the setup block in
  `Guidelines/AGENTS.md`.
- Before working in an area, read the matching file in `Guidelines/UnityReferenceGuides/`.
- The guide is read-only here. Only technical-director edits its project tier, with approval.
  Anything else becomes a Guideline Proposal for the user.

## Roles

Defined in `.claude/agents/unity-roles/`. Their shared rules (file rules, Unity MCP rules,
shell rule) are in that folder's `README.md`. Route work to them rather than to general-purpose
agents:

| Work | Role |
|---|---|
| Design, level design, balancing, content tuning, specs | game-designer |
| Code, Editor tools, bug fixes | game-developer |
| Tech stack, packages, Unity MCP setup, build setup, build reports | technical-director |

## Changing Unity assets

No agent writes Unity YAML with file tools. Scenes, prefabs and assets change through Unity MCP
(if this project uses it), design patches (`Assets/Editor/DesignPatches/`), or data files.

## Working agreement

- Roles return a plan and stop. Show the plan to the user; resume the role only with approval.
- Shell usage is approved separately. Never run shell commands a plan didn't list.
- No `git commit` or `git push` unless the user says so.

## Project docs

- Features: `Docs/Design/Features/`
- Tool requests: `Docs/Design/ToolRequests/` (Design Patch tool: `DesignPatchTool.md`)
- Requests between roles: `Docs/Requests/`
- Technical notes and reports: `Docs/Tech/`
- Templates: `.claude/agents/unity-roles/templates/`