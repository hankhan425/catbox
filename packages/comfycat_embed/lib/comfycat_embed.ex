defmodule ComfycatEmbed do
  @moduledoc """
  Plugs for embedding Phoenix apps inside the Comfycat preview iframe.

  Add to your router pipeline:

      plug ComfycatEmbed.AllowIframe
      plug ComfycatEmbed.Inspector
  """
end
