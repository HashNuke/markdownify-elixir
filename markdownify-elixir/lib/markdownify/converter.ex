defmodule Markdownify.Converter do
  @moduledoc """
  Behaviour for overriding tag conversion.

  Return a string to override the conversion, or `:default` to delegate to the
  built-in converter. The `default` argument is a zero-arity function for
  `super`-style composition.

  ## Example

      defmodule ImageBlockConverter do
        @behaviour Markdownify.Converter

        @impl true
        def convert("img", _node, _text, _context, default) do
          default.() <> "\\n\\n"
        end

        def convert(_tag, _node, _text, _context, _default), do: :default
      end

      Markdownify.markdownify(
        ~s(<img src="/img.jpg" alt="Image" />text),
        converter: ImageBlockConverter
      )

  `context` includes the parent tag set, parent node, sibling nodes, ancestors,
  and normalized options. Nodes are Floki HTML tuples.
  """

  @type html_node :: tuple() | String.t()
  @type context :: %{
          parent_tags: MapSet.t(String.t()),
          parent: html_node() | nil,
          previous_sibling: html_node() | nil,
          next_sibling: html_node() | nil,
          ancestors: [html_node()],
          options: map()
        }

  @callback convert(
              tag :: String.t(),
              node :: html_node(),
              text :: String.t(),
              context :: context(),
              default :: (-> String.t())
            ) :: String.t() | :default
end
