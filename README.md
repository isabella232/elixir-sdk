# ConfigCat SDK for Elixir

https://configcat.com

ConfigCat SDK for Elixir provides easy integration for your application to ConfigCat.

ConfigCat is a feature flag and configuration management service that lets you separate releases from deployments. You can turn your features ON/OFF using [ConfigCat Dashboard](http://app.configcat.com) even after they are deployed. ConfigCat lets you target specific groups of users based on region, email or any other custom user attribute.

ConfigCat is a [hosted feature flag service](http://configcat.com). Manage feature toggles across frontend, backend, mobile, desktop apps. [Alternative to LaunchDarkly](http://configcat.com). Management app + feature flag SDKs.

[![Build Status](https://api.travis-ci.com/configcat/elixir-sdk.svg)](https://travis-ci.com/configcat/elixir-sdk)
[![Coverage Status](https://codecov.io/github/configcat/elixir-sdk/badge.svg?branch=main)](https://codecov.io/github/configcat/elixir-sdk?branch=main)
[![Hex.pm](https://img.shields.io/hexpm/v/configcat.svg?style=circle)](https://hex.pm/packages/configcat)
[![Hex.pm](https://img.shields.io/hexpm/dt/configcat.svg?style=circle)](https://hex.pm/packages/configcat)

# Getting Started

### 1. Add `configcat` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:configcat, "~> 1.0.0"}
  ]
end
```

### 2. Go to [Connect your application](https://app.configcat.com/sdkkey) tab to get your _SDK Key_:

![SDK-KEY](assets/readme01.png "SDK-KEY")

### 3. Add `ConfigCat` to your application Supervisor tree:

```elixir
def start(_type, _args) do
  children = [
    {ConfigCat, [sdk_key: "YOUR SDK KEY"]},
    MyApp
  ]

  opts = [strategy: :one_for_one, name: Simple.Supervisor]
  Supervisor.start_link(children, opts)
end
```

### 4. Get your setting value:

```elixir
isMyAwesomeFeatureEnabled = ConfigCat.get_value("isMyAwesomeFeatureEnabled", false)
if isMyAwesomeFeatureEnabled do
  do_the_new_thing()
else
  do_the_old_thing()
end
```

## Getting user specific setting values with Targeting

Using this feature, you will be able to get different setting values for different users in your application by passing a `ConfigCat.User` object to the `ConfigCat.get_value/3` function.

Read more about [Targeting here](https://configcat.com/docs/advanced/targeting/).

```elixir
user = ConfigCat.User.new("#USER-IDENTIFIER#")

isMyAwesomeFeatureEnabled = ConfigCat.get_value("isMyAwesomeFeatureEnabled", false, user)
if isMyAwesomeFeatureEnabled do
    do_the_new_thing()
else
    do_the_old_thing()
end
```

## Sample/Demo apps

- [Sample Console Apps](https://github.com/configcat/elixir-sdk/tree/main/samples)

## Polling Modes

The ConfigCat SDK supports 3 different polling mechanisms to acquire the setting values from ConfigCat. After latest setting values are downloaded, they are stored in the internal cache then all requests are served from there. Read more about Polling Modes and how to use them at [ConfigCat Docs](https://configcat.com/docs/sdk-reference/elixir/).

## Need help?

https://configcat.com/support

## Contributing

Contributions are welcome.

## About ConfigCat

- [Official ConfigCat SDKs for other platforms](https://github.com/configcat)
- [Documentation](https://configcat.com/docs)
- [Blog](https://configcat.com/blog)
