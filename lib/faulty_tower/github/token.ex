defmodule FaultyTower.Github.Token do
  use Joken.Config

  @impl true
  def token_config do
    default_claims(
      skip: [:aud, :jti, :nbf],
      iss: iss(),
      default_exp: 600
    )
    |> add_claim("alg", fn -> "RS256" end)
  end

  def signer do
    Joken.Signer.create(
      "RS256",
      %{"pem" => File.read!(System.get_env("GH_PRIVATE_KEY"))}
    )
  end

  def iss do
    System.get_env("GH_CLIENT_ID")
  end

  def generate_jwt do
    generate_and_sign!(%{}, signer())
  end
end
