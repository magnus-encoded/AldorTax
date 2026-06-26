---
name: inner-cartographer
description: Map and document the internal structure of a codebase. Use when you need a navigational guide to understand how a project is organized — key files, modules, data flows, and relationships — so you can move through unfamiliar code quickly.
---

# Inner Cartographer

Explore the codebase and produce a structural map: what exists, where it lives, and how the pieces connect.

## Workflow

Make a todo list for all the tasks in this workflow and work on them one after another.

### 1. Survey the Territory

Get a high-level picture of the project:

```bash
# Directory structure (skip node_modules, .git, build output)
find . -type f \( -not -path '*/.git/*' -not -path '*/node_modules/*' -not -path '*/dist/*' \) | sort

# Read README and any existing architecture docs
cat README.md 2>/dev/null
```

Also read:
- `CLAUDE.md` or `.claude/CLAUDE.md` if present
- Any top-level config files (package.json, *.toml, *.yaml) for project type and entry points

### 2. Identify Entry Points

Find where execution starts:

- **Scripts / CLI**: look for `main`, `__main__`, `init`, binary entry points
- **Libraries**: exported symbols in index files
- **Addons / plugins**: declared entry files in manifests (e.g. `## Interface`, `# toc`, `main.lua`, `plugin.json`)
- **Servers**: request handlers, route definitions

### 3. Trace Key Data Flows

Follow the data from input to output:

1. Where does external data arrive? (user input, network, files, game events)
2. How is it transformed or stored? (state objects, data structures, caches)
3. Where does it go out? (UI, network, files, other systems)

Read the files at each stage; don't just list filenames.

### 4. Catalogue Modules and Responsibilities

For each significant file or module, record:
- **What it owns**: the concept or resource it manages
- **Public surface**: functions/methods/events/messages it exposes
- **Dependencies**: what it imports or calls

Group by layer (e.g. data layer, logic layer, UI layer) when a natural grouping exists.

### 5. Identify Key Abstractions

Note the 3-7 central concepts the codebase is built around. For each:
- Its name and what it represents
- Where it is defined
- Where it is used

### 6. Note Surprises and Non-Obvious Patterns

Flag anything that would trip up a new reader:
- Implicit conventions (naming, file placement, event naming)
- State shared across modules in a non-obvious way
- Performance-sensitive paths
- Known quirks or workarounds in the code (look for comments)

### 7. Write the Map

Produce (or update) `CODEBASE-MAP.md` in the project root:

```markdown
# Codebase Map

## Project Overview
One paragraph: what the project does and its primary technology.

## Entry Points
- `path/to/file.ext` — what starts here

## Module Catalogue

### Layer: <name>
| File | Owns | Exposes |
|------|------|---------|
| `path/to/file` | brief description | key symbols |

## Key Abstractions
1. **ConceptName** (`path/to/definition`) — what it is and why it matters
2. ...

## Data Flow
```
Input source → transform (file) → store (file) → output sink
```

## Non-Obvious Patterns
- Pattern or convention and where to see it
```

Keep entries short. The map is for navigation, not exhaustive documentation.

### 8. Validate the Map

Re-read the map and ask:
- Can a reader find any major file from the map?
- Does the data flow actually match the code?
- Are the key abstractions the right ones, or did you miss one?

Fix anything that's wrong before finishing.

## Wrap Up

Report to the user:
- What the map covers and where `CODEBASE-MAP.md` was written
- Any areas that were unclear or incomplete (and why)
- Suggested next steps if the codebase has a complex area worth a deeper dive
