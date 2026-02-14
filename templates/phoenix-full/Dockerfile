ARG BASE_IMAGE=registry.fly.io/comfycat-machines-base:latest
FROM ${BASE_IMAGE}

# Pre-scaffold Phoenix app with Ecto + PostgreSQL
USER user
WORKDIR /home/user
RUN mix archive.install hex phx_new --force && \
    mix phx.new app --no-install --no-mailer --no-dashboard && \
    cd app && \
    sed -i 's/http: \[ip: {127, 0, 0, 1}, port: 4000/http: [ip: {0, 0, 0, 0}, port: 8080/' config/dev.exs && \
    mix deps.get && mix compile

USER root
