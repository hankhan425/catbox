ARG BASE_IMAGE=registry.fly.io/comfycat-machines-base:latest
FROM ${BASE_IMAGE}

# Pre-scaffold a blank Phoenix app (no Ecto, no mailer)
WORKDIR /home/user
RUN mix archive.install hex phx_new --force && \
    mix phx.new app --no-install --no-ecto --no-mailer --no-dashboard && \
    cd app && \
    sed -i 's/http: \[ip: {127, 0, 0, 1}, port: 4000/http: [ip: {0, 0, 0, 0}, port: 8080/' config/dev.exs && \
    mix deps.get && mix compile

# Start both the Phoenix app and the workspace agent (runs as non-root user from base image)
CMD sh -c "cd /home/user/app && elixir -S mix phx.server > /tmp/phx.log 2>&1 & exec /opt/agent/_build/prod/rel/workspace_agent/bin/workspace_agent start"
