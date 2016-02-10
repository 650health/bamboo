defmodule Bamboo.Mailer do
  @moduledoc """
  Sets up mailers that make it easy to configure and swap adapters.

  Adds deliver/1 and deliver_async/1 functions to the mailer module it is used by.
  Bamboo ships with [Bamboo.MandrillAdapter](Bamboo.MandrillAdapter.html),
  [Bamboo.LocalAdapter](Bamboo.LocalAdapter) and
  [Bamboo.TestAdapter](Bamboo.TestAdapter.html).

  ## Example

      # In your config/config.exs file
      # Other adapters that come with Bamboo are
      # Bamboo.LocalAdapter and Bamboo.TestAdapter
      config :my_app, MyApp.Mailer,
        adapter: Bamboo.MandrillAdapter,
        api_key: "my_api_key"

      # Somewhere in your application. Maybe lib/my_app/mailer.ex
      defmodule MyApp.Mailer do
        # Adds deliver/1 and deliver_async/1
        use Bamboo.Mailer, otp_app: :my_app
      end

      # Set up your emails
      defmodule MyApp.Email do
        use Bamboo.Email

        def welcome_email do
          new_mail(
            to: "foo@example.com",
            from: "me@example.com",
            subject: "Welcome!!!",
            html_body: "<strong>WELCOME</strong>",
            text_body: "WELCOME"
          )
        end
      end

      # In a Phoenix controller or some other module
      defmodule MyApp.Foo do
        alias MyApp.Emails
        alias MyApp.Mailer

        def register_user do
          # Create a user and whatever else is needed
          # Could also have called Mailer.deliver_async
          Email.welcome_email |> Mailer.deliver
        end
      end
  """
  require Logger

  alias Bamboo.Formatter

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      %{adapter: adapter, config: config} = Bamboo.Mailer.parse_opts(__MODULE__, opts)

      @adapter adapter
      @config config

      def deliver(email) do
        Bamboo.Mailer.deliver(@adapter, email, @config)
      end

      def deliver_async(email) do
        Bamboo.Mailer.deliver_async(@adapter, email, @config)
      end
    end
  end

  @doc false
  def deliver(adapter, email, config) do
    email = email |> Bamboo.Mailer.normalize_addresses

    debug(email)
    adapter.deliver(email, config)
  end

  @doc false
  def deliver_async(adapter, email, config) do
    email = email |> Bamboo.Mailer.normalize_addresses

    debug(email)
    adapter.deliver_async(email, config)
  end

  defp debug(email) do
    Logger.debug """
    Sending email with Bamboo:

    #{inspect email, limit: :infinity}
    """
  end

  @doc """
  Wraps to, cc and bcc addresses in a list and normalizes email addresses.

  Email normalization/formatting is done by the [Bamboo.Formatter] protocol.
  """
  def normalize_addresses(email) do
    %{email |
      from: normalize(email.from, :from),
      to: normalize(List.wrap(email.to), :to),
      cc: normalize(List.wrap(email.cc), :cc),
      bcc: normalize(List.wrap(email.bcc), :bcc)
    }
  end

  defp normalize(nil, :from) do
    raise Bamboo.EmptyFromAddressError, nil
  end

  defp normalize(record, type) do
    Formatter.format_email_address(record, %{type: type})
  end

  @doc false
  def parse_opts(mailer, opts) do
    otp_app = Keyword.fetch!(opts, :otp_app)
    config = Application.get_env(otp_app, mailer)
    adapter = Keyword.fetch!(config, :adapter)

    %{adapter: adapter, config: config}
  end
end
