FROM hexpm/elixir:1.19.5-erlang-28.0-ubuntu-noble-20250127

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    nodejs \
    npm \
    build-essential \
    inotify-tools \
    bubblewrap \
    socat \
    && rm -rf /var/lib/apt/lists/*

# Install Claude Code globally
RUN npm install -g @anthropic-ai/claude-code

# Create non-root user
RUN useradd -m -s /bin/bash user

# Build the agent release
WORKDIR /opt/agent
COPY mix.exs mix.lock* ./
RUN mix local.hex --force && mix local.rebar --force
RUN MIX_ENV=prod mix deps.get --only prod
COPY config config/
COPY lib lib/
RUN MIX_ENV=prod mix release

# Set up the user's app directory
RUN mkdir -p /home/user/app && chown -R user:user /home/user

# Install hex and rebar for the user (needed for Phoenix project bootstrap)
USER user
RUN mix local.hex --force && mix local.rebar --force
USER root

EXPOSE 8080 9090

# Start the agent
CMD ["/opt/agent/_build/prod/rel/workspace_agent/bin/workspace_agent", "start"]
