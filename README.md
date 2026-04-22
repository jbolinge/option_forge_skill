# option_forge

Strategy-authoring workspace for [OptionForge](https://option-forge.com), a hosted Lua (Luau) options-backtesting platform. Scripts here are pasted into the OptionForge web UI — they do **not** execute locally.

## What's in here

- `strategies/` — finished `.lua` strategies
- `docs/` — API cheat sheet (`brief_api.txt`), full reference (`api_docs.txt`), and runnable reference strategies
- `skills/option-forge-strategy/` — portable [claude.ai Skill](https://www.anthropic.com/news/skills) bundle
- `skills/build.sh` — packages the Skill into an uploadable zip
- `.claude/commands/strategy.md` — `/strategy` slash command for Claude Code users who clone this repo
- `CLAUDE.md` — project guidance for Claude Code

## Use with Claude Code

Clone the repo, open it in Claude Code, and run:

```
/strategy put credit spread 15-delta 10-wide weekly
```

## Use with claude.ai (Skill)

The Skill makes Claude on claude.ai draft OptionForge strategies without needing the local repo.

### 1. Build the zip

Requires `bash` and `zip` on PATH.

```sh
./skills/build.sh
```

This copies the latest `docs/brief_api.txt` and reference `.lua` files into the bundle and writes `skills/option-forge-strategy.zip`. The zip is git-ignored — rebuild and re-upload whenever the API docs or reference strategies change.

### 2. Upload to claude.ai

1. Go to [claude.ai](https://claude.ai) → **Settings → Capabilities → Skills** (the exact label may change; look for the Skills section).
2. Choose **Upload skill** and select `skills/option-forge-strategy.zip`.
3. Enable it for the conversations or project where you want OptionForge drafting.

### 3. Use it

In a chat with the Skill enabled, just describe the strategy ("put credit spread, 15 delta, 10 wide, weekly entries"). The Skill triggers automatically from its description — there is no slash command on claude.ai.

## License

GPLv3 — see [LICENSE](LICENSE).
