# Copilot Ecosystem — Complete Reference

## Three Separate Products

They share the name "Copilot" but work independently.

```
┌─────────────────────┐  ┌──────────────────────┐  ┌──────────────────────┐
│  1. COPILOT CHAT    │  │ 2. COPILOT CLI       │  │ 3. COPILOT CODING   │
│     (VS Code)       │  │    (Terminal)         │  │    AGENT (GitHub)   │
│                     │  │                       │  │                      │
│ • Chat panel in     │  │ • gh copilot suggest  │  │ • Assign issue to   │
│   VS Code sidebar   │  │ • gh copilot explain  │  │   Copilot on GitHub │
│ • Inline completions│  │ • Runs in your        │  │ • Creates PRs auto  │
│ • Copilot Edits     │  │   terminal            │  │ • Runs in GitHub VM │
│ • @workspace, etc.  │  │                       │  │   or locally        │
└────────┬────────────┘  └──────────┬────────────┘  └──────────┬───────────┘
         │                          │                           │
         ▼                          ▼                           ▼
Reads instructions from:   Reads config from:          Reads config from:
.github/ + .vscode/       ~/.copilot/                  ~/.copilot/
                            (shared)                    (shared)
```

---

## Where Files Live & What They Control

```
YOUR REPO (e.g. c:\Bicep_GithubCode\)
├── .github/
│   ├── copilot-instructions.md  ◄── Copilot CHAT reads this (repo-level)
│   └── rules/
│       ├── general.md           ◄── Component rules (referenced by above)
│       ├── bicep-conventions.md
│       ├── deploy-script.md
│       ├── validate-script.md
│       ├── cleanup-script.md
│       └── documentation.md
│
├── .vscode/
│   ├── mcp.json                 ◄── MCP servers for VS Code (workspace)
│   ├── *.prompt.md              ◄── Reusable prompt templates
│   └── *.agent.md               ◄── Custom chat agents
│
└── CLAUDE.md                    ◄── Claude Code (Anthropic CLI) — NOT
                                     Copilot. Separate product entirely.


YOUR HOME (~\  = C:\Users\<you>\)
├── .github/
│   └── copilot-instructions.md  ◄── Copilot CHAT global (all repos)
│
├── .copilot/                    ◄── Copilot CLI + Coding Agent ONLY
│   ├── config.json                  (NO effect on Copilot Chat)
│   ├── mcp-config.json         ◄── Global MCP servers for CLI/agent
│   ├── permissions-config.json  ◄── Tool permissions for agent
│   ├── pkg/                     ◄── Runtime binaries (node, ripgrep, etc.)
│   ├── logs/
│   └── session-state/
│
├── .agents/                     ◄── Skills for VS Code Copilot Chat
│   └── skills/                      (azure-*, microsoft-foundry, etc.)
│
└── .copilot-cli/                ◄── Copilot CLI binary/cache
```

---

## Instructions — Who Reads What

| Product | Reads from |
|---------|------------|
| **Copilot Chat** (VS Code) | 1. `~/.github/copilot-instructions.md` (user-global) |
| | 2. `repo/.github/copilot-instructions.md` (repo-level) |
| | 3. `.vscode/*.agent.md` (if invoked) |
| | 4. `.vscode/*.prompt.md` (if invoked) |
| **Copilot CLI + Coding Agent** | 1. `~/.copilot/config.json` |
| | 2. `~/.copilot/mcp-config.json` |
| | 3. `~/.copilot/permissions-config.json` |
| **Claude Code** (Anthropic CLI) | 1. `repo/CLAUDE.md` |
| | 2. `~/.claude/settings.json` |
| | ⚠️ NOT related to Copilot at all |

---

## MCP Servers — Two Separate Configs

| Surface | Config location |
|---------|-----------------|
| VS Code Copilot Chat | `.vscode/mcp.json` (per workspace) or VS Code Settings (user-global) |
| Copilot CLI / Coding Agent | `~/.copilot/mcp-config.json` (global) |

> ⚠️ These two DO NOT share MCP servers. Configure separately.

---

## Quick Cheat Sheet

| I want to... | Go to... |
|---|---|
| Copilot Chat follow my rules (this repo) | `.github/copilot-instructions.md` ✅ |
| Rules for ALL my repos in Chat | `~/.github/copilot-instructions.md` |
| Add MCP tools to Chat | `.vscode/mcp.json` |
| Add MCP tools to CLI/agent | `~/.copilot/mcp-config.json` |
| Claude Code follow my rules | `CLAUDE.md` (not Copilot) |
| Know what `~/.copilot/` is | CLI + Coding Agent runtime. Ignore for Chat. |
