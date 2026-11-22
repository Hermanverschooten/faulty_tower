defmodule FaultyTower.Forgejo.Request do
  def create_issue(config, repo, error, occurrence, url) do
    stack =
      Enum.map_join(
        occurrence.stacktrace.lines,
        "\n",
        fn line ->
          "  File \"#{line.file}\", line #{line.line}, in #{line.module}.#{line.function}/#{line.arity} (#{line.application})"
        end
      )

    body = """
    ```elixir
    #{String.slice(occurrence.reason, 0, 32768)}
    ```

    View details in [FaultyTower](#{url})

    ```
    Stacktrace:
    #{stack}
    ```

    ```elixir
    Context:

    #{inspect(occurrence.context, pretty: true)}
    ```

    """

    case Req.post("#{config.instance_url}/api/v1/repos/#{repo}/issues",
           headers: headers(config),
           json: %{
             title: String.slice(error.reason, 0, 256),
             body: body
           }
         ) do
      {:ok, %{status: 201, body: %{"number" => number}}} ->
        {:ok, number}

      {:ok, response} ->
        {:error, {:forgejo_api_error, response}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def add_comment(config, repo, issue_number, body) do
    Req.post(
      "#{config.instance_url}/api/v1/repos/#{repo}/issues/#{issue_number}/comments",
      headers: headers(config),
      json: %{body: body}
    )
  end

  def update_issue_state(config, repo, issue_number, state) do
    Req.patch(
      "#{config.instance_url}/api/v1/repos/#{repo}/issues/#{issue_number}",
      headers: headers(config),
      json: %{state: state}
    )
  end

  defp headers(config) do
    %{
      "accept" => "application/json",
      "authorization" => "token #{config.access_token}",
      "content-type" => "application/json"
    }
  end
end
