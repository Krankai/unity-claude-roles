# Tool Request: Design Patch tool

Status: Not started
Requested by: game-designer · Date: <YYYY-MM-DD>

> Project-specific. Each project builds its own Design Patch tool.
> Patch files always live in `Assets/Editor/DesignPatches/`; everything else is decided here.

## Purpose
<!-- Which kinds of values this project's tool must cover (ScriptableObjects, prefabs, scenes). -->

## Inputs
<!-- Patch file format and naming. -->

## Outputs
<!-- What changes, and how results are reported back to the agent. -->

## Restrictions
- **All or nothing:** validate every change in the patch before applying any of them. If even
  one change is invalid, apply none: reject the whole patch and report *every* problem found,
  not only the first.
<!-- Project-specific validation rules. -->

## Trigger
<!-- Automatic, menu item under Tools/Design/, custom MCP tool Design_*, or a mix. -->

## Acceptance criteria
- [ ]

## Usage
<!-- Filled in by game-developer when the tool is ready. -->
