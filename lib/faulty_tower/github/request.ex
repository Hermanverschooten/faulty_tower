defmodule FaultyTower.Github.Request do
  alias FaultyTower.Github.Token

  def authenticate(repo) do
    token = Token.generate_jwt()

    with {:ok, %{status: 200, body: %{"access_tokens_url" => access_tokens_url}}} <-
           Req.get("https://api.github.com/repos/#{repo}/installation",
             headers: %{
               "accept" => "application/vnd.github+json",
               "authorization" => "Bearer #{token}",
               "X-GitHub-Api-version" => "2022-11-28"
             }
           ),
         {:ok, %{status: 201, body: body}} <-
           Req.post(access_tokens_url,
             headers: %{
               "accept" => "application/vnd.github+json",
               "authorization" => "Bearer #{token}",
               "X-GitHub-Api-version" => "2022-11-28"
             }
           ) do
      {:ok, body}
    end
  end
end
