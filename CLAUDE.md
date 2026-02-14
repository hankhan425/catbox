# Comfycat Workspace Agent

Lightweight HTTP agent that runs inside Fly Machines to execute commands and stream output for the Comfycat platform.

## Architecture

This is a minimal Elixir/Plug HTTP server (no Phoenix, no Ecto) that runs alongside Claude Code inside a Docker container on Fly Machines. Comfycat creates one machine per user project and communicates with this agent over HTTPS.

## Endpoints

- `GET /health` — readiness probe (no auth)
- `POST /exec` — execute a command, stream output via SSE
- `PUT /files` — write a file to disk

## Auth

All endpoints except `/health` require `Authorization: Bearer <AGENT_TOKEN>` header. The token is set via `AGENT_TOKEN` env var at machine creation time.

## Environment Variables

- `AGENT_TOKEN` — bearer token for auth (required)
- `AGENT_PORT` — port to listen on (default: 9090)
- `ANTHROPIC_API_KEY` — passed through to Claude Code

## Commands

```bash
mix deps.get     # Install dependencies
mix test         # Run tests
mix compile      # Compile
MIX_ENV=prod mix release  # Build release
```

## Tech Stack

- Elixir 1.19.5, OTP 28
- Plug + Bandit (HTTP server)
- Jason (JSON)
- No external dependencies beyond these three
