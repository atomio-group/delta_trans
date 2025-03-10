defmodule DeltaTrans do
  defdelegate from_markdown(markdown), to: DeltaTrans.MarkdownTransformer, as: :to_delta
  defdelegate to_html(delta, opts \\ []), to: DeltaTrans.HTMLTransformer, as: :to_html
end
