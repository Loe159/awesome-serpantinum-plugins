# AI Agents

Serpantinum plugin for monitoring local AI coding agents. V1 implements Codex through its local app-server protocol.

Features: Codex sessions and state, 5-hour/weekly remaining quota, recent sessions, last assistant message, Waiting notifications, terminal focus/resume, and launching new agents with Codex-discovered models and permission profiles.

Requires Serpantinum plugin framework support for manifest `barEntries` (included on the `feature/pluginset` branch of `serpantinum-plugins`).

Version 0.1.3 restores the Codex SVG logo in the bar and panel, themed Serpantinum
controls for session creation and settings, animated panel transitions, and
outside-click dismissal. The icon-only Refresh retains its full 360° animation.
Settings are available both from the panel gear and Settings → Plugins → AI Agents.
