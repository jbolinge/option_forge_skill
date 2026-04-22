# option_forge

Gives Claude the ability to write Lua strategies for [OptionForge](https://option-forge.com) — either via a portable claude.ai Skill, or via a `/strategy` slash command in Claude Code.

**About OptionForge.** OptionForge is a hosted options-backtesting platform where strategies are authored in Lua (Luau dialect) and run against historical option-chain archives (SPX, etc.). You paste a script into the web UI at `/forge/` for a single run or `/grid-search/` for parameter sweeps; scripts do not execute locally. The API is a Portfolio → Trade → Leg object model with selector-based leg placement (`Delta`, `Strike`, `Mid`, ...). Full docs live at [option-forge.com/docs](https://option-forge.com/docs/).

## What's in here

- `strategies/` — finished `.lua` strategies
- `docs/` — API cheat sheet (`brief_api.txt`), full reference (`api_docs.txt`), and runnable reference strategies
- `skills/option-forge-strategy/` — portable [claude.ai Skill](https://www.anthropic.com/news/skills) bundle
- `skills/option-forge-strategy.zip` — prebuilt, ready-to-upload Skill zip (checked in)
- `skills/build.sh` — rebuilds the zip from `skills/option-forge-strategy/` and the latest `docs/`
- `.claude/commands/strategy.md` — `/strategy` slash command for Claude Code users who clone this repo
- `CLAUDE.md` — project guidance for Claude Code

## Use with claude.ai (Skill)

The Skill lets Claude on claude.ai draft OptionForge strategies without the local repo.

### 1. Get the zip

A prebuilt zip is checked into the repo at `skills/option-forge-strategy.zip` — grab that and skip to step 2.

If you've edited the Skill sources under `skills/option-forge-strategy/` or updated `docs/`, rebuild it (requires `bash` and `zip` on PATH):

```sh
./skills/build.sh
```

This copies the latest `docs/brief_api.txt` and reference `.lua` files into the bundle and overwrites `skills/option-forge-strategy.zip`.

### 2. Upload to claude.ai

1. Go to [claude.ai](https://claude.ai) → **Settings → Capabilities → Skills** (the exact label may change; look for the Skills section).
2. Choose **Upload skill** and select `skills/option-forge-strategy.zip`.
3. Enable it for the conversations or project where you want OptionForge drafting.

### 3. Use it

In a chat with the Skill enabled, just describe the strategy ("put credit spread, 15 delta, 10 wide, weekly entries"). The Skill triggers automatically from its description — there is no slash command on claude.ai.

## Use with Claude Code

Clone the repo, open it in Claude Code, and run:

```
/strategy put credit spread 15-delta 10-wide weekly
```

## License

GPLv3 — see [LICENSE](LICENSE).
