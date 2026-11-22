defmodule FaultyTower.Forgejo do
  alias FaultyTower.Forgejo.Request

  def create_issue(project, error, occurrence, url) do
    repo = issues_repo(project)
    organization = project.organization

    with {:ok, config} <- get_config(organization),
         {:ok, number} <- Request.create_issue(config, repo, error, occurrence, url) do
      {:ok, number}
    end
  end

  def close_issue(project, issue_number, who) do
    repo = issues_repo(project)
    organization = project.organization

    with {:ok, config} <- get_config(organization) do
      Request.add_comment(config, repo, issue_number, "Resolved by #{who.name}")
      Request.update_issue_state(config, repo, issue_number, "closed")
    end
  end

  def reopen_issue(project, issue_number, who) do
    repo = issues_repo(project)
    organization = project.organization

    with {:ok, config} <- get_config(organization) do
      Request.add_comment(config, repo, issue_number, "Reopened by #{who.name}")
      Request.update_issue_state(config, repo, issue_number, "open")
    end
  end

  def issues_repo(%{repository: nil}), do: nil
  def issues_repo(%{repository: %{issue_repo: nil, repo: repo}}), do: repo
  def issues_repo(%{repository: %{issue_repo: repo}}) when is_binary(repo), do: repo
  def issues_repo(%{repository: %{repo: repo}}), do: repo

  def configured?(%{git_provider: "forgejo", repository: %{repo: repo}, organization: org})
      when is_binary(repo) do
    case get_config(org) do
      {:ok, _} -> true
      _ -> false
    end
  end

  def configured?(_), do: false

  def instance_url(organization) do
    org_config = organization.forgejo
    global_config = Application.get_env(:faulty_tower, :forgejo)

    get_setting(org_config, :instance_url) || get_setting(global_config, :instance_url)
  end

  defp get_config(organization) do
    org_config = organization.forgejo
    global_config = Application.get_env(:faulty_tower, :forgejo)

    instance_url =
      get_setting(org_config, :instance_url) || get_setting(global_config, :instance_url)

    access_token =
      get_setting(org_config, :access_token) || get_setting(global_config, :access_token)

    if instance_url && access_token do
      {:ok, %{instance_url: instance_url, access_token: access_token}}
    else
      {:error, :not_configured}
    end
  end

  defp get_setting(nil, _key), do: nil
  defp get_setting(config, key) when is_map(config), do: Map.get(config, key)
  defp get_setting(config, key) when is_list(config), do: Keyword.get(config, key)
end
