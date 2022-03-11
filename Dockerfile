# Extend from the official Elixir image.
FROM elixir:latest

# Create app directory and copy the Elixir projects into it.
RUN mkdir /app
COPY . /app
WORKDIR /app

# Install Hex package manager.
# By using `--force`, we don’t need to type “Y” to confirm the installation.
RUN mix local.rebar --force
RUN mix local.hex --force

ENV MIX_ENV=prod

# Compile the project.
RUN mix do compile

RUN chmod +x /app/entrypoint.sh

CMD ["/app/entrypoint.sh"]