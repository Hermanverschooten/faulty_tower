defmodule FaultyTowerWeb.Helpers do
  use Phoenix.Component
  @doc false
  def sanitize_module(<<"Elixir.", str::binary>>), do: str
  def sanitize_module(str), do: str

  def has_source_info?(%{source_function: "-", source_line: "-"}), do: false
  def has_source_info?(%{}), do: true

  def format_datetime(dt = %DateTime{}), do: Calendar.strftime(dt, "%c %Z")

  @doc """
  Renders a badge.

  ## Examples

      <.badge>Info</.badge>
      <.badge color={:red}>Error</.badge>
  """
  attr(:color, :atom, default: :blue)
  attr(:rest, :global)

  slot(:inner_block, required: true)

  def badge(assigns) do
    color_class =
      case assigns.color do
        :blue -> "bg-blue-900 text-blue-300"
        :gray -> "bg-gray-700 text-gray-300"
        :red -> "bg-red-200 text-red-700 ring-red-700"
        :green -> "bg-emerald-200 text-emerald-700 ring-emerald-7000"
        :yellow -> "bg-yellow-900 text-yellow-300"
        :indigo -> "bg-indigo-900 text-indigo-300"
        :purple -> "bg-purple-900 text-purple-300"
        :pink -> "bg-pink-900 text-pink-300"
      end

    assigns = Map.put(assigns, :color_class, color_class)

    ~H"""
    <span
      class={["text-sm font-medium me-2 py-1 px-2 rounded-lg ring-1 ring-inset", @color_class]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </span>
    """
  end
end
