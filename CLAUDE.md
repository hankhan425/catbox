# catbox

Multi-template workspace images for the Comfycat platform. Each template is a Docker image that runs inside a Fly Machine, containing the workspace agent + Claude Code + a pre-scaffolded app.

## Structure

```
agent/              # Shared workspace agent (Elixir/Plug HTTP server)
templates/
  default/          # Blank Phoenix app (no Ecto, no mailer)
  phoenix-full/     # Phoenix with Ecto + PostgreSQL
Dockerfile.base     # Base image: Elixir + Node + Claude Code + agent
.github/workflows/  # CI: builds and pushes images to GHCR
```

## How It Works

1. `Dockerfile.base` builds the base image with system deps, Claude Code, and the agent release
2. Each `templates/*/Dockerfile` extends the base image and pre-scaffolds a specific app type
3. Comfycat selects the right image when creating a Fly Machine based on the user's chosen template

## Image Naming

- Base: `ghcr.io/{owner}/comfycat-machines-base`
- Templates: `ghcr.io/{owner}/comfycat-machines-{template-name}` (e.g., `comfycat-machines-default`)

## Agent

Minimal Elixir/Plug HTTP server that runs alongside Claude Code. See `agent/` for source.

### Endpoints

- `GET /health` — readiness probe (no auth)
- `POST /exec` — execute a command, stream output via SSE
- `PUT /files` — write a file to disk

### Auth

All endpoints except `/health` require `Authorization: Bearer <AGENT_TOKEN>` header.

### Environment Variables

- `AGENT_TOKEN` — bearer token for auth (required)
- `AGENT_PORT` — port to listen on (default: 9090)
- `ANTHROPIC_API_KEY` — passed through to Claude Code

## Commands

```bash
cd agent
mix deps.get     # Install dependencies
mix test         # Run tests
mix compile      # Compile
```

## Adding a New Template

1. Create `templates/{name}/Dockerfile` extending the base image
2. Pre-scaffold the app in the Dockerfile (install deps, compile)
3. Push to main — CI will build and push `comfycat-machines-{name}` to GHCR
4. Add the template to `Comfycat.Templates` in the comfycat repo with `image: "ghcr.io/{owner}/comfycat-machines-{name}:latest"`
