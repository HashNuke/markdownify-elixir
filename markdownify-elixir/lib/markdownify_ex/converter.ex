defmodule MarkdownifyEx.Converter do
  @moduledoc """
  Behaviour for overriding tag conversion.

  Return a string to override the conversion, or `:default` to delegate to the
  built-in converter. The `default` argument is a zero-arity function for
  `super`-style composition.
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
