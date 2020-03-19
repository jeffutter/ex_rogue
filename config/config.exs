# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :ex_rogue,
  ecto_repos: [ExRogue.Repo]

# Configures the endpoint
config :ex_rogue, ExRogueWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "N30rZcoKZ+VV9H1LE5dedEq+my4UW0ptDqUJbeSsChslaAiwjjU5JOmCsMVo3p9F",
  render_errors: [view: ExRogueWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: ExRogue.PubSub, adapter: Phoenix.PubSub.PG2],
  live_view: [signing_salt: "kAwi/R97"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
