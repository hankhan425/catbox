# catbox

Multi-template workspace images for the Comfycat platform. Each template is a Docker image that runs inside a Fly Machine, containing the workspace agent + Claude Code + a pre-scaffolded app.

## Structure

```
agent/              # Shared workspace agent (Elixir/Plug HTTP server)
packages/
  comfycat_embed/   # Elixir package: iframe + inspector plugs for generated apps
templates/
  default/          # Blank Phoenix app (no Ecto, no mailer)
  phoenix-full/     # Phoenix with Ecto + PostgreSQL
Dockerfile.base     # Base image: Elixir + Node + Claude Code + agent + comfycat_embed
.github/workflows/  # CI: builds and pushes images to Fly registry
```

## How It Works

1. `Dockerfile.base` builds the base image with system deps, Claude Code, and the agent release
2. Each `templates/*/Dockerfile` extends the base image and pre-scaffolds a specific app type
3. Comfycat selects the right image when creating a Fly Machine based on the user's chosen template

## Image Naming

- Base: `registry.fly.io/comfycat-machines-base`
- Templates: `registry.fly.io/comfycat-machines-{template-name}` (e.g., `comfycat-machines-default`)

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

## ComfycatEmbed Package

The `comfycat_embed` package (`packages/comfycat_embed/`) provides plugs for iframe embedding and element inspection. It is pre-compiled in the base image at `/opt/comfycat_embed` and added as a path dependency to generated apps.

### Plugs

- **`ComfycatEmbed.AllowIframe`** — Strips `x-frame-options` and overrides CSP to allow cross-origin iframe embedding
- **`ComfycatEmbed.Inspector`** — Injects `comfycat-inspector.js` before `</body>` in HTML responses, enabling element selection in the preview

### Iframe Compatibility

Generated apps are previewed inside an iframe on Comfycat (different origin). The `ComfycatEmbed.AllowIframe` plug handles this automatically. Additional requirements:

- **The app must listen on `0.0.0.0:4000`** (not `127.0.0.1`). Fly's proxy routes external HTTPS traffic to internal port 4000.
- **NEVER remove the `ComfycatEmbed.AllowIframe` or `ComfycatEmbed.Inspector` plugs from the router.**
- **NEVER remove the `comfycat_embed` dependency from `mix.exs`.**
- **Do not add `x-frame-options`** headers or any CSP directive that blocks framing.

When adding new templates, ensure `comfycat_embed` is added as a dependency and both plugs are in the router pipeline.

## Adding a New Template

1. Create `templates/{name}/Dockerfile` extending the base image
2. Pre-scaffold the app in the Dockerfile (install deps, compile)
3. Push to main — CI will build and push `comfycat-machines-{name}` to Fly registry
4. Add the template to `Comfycat.Templates` in the comfycat repo with `image: "registry.fly.io/comfycat-machines-{name}:latest"`
