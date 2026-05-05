defmodule MarkdownifyEx.CustomConverterTest do
  use ExUnit.Case, async: true

  defmodule UnitTestConverter do
    @behaviour MarkdownifyEx.Converter

    @impl true
    def convert("img", _node, _text, _context, default) do
      default.() <> "\n\n"
    end

    def convert("custom-tag", _node, text, _context, _default) do
      "convert_custom_tag(): #{text}"
    end

    def convert("h1", _node, text, _context, _default) do
      "convert_h1: #{text}"
    end

    def convert("h" <> n, _node, text, _context, _default) do
      "convert_hN(#{n}): #{text}"
    end

    def convert(_tag, _node, _text, _context, _default), do: :default
  end

  defp md(html, opts \\ []) do
    MarkdownifyEx.markdownify(
      html,
      Keyword.merge([strip_document: nil, converter: UnitTestConverter], opts)
    )
  end

  test "custom conversion functions mirror the Python custom converter tests" do
    assert md(~s(<img src="/path/to/img.jpg" alt="Alt text" title="Optional title" />text)) ==
             ~S|![Alt text](/path/to/img.jpg "Optional title")| <> "\n\ntext"

    assert md(~s(<img src="/path/to/img.jpg" alt="Alt text" />text)) ==
             "![Alt text](/path/to/img.jpg)\n\ntext"

    assert md("<custom-tag>text</custom-tag>") == "convert_custom_tag(): text"
    assert md("<h1>text</h1>") == "convert_h1: text"
    assert md("<h3>text</h3>") == "convert_hN(3): text"
  end
end
