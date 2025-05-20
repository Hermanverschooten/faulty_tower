defmodule FaultyTower.Email do
  import Swoosh.Email
  use FaultyTowerWeb, :html
  import FaultyTowerWeb.Helpers

  def new_error(error) do
    template = error_content(%{error: error})
    html = heex_to_html(template)
    text = html_to_text(html)

    new()
    |> to(recipients(error))
    |> from({"Faulty Tower", "info@faultytower.com"})
    |> subject("Error in #{error.project.name}: #{String.slice(error.reason, 0, 256)}")
    |> html_body(html)
    |> text_body(text)
  end

  defp recipients(error) do
    for user <- error.project.users do
      {user.name, user.email}
    end
  end

  defp error_content(assigns) do
    ~H"""
    <.email_layout>
      <div class="px-8">
        <div class="uppercase font-bold my-2">
          Error #{@error.id} @ {format_datetime(@error.last_occurrence_at)}
        </div>
        <h1 class="text-2xl font-semibold whitespace-nowrap text-ellipsis w-full overflow-hidden">
          ({sanitize_module(@error.kind)}) {@error.reason}
        </h1>
        <div class="text-gray-700 font-bold mt-4">FULL MESSAGE</div>
        <div class="p-4 rounded-md bg-gray-600 text-white mb-4 mt-2">
          {@error.reason}
        </div>
        <div class="text-gray-700 font-bold">SOURCE</div>
        <div class="p-4 rounded-md bg-gray-600 text-white mb-4 mt-2">
          <p :if={has_source_info?(@error)} class="font-normal">
            {sanitize_module(@error.source_function)}
            <br />
            {@error.source_line}
          </p>
        </div>
      </div>
      <div class="mt-2">
        <.link
          href={url(~p"/project/#{@error.project.key}/#{@error.id}")}
          class="border rounded-md p-4 bg-gray-600 text-white"
        >
          Visit on Faulty Tower
        </.link>
      </div>
    </.email_layout>
    """
  end

  defp email_layout(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="UTF-8" />
        <meta http-equiv="X-UA-Compatible" content="IE=edge" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <title>Faulty Tower</title>

        <link rel="stylesheet" href={static_url(FaultyTowerWeb.Endpoint, ~p"/assets/app.css")} />
      </head>
      <body class="h-full bg-gray-50">
        {render_slot(@inner_block)}
      </body>
    </html>
    """
  end

  defp heex_to_html(template) do
    template
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
  end

  defp html_to_text(html) do
    html
    |> Floki.parse_document!()
    |> Floki.find("body")
    |> Floki.text(sep: "\n\n")
  end
end
