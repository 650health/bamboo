# Bamboo

Bamboo was built with a few goals in mind

* Easy to format recipients, so you can do `new_email(to: Repo.one(User))` and Bamboo can format the user automatically.
* Works with Phoenix views and layouts to make rendering easy.
* Adapter based so it can be used with Mandrill, SMTP, or whatever else you want.
* Very composable. Emails are just a Bamboo.Email struct and be manipulated with plain functions.
* Make it super easy to unit test. No special functions needed.
* Easy to test delivery in integration tests. As little repeated code as possible.

See the [API Reference](api-reference.html) for the most up to date information.

## Usage

Bamboo breaks email creation and email sending in to two separate modules.

```elixir
# In your config/config.exs file
config :my_app, MyApp.Mailer,
  adapter: Bamboo.MandrillAdapter,
  api_key: "my_api_key"

# In your application code
defmodule MyApp.Mailer do
  use Bamboo.Mailer, otp_app: :my_app
end

defmodule MyApp.Emails do
  import Bamboo.Email

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

# In a controller or some other module
defmodule MyApp.Foo do
  alias MyApp.Emails
  alias MyApp.Mailer

  def register_user do
    # Create a user and whatever else is needed

    # Emails are not delivered until you explicitly deliver them. This makes
    # them very composable and easy to unit test
    Emails.welcome_email |> Mailer.deliver
  end
end
```

## More options

```elixir
defmodule MyApp.Emails do
  # Adds a `render` function for rending emails with a Phoenix view
  use Bamboo.Phoenix, view: MyApp.EmailView
  import Bamboo.MandrillEmails

  def welcome_email do
    base_email
    |> to("foo@bar.com", %Bamboo.EmailAddress{name: "John Smith", address:"john@foo.com"})
    |> cc(author) # You can set up a custom protocol that handles different types of structs.
    |> subject("Welcome!!!")
    |> tag("welcome-email") # Imported by Bamboo.MandrillEmails
    |> put_header("Reply-To", "somewhere@example.com")
    # Uses the view from `view` to render the `welcome_email.html.eex`
    # and `welcome_email.text.eex` templates with the passed in assigns
    # Use string to render a specific template, e.g. `welcome_email.html.eex`
    |> render(:welcome_email, author: author)
  end

  defp author do
    User |> Repo.one
  end

  defp base_email do
    mail(from: "myapp@example.com")
  end
end

defimpl Bamboo.Formatter, for: User do
  # Used by `to`, `bcc`, `cc` and `from`
  def format_email_address(user, _opts) do
    fullname = "#{user.first_name} #{user.last_name}"
    %Bamboo.EmailAddress{name: fullname, email: email}
  end
end
```

## In development (coming soonish)

You can see the sent emails by forwarding a route to the `Bamboo.Preview`
module. You can see all the emails sent. It will live update with new emails
sent.

```elixir
# In your Phoenix router
forward "/delivered_emails", Bamboo.Mailbox

# If you want to see the latest email, add this to your socket
channel "/latest_email", Bamboo.LatestEmailChannel

# In your browser
localhost:4000/email_previews
```

## Testing

You can use the `Bamboo.TestAdapter` to make testing your emails a piece of cake.

```elixir
# Use the Bamboo.LocalAdapter in your config/test.exs file
config :my_app, MyApp.Mailer,
  adapter: Bamboo.LocalAdapter

# Unit testing requires no special functions
defmodule MyApp.EmailsTest do
  use ExUnit.Case

  alias MyApp.Emails

  test "welcome email" do
    user = %User{...}
    email = Emails.welcome_email(user)

    assert email.to == "someone@foo.com"
    assert email.subject == "This is your welcome email"
    assert email.html_body =~ "Welcome to the app!"
  end
end

# Integration tests

defmodule MyApp.RegistrationControllerTest do
  use ExUnit.Case

  use Bamboo.Test
  alias MyApp.Emails

  test "registers user and sends welcome email" do
    ...post to registration controller

    newly_created_user = Repo.first(User)
    assert_delivered_email Emails.welcome_email(newly_created_user)
  end
end

```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add bamboo to your list of dependencies in `mix.exs`:

        def deps do
          [{:bamboo, "~> 0.0.5"}]
        end

  2. Ensure bamboo is started before your application:

        def application do
          [applications: [:bamboo]]
        end
