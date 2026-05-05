# MarkdownifyEx

MarkdownifyEx converts HTML fragments to Markdown. This repository keeps the
upstream Python `markdownify/` package and `tests/` tree in place so changes can
continue to be tracked against the parent project, while the Elixir library
lives under `lib/` and `test/`.

## Installation

Add `markdownify_ex` to your dependencies:

```elixir
def deps do
  [
    {:markdownify_ex, "~> 0.1.0"}
  ]
end
```

For local development in this repository:

```sh
mix deps.get
mix test
```

## Usage

Convert HTML to Markdown:

```elixir
MarkdownifyEx.markdownify(~s(<b>Yay</b> <a href="http://github.com">GitHub</a>))
#=> "**Yay** [GitHub](http://github.com)"
```

Specify tags to strip:

```elixir
MarkdownifyEx.markdownify(
  ~s(<b>Yay</b> <a href="http://github.com">GitHub</a>),
  strip: ["a"]
)
#=> "**Yay** GitHub"
```

Or specify only the tags to convert:

```elixir
MarkdownifyEx.markdownify(
  ~s(<b>Yay</b> <a href="http://github.com">GitHub</a>),
  convert: ["b"]
)
#=> "**Yay** GitHub"
```

`MarkdownifyEx.convert/2` is an alias for `MarkdownifyEx.markdownify/2`.

## Options

Options are passed as a keyword list or map:

```elixir
MarkdownifyEx.markdownify("<h1>Hello</h1>", heading_style: :atx)
#=> "# Hello"
```

Supported options:

- `:strip` - list of tags to strip. Cannot be combined with `:convert`.
- `:convert` - list of tags to convert. Cannot be combined with `:strip`.
- `:autolinks` - use automatic link syntax when link text matches `href`.
- `:default_title` - use `href` as the title when no title is provided.
- `:heading_style` - `:underlined`, `:atx`, or `:atx_closed`.
- `:bullets` - bullet characters for nested unordered lists. Defaults to `"*+-"`.
- `:strong_em_symbol` - `"*"` or `"_"`.
- `:sub_symbol` and `:sup_symbol` - wrapper text for `<sub>` and `<sup>`.
- `:newline_style` - `:spaces` or `:backslash` for `<br>` output.
- `:code_language` - language label for all fenced `<pre>` blocks.
- `:code_language_callback` - one-arity function that can derive a language from a Floki node.
- `:converter` - module implementing `MarkdownifyEx.Converter` for custom tag conversion.
- `:escape_asterisks`, `:escape_underscores`, and `:escape_misc` - Markdown escaping controls.
- `:keep_inline_images_in` - parent tags where inline images remain Markdown images.
- `:table_infer_header` - infer the first table row as the header when no header exists.
- `:wrap` and `:wrap_width` - wrap paragraph text.
- `:strip_document` - `:lstrip`, `:rstrip`, `:strip`, or `nil`.
- `:strip_pre` - `:strip`, `:strip_one`, or `nil`.

## Custom Converters

Python `markdownify` customizes conversion by subclassing `MarkdownConverter`.
In Elixir, pass a module that implements `MarkdownifyEx.Converter`:

```elixir
defmodule ImageBlockConverter do
  @behaviour MarkdownifyEx.Converter

  @impl true
  def convert("img", _node, _text, _context, default) do
    default.() <> "\n\n"
  end

  def convert(_tag, _node, _text, _context, _default), do: :default
end

MarkdownifyEx.markdownify(
  ~s(<img src="/path/to/img.jpg" alt="Alt text" />text),
  converter: ImageBlockConverter
)
#=> "![Alt text](/path/to/img.jpg)\n\ntext"
```

The callback receives the tag name, Floki node, converted child text, conversion
context, and a zero-arity `default` function. Return a string to override the
conversion, or `:default` to use the built-in converter.

## Upstream Files

The Python source and tests are intentionally retained:

- `markdownify/`
- `tests/`
- `pyproject.toml`
- `tox.ini`
- `MANIFEST.in`
- `shell.nix`

The Elixir parity test reads the retained Python test files and runs extracted
Python expectations against `MarkdownifyEx`, so upstream behavior changes can be
tracked from the original test corpus.
