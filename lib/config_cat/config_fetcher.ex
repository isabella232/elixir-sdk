defmodule ConfigCat.ConfigFetcher do
  alias ConfigCat.Config
  alias HTTPoison.{Error, Response}

  @type fetch_error :: {:error, Error.t() | Response.t()}
  @type id :: atom()
  @type result :: {:ok, Config.t()} | {:ok, :unchanged} | fetch_error()

  @callback fetch(id()) :: result()

  defmodule RedirectMode do
    defmacro no_redirect, do: 0
    defmacro should_redirect, do: 1
    defmacro force_redirect, do: 2
  end
end

defmodule ConfigCat.CacheControlConfigFetcher do
  use GenServer

  alias ConfigCat.{ConfigFetcher, Constants, DataGovernance}
  alias ConfigFetcher.RedirectMode
  alias HTTPoison.Response

  require ConfigCat.{Constants, DataGovernance}
  require ConfigFetcher.RedirectMode
  require Logger

  @type option ::
          {:base_url, String.t()}
          | {:http_proxy, String.t()}
          | {:mode, String.t()}
          | {:name, ConfigFetcher.id()}
          | {:sdk_key, String.t()}
          | {:data_governance, DataGovernance.id()}
  @type options :: [option]

  @behaviour ConfigFetcher

  @spec start_link(options()) :: GenServer.on_start()
  def start_link(options) do
    {name, options} = Keyword.pop!(options, :name)

    initial_state =
      default_options()
      |> custom_server_options(options)
      |> Map.merge(Enum.into(options, %{}))
      |> data_governance_options(options)
      |> Map.put(:etag, nil)

    GenServer.start_link(__MODULE__, initial_state, name: name)
  end

  defp default_options,
    do: %{
      api: ConfigCat.API,
      base_url: Constants.base_url_global(),
      data_governance: DataGovernance.global(),
      custom_endpoint: false
    }

  defp custom_server_options(state, options) do
    case List.keyfind(options, :base_url, 0) do
      {:base_url, _url} ->
        %{state | custom_endpoint: true}

      _ ->
        state
    end
  end

  defp data_governance_options(state, options) do
    with %{data_governance: data_governance, custom_endpoint: custom_endpoint} <-
           Map.take(state, [:data_governance, :custom_endpoint]) do
      cond do
        custom_endpoint ->
          {:base_url, base_url} = List.keyfind(options, :base_url, 0)
          %{state | base_url: base_url}

        data_governance == DataGovernance.eu_only() ->
          %{state | base_url: Constants.base_url_eu_only()}

        true ->
          state
      end
    end
  end

  @impl ConfigFetcher
  def fetch(fetcher) do
    GenServer.call(fetcher, :fetch)
  end

  @impl GenServer
  def init(state) do
    {:ok, state}
  end

  @impl GenServer
  def handle_call(:fetch, _from, state) do
    handle_fetch_call(state)
  end

  defp handle_fetch_call(state) do
    Logger.info("Fetching configuration from ConfigCat")

    with api <- Map.get(state, :api),
         {:ok, response} <-
           api.get(url(state), headers(state), http_options(state)) do
      response
      |> log_response()
      |> handle_response(state)
    else
      error ->
        log_error(error)
        {:reply, error, state}
    end
  end

  defp url(%{base_url: base_url, sdk_key: sdk_key}) do
    base_url
    |> URI.parse()
    |> URI.merge("#{Constants.base_path()}/#{sdk_key}/#{Constants.config_filename()}")
    |> URI.to_string()
  end

  defp headers(state) do
    base_headers(state) ++ cache_headers(state)
  end

  defp base_headers(%{mode: mode}) do
    version = Application.spec(:config_cat, :vsn) |> to_string()
    user_agent = "ConfigCat-Elixir/#{mode}-#{version}"

    [
      {"User-Agent", user_agent},
      {"X-ConfigCat-UserAgent", user_agent}
    ]
  end

  defp cache_headers(state) do
    case Map.get(state, :etag) do
      nil -> []
      etag -> [{"If-None-Match", etag}]
    end
  end

  defp http_options(state) do
    case Map.get(state, :http_proxy) do
      nil -> []
      proxy -> [proxy: proxy]
    end
  end

  defp handle_response(%Response{status_code: code, body: config, headers: headers}, state)
       when code >= 200 and code < 300 do
    with etag <- extract_etag(headers),
         %{base_url: new_base_url, custom_endpoint: custom_endpoint} <-
           Map.take(state, [:base_url, :custom_endpoint]),
         p <- Map.get(config, Constants.preferences(), %{}),
         base_url <- Map.get(p, Constants.preferences_base_url()),
         redirect <- Map.get(p, Constants.redirect()) do
      state =
        cond do
          custom_endpoint && redirect != RedirectMode.force_redirect() ->
            state

          base_url && new_base_url != base_url ->
            {_, {_, _}, state} = handle_fetch_call(%{state | base_url: base_url})
            state

          true ->
            state
        end

      if redirect == RedirectMode.should_redirect() do
        Logger.warn("""
        Your data_governance parameter at ConfigCat client initialization
        is not in sync with your preferences on the ConfigCat Dashboard:
        https://app.configcat.com/organization/data-governance.
        Only Organization Admins can set this preference.
        """)
      end

      {:reply, {:ok, config}, %{state | etag: etag}}
    end
  end

  defp handle_response(%Response{status_code: 304}, state) do
    {:reply, {:ok, :unchanged}, state}
  end

  defp handle_response(response, state) do
    {:reply, {:error, response}, state}
  end

  defp extract_etag(headers) do
    case List.keyfind(headers, "ETag", 0) do
      nil -> nil
      {_key, value} -> value
    end
  end

  defp log_response(%Response{headers: headers, status_code: status_code} = response) do
    Logger.info(
      "ConfigCat configuration json fetch response code: #{status_code} Cached: #{
        extract_etag(headers)
      }"
    )

    response
  end

  defp log_error(error) do
    Logger.error("Double-check your SDK Key at https://app.configcat.com/sdkkey.")
    Logger.error("Failed to fetch configuration from ConfigCat: #{inspect(error)}")
  end

  @impl GenServer
  # Work around leaking messages from hackney (see https://github.com/benoitc/hackney/issues/464#issuecomment-495731612)
  # Seems to be an issue in OTP 21 and later.
  def handle_info({:ssl_closed, _msg}, state), do: {:noreply, state}
end
