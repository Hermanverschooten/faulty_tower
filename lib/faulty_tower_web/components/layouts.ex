defmodule FaultyTowerWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.

  See the `layouts` directory for all templates available.
  The "root" layout is a skeleton rendered as part of the
  application router. The "app" layout is set as the default
  layout on both `use FaultyTowerWeb, :controller` and
  `use FaultyTowerWeb, :live_view`.
  """
  use FaultyTowerWeb, :html

  embed_templates "layouts/*"
end
