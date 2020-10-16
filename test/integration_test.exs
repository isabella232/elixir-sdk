defmodule ConfigCat.IntegrationTest do
  use ExUnit.Case, async: true

  alias ConfigCat.FetchPolicy

  @sdk_key "PKDVCLf-Hq-h-kCzMp-L7Q/PaDVCFk9EpmD6sLpGLltTA"

  test "fetches config" do
    {:ok, client} = start_config_cat(@sdk_key)

    :ok = ConfigCat.force_refresh(client)

    assert ConfigCat.get_value("keySampleText", "default value", client: client) ==
             "This text came from ConfigCat"
  end

  test "maintains previous configuration when config has not changed between refreshes" do
    {:ok, client} = start_config_cat(@sdk_key)

    :ok = ConfigCat.force_refresh(client)
    :ok = ConfigCat.force_refresh(client)

    assert ConfigCat.get_value("keySampleText", "default value", client: client) ==
             "This text came from ConfigCat"
  end

  test "lazily fetches configuration when using lazy loading" do
    {:ok, client} =
      start_config_cat(
        @sdk_key,
        fetch_policy: FetchPolicy.lazy(cache_expiry_seconds: 5)
      )

    assert ConfigCat.get_value("keySampleText", "default value", client: client) ==
             "This text came from ConfigCat"
  end

  @tag capture_log: true
  test "handles errors from ConfigCat server" do
    {:ok, client} = start_config_cat("invalid_sdk_key")

    {:error, response} = ConfigCat.force_refresh(client)
    assert response.status_code == 404
  end

  @tag capture_log: true
  test "handles invalid base_url" do
    {:ok, client} = start_config_cat(@sdk_key, base_url: "https://invalidcdn.configcat.com")

    assert {:error, %HTTPoison.Error{}} = ConfigCat.force_refresh(client)
  end

  defp start_config_cat(sdk_key, options \\ []) do
    name = UUID.uuid4() |> String.to_atom()
    ConfigCat.start_link(sdk_key, Keyword.merge([name: name], options))
  end
end
