ARG BASE_IMAGE=ghcr.io/han2k/comfycat-machines-base:latest
FROM ${BASE_IMAGE}

# Pre-scaffold a blank Phoenix app (no Ecto, no mailer)
USER user
WORKDIR /home/user
RUN mix archive.install hex phx_new --force && \
    mix phx.new app --no-install --no-ecto --no-mailer --no-dashboard && \
    cd app && \
    sed -i 's/http: \[ip: {127, 0, 0, 1}, port: 4000/http: [ip: {0, 0, 0, 0}, port: 8080/' config/dev.exs && \
    mix deps.get && mix compile

USER root
