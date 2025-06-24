defmodule FaultyTower.Github do
  alias FaultyTower.Github.Request

  def create_issue(project, error, occurrence, url) do
    repo = issues_repo(project)

    with {:ok, %{"token" => token}} <- Request.authenticate(repo) do
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

      case Req.post("https://api.github.com/repos/#{repo}/issues",
             headers: %{
               "accept" => "application/vnd.github+json",
               "authorization" => "Bearer #{token}",
               "X-GitHub-Api-version" => "2022-11-28"
             },
             json: %{
               title: String.slice(error.reason, 0, 256),
               body: body
             }
           ) do
        {:ok, %{status: 201, body: %{"number" => number}}} ->
          {:ok, number}

        e ->
          dbg(e)
          :error
      end
    end
  end

  def close_issue(project, gh_issue, who) do
    repo = issues_repo(project)

    with {:ok, %{"token" => token}} <- Request.authenticate(repo) do
      Req.post(
        "https://api.github.com/repos/#{repo}/issues/#{gh_issue}/comments",
        headers: %{
          "accept" => "application/vnd.github+json",
          "authorization" => "Bearer #{token}",
          "X-GitHub-Api-version" => "2022-11-28"
        },
        json: %{
          body: "Resolved by #{who.name}"
        }
      )

      Req.patch(
        "https://api.github.com/repos/#{repo}/issues/#{gh_issue}",
        headers: %{
          "accept" => "application/vnd.github+json",
          "authorization" => "Bearer #{token}",
          "X-GitHub-Api-version" => "2022-11-28"
        },
        json: %{
          state: "closed"
        }
      )
    end
  end

  def reopen_issue(project, gh_issue, who) do
    repo = issues_repo(project)

    with {:ok, %{"token" => token}} <- Request.authenticate(repo) do
      Req.post(
        "https://api.github.com/repos/#{repo}/issues/#{gh_issue}/comments",
        headers: %{
          "accept" => "application/vnd.github+json",
          "authorization" => "Bearer #{token}",
          "X-GitHub-Api-version" => "2022-11-28"
        },
        json: %{
          body: "Reopened by #{who.name}"
        }
      )

      Req.patch(
        "https://api.github.com/repos/#{repo}/issues/#{gh_issue}",
        headers: %{
          "accept" => "application/vnd.github+json",
          "authorization" => "Bearer #{token}",
          "X-GitHub-Api-version" => "2022-11-28"
        },
        json: %{
          state: "open"
        }
      )
    end
  end

  def issues_repo(%{github: nil}), do: nil
  def issues_repo(%{github: %{issue_repo: nil, repo: repo}}), do: repo
  def issues_repo(%{github: %{issue_repo: repo}}), do: repo

  def create_issue(project, title, body) do
    repo = issues_repo(project)

    with {:ok, %{"token" => token}} <- Request.authenticate(repo) do
      case Req.post("https://api.github.com/repos/#{repo}/issues",
             headers: %{
               "accept" => "application/vnd.github+json",
               "authorization" => "Bearer #{token}",
               "X-GitHub-Api-version" => "2022-11-28"
             },
             json: %{
               title: String.slice(title, 0, 256),
               body: body
             }
           ) do
        {:ok, %{status: 201, body: %{"html_url" => url, "number" => _number}}} ->
          {:ok, url}

        {:ok, response} ->
          {:error, {:github_api_error, response}}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end
end
