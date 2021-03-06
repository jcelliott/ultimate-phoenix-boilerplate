defmodule Mix.Tasks.App.Setup do
  use Mix.Task

  def run([name, otp]) do
    with :ok <- rename_app(name, otp),
         :ok <- remove_rename_dependency(),
         :ok <- create_prod_secret_config(name, otp),
         :ok <- __MODULE__.Frontend.run(),
         :ok <- node_init(),
         :ok <- remove_mix_task(),
         :ok <- remove_setup_config(),
         :ok <- git_init() do
      :ok
    end
    |> case do
      :ok             -> print_conclusion_message()
      {:error, error} -> print_error_message(error)
    end
  end

  def run([]) do
    run([
      config()[:name],
      config()[:otp],
    ])
  end

  def run(_) do
    """
    Call should look like:
    mix app.setup AppName app_name
    or, with name/otp set in config/setup.exs
    mix app.setup
    """
    |> print_error_message
  end

  def config do
    Application.get_env(
      :ultimate_phoenix_boilerplate,
      Mix.Tasks.App.Setup
    )
  end

  def rename_app(name, otp) do
    Mix.Shell.IO.info "Renaming app"
    Rename.run(
      {"UltimatePhoenixBoilerplate", name},
      {"ultimate_phoenix_boilerplate", otp}
    )
    :ok
  rescue
    _ -> {:error, "Failed to rename the app to #{name}/#{otp}"}
  end

  defp remove_rename_dependency do
    Mix.Shell.IO.info "Removing rename dependency"
    with_dep_removed = "mix.exs"
    |> File.read!
    |> String.split("\n")
    |> Enum.reject(&(&1 |> String.contains?(":rename")))
    |> Enum.join("\n")
    File.write!("mix.exs", with_dep_removed)
  rescue
    _ -> {:error, "Failed to remove the :rename dependency from mix.exs"}
  end

  defp create_prod_secret_config(name, otp) do
    Mix.Shell.IO.info "Creating config/prod.secret.exs"
    file = """
    use Mix.Config

    config :#{otp}, #{name}.Web.Endpoint,
      secret_key_base: "#{new_secret()}"
    
    config :#{otp}, #{name}.Repo,
      adapter: Ecto.Adapters.Postgres,
      username: "postgres",
      password: "postgres",
      database: "#{otp}_prod",
      pool_size: 15
    """
    File.write!("./config/prod.secret.exs", file)
  end

  defp new_secret do
    64
    |> :crypto.strong_rand_bytes
    |> Base.encode64 
    |> binary_part(0, 64)
  end

  defp git_init do
    if System.get_env("GIT_RESET") == "false" do
      Mix.Shell.IO.info "GIT_RESET set to false. Skipping git init."
    else
      Mix.Shell.IO.info "Initializing git"
      [
        "rm -rf .git",
        "git init",
        "git add -A",
        "git commit -m 'init'",
      ]
      |> Enum.each(&Mix.Shell.IO.cmd/1)
    end
    :ok
  rescue
    _ -> {:error, "Failed to initialize git"}
  end

  defp node_init do
    Mix.Shell.IO.info "Installing npm packages"
    File.cd!("assets")
    Mix.Shell.IO.cmd("npm i")
    File.cd!("..")
  rescue
    _ -> {:error, "Failed to install npm packages"}
  end

  defp remove_mix_task do
    Mix.Shell.IO.info "Removing this mix task (you shouldn't need it anymore)"
    Mix.Shell.IO.cmd("rm -rf lib/mix/tasks/app")
    :ok
  rescue
    _ -> {:error, "Failed to remove mix task"}
  end

  def remove_setup_config do
    Mix.Shell.IO.info "Removing setup config file"
    Mix.Shell.IO.cmd("rm -rf config/setup.exs")
    with_import_removed = "config/dev.exs"
    |> File.read!
    |> String.split("\n") 
    |> Enum.reject(&(&1 |> String.contains?("setup.exs")))
    |> Enum.join("\n")
    File.write!("config/dev.exs", with_import_removed)
  rescue
    _ -> {:error, "Failed to remove setup config"}

  end

  defp print_conclusion_message do
    Mix.Shell.IO.info """

    Almost done!

    Create your database: 
    mix ecto.create

    Start your app:
    iex -S mix phx.server (or phoenix.server for Phoenix versions < 1.3)

    Visit http://localhost:4000

    Enjoy!
    """
  end

  defp print_error_message(error) do
    Mix.Shell.IO.error(error)
  end
end
