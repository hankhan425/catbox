ARG BASE_IMAGE=registry.fly.io/comfycat-machines-base:latest
FROM ${BASE_IMAGE}

# Pre-scaffold a blank Phoenix app (no Ecto, no mailer)
WORKDIR /home/user
RUN mix archive.install hex phx_new --force && \
    mix phx.new app --no-install --no-ecto --no-mailer --no-dashboard && \
    cd app && \
    sed -i 's/http: \[ip: {127, 0, 0, 1}\]/http: [ip: {0, 0, 0, 0}]/' config/dev.exs && \
    sed -i '/defp deps do/,/end/ s/\[/[\n      {:comfycat_embed, path: "\/opt\/comfycat_embed"},/' mix.exs && \
    sed -i '/plug :put_secure_browser_headers/a\    plug ComfycatEmbed.AllowIframe\n    plug ComfycatEmbed.Inspector' lib/app_web/router.ex && \
    cp /opt/comfycat_embed/priv/static/comfycat-inspector.js priv/static/comfycat-inspector.js && \
    mix deps.get && mix compile

# Bake in CLAUDE.md and Claude Code settings (avoids writing them over the network every generation)
COPY CLAUDE.md /home/user/app/CLAUDE.md
COPY claude-settings.json /home/user/.claude/settings.json

# Start both the Phoenix app and the workspace agent (runs as non-root user from base image)
CMD sh -c "cd /home/user/app && elixir -S mix phx.server > /tmp/phx.log 2>&1 & exec /opt/agent/_build/prod/rel/workspace_agent/bin/workspace_agent start"
