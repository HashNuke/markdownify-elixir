defmodule Markdownify do
  @moduledoc """
  Converts HTML fragments to Markdown.

  `Markdownify` is an Elixir port of Python `markdownify`. It accepts an HTML
  fragment, parses it with Floki, and emits Markdown that tracks the upstream
  Python project's conversion behavior.

  ## Basic usage

      iex> Markdownify.markdownify(~s(<b>Yay</b> <a href="http://github.com">GitHub</a>))
      "**Yay** [GitHub](http://github.com)"

      iex> Markdownify.markdownify("<h1>Hello</h1>", heading_style: :atx)
      "# Hello"

  ## Filtering tags

  Use `:strip` to remove Markdown conversion for specific tags while keeping
  their contents:

      iex> Markdownify.markdownify(~s(<b>Yay</b> <a href="/">Home</a>), strip: ["a"])
      "**Yay** Home"

  Use `:convert` to allow only specific tags:

      iex> Markdownify.markdownify(~s(<b>Yay</b> <a href="/">Home</a>), convert: ["b"])
      "**Yay** Home"

  `:strip` and `:convert` are mutually exclusive.

  ## Custom conversion

  Pass `converter: MyModule` to override tag conversion with a module that
  implements `Markdownify.Converter`.

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

  ## Options

  The supported options mirror the Python project where practical:

  * `:strip` - tags to skip converting.
  * `:convert` - tags to convert, skipping all others.
  * `:converter` - module implementing `Markdownify.Converter`.
  * `:autolinks` - emit `<url>` links when link text matches `href`.
  * `:default_title` - use `href` as link title when no title exists.
  * `:heading_style` - `:underlined`, `:atx`, or `:atx_closed`.
  * `:bullets` - unordered list bullet cycle, default `"*+-"`.
  * `:strong_em_symbol` - `"*"` or `"_"`.
  * `:sub_symbol` and `:sup_symbol` - wrappers for subscript/superscript text.
  * `:newline_style` - `:spaces` or `:backslash` for `<br>`.
  * `:code_language` - language marker for fenced `<pre>` blocks.
  * `:code_language_callback` - function that receives a Floki node and returns a language.
  * `:escape_asterisks`, `:escape_underscores`, `:escape_misc` - escaping controls.
  * `:keep_inline_images_in` - tags where inline images should remain Markdown images.
  * `:table_infer_header` - use first body row as table header when no header exists.
  * `:wrap` and `:wrap_width` - paragraph wrapping controls.
  * `:strip_document` - `:lstrip`, `:rstrip`, `:strip`, or `nil`.
  * `:strip_pre` - `:strip`, `:strip_one`, or `nil`.
  """

  @atx :atx
  @atx_closed :atx_closed
  @underlined :underlined
  @spaces :spaces
  @backslash :backslash
  @asterisk "*"
  @underscore "_"
  @lstrip :lstrip
  @rstrip :rstrip
  @strip :strip
  @strip_one :strip_one
  @space_sentinel "\uE000"

  @option_keys %{
    "autolinks" => :autolinks,
    "bs4_options" => :bs4_options,
    "bullets" => :bullets,
    "code_language" => :code_language,
    "code_language_callback" => :code_language_callback,
    "convert" => :convert,
    "converter" => :converter,
    "default_title" => :default_title,
    "escape_asterisks" => :escape_asterisks,
    "escape_misc" => :escape_misc,
    "escape_underscores" => :escape_underscores,
    "heading_style" => :heading_style,
    "keep_inline_images_in" => :keep_inline_images_in,
    "newline_style" => :newline_style,
    "strip" => :strip,
    "strip_document" => :strip_document,
    "strip_pre" => :strip_pre,
    "strong_em_symbol" => :strong_em_symbol,
    "sub_symbol" => :sub_symbol,
    "sup_symbol" => :sup_symbol,
    "table_infer_header" => :table_infer_header,
    "wrap" => :wrap,
    "wrap_width" => :wrap_width
  }

  @style_values %{
    "atx" => @atx,
    "atx_closed" => @atx_closed,
    "backslash" => @backslash,
    "lstrip" => @lstrip,
    "rstrip" => @rstrip,
    "spaces" => @spaces,
    "strip" => @strip,
    "strip_one" => @strip_one,
    "underlined" => @underlined
  }

  @doc "Heading style that renders headings as `# Heading`."
  def atx, do: @atx

  @doc "Heading style that renders headings as `# Heading #`."
  def atx_closed, do: @atx_closed

  @doc "Heading style that renders h1/h2 with Setext underlines."
  def underlined, do: @underlined

  @doc "Alias for `underlined/0`."
  def setext, do: @underlined

  @doc "Line break style that renders `<br>` as two spaces plus a newline."
  def spaces, do: @spaces

  @doc "Line break style that renders `<br>` as a backslash plus a newline."
  def backslash, do: @backslash

  @doc "Strong/emphasis marker using `*`."
  def asterisk, do: @asterisk

  @doc "Strong/emphasis marker using `_`."
  def underscore, do: @underscore

  @doc "Document/pre strip style that removes leading newlines."
  def lstrip, do: @lstrip

  @doc "Document/pre strip style that removes trailing newlines."
  def rstrip, do: @rstrip

  @doc "Document/pre strip style that removes leading and trailing newlines."
  def strip, do: @strip

  @doc "Preformatted strip style that removes one leading and trailing newline."
  def strip_one, do: @strip_one

  @defaults %{
    autolinks: true,
    bs4_options: nil,
    bullets: "*+-",
    code_language: "",
    code_language_callback: nil,
    convert: nil,
    converter: nil,
    default_title: false,
    escape_asterisks: true,
    escape_underscores: true,
    escape_misc: false,
    heading_style: @underlined,
    keep_inline_images_in: [],
    newline_style: @spaces,
    strip: nil,
    strip_document: @strip,
    strip_pre: @strip,
    strong_em_symbol: @asterisk,
    sub_symbol: "",
    sup_symbol: "",
    table_infer_header: false,
    wrap: false,
    wrap_width: 80
  }

  @type option ::
          {:autolinks, boolean()}
          | {:bs4_options, term()}
          | {:bullets, String.t() | [String.t()]}
          | {:code_language, String.t()}
          | {:code_language_callback, (html_node() -> String.t() | nil)}
          | {:convert, [String.t() | atom()] | nil}
          | {:converter, module() | nil}
          | {:default_title, boolean()}
          | {:escape_asterisks, boolean()}
          | {:escape_underscores, boolean()}
          | {:escape_misc, boolean()}
          | {:heading_style, atom() | String.t()}
          | {:keep_inline_images_in, [String.t() | atom()]}
          | {:newline_style, atom() | String.t()}
          | {:strip, [String.t() | atom()] | nil}
          | {:strip_document, atom() | nil}
          | {:strip_pre, atom() | nil}
          | {:strong_em_symbol, String.t()}
          | {:sub_symbol, String.t()}
          | {:sup_symbol, String.t()}
          | {:table_infer_header, boolean()}
          | {:wrap, boolean()}
          | {:wrap_width, pos_integer() | nil}

  @type html_node :: tuple() | String.t()

  @doc """
  Converts an HTML string to Markdown.

  `options` may be a keyword list or map. The default conversion strips leading
  and trailing document-separation newlines, matching Python `markdownify`.

  ## Examples

      iex> Markdownify.markdownify("<strong>Hello</strong>")
      "**Hello**"

      iex> Markdownify.markdownify(~s(<a href="https://example.com">Example</a>))
      "[Example](https://example.com)"

      iex> Markdownify.markdownify("<h1>Hello</h1>", heading_style: :atx)
      "# Hello"

      iex> Markdownify.markdownify("<p>Hello</p>", strip_document: nil)
      "\\n\\nHello\\n\\n"
  """
  @spec markdownify(String.t(), [option()] | map()) :: String.t()
  def markdownify(html, options \\ []) when is_binary(html) do
    options = normalize_options(options)

    parse_html =
      html
      |> replace_re(
        ~r/<(b|i|del|em|code|strong|s|sup|sub|kbd|samp)(?:\s[^>]*)?>([\r\n]+)<\/\1>/,
        "\\2"
      )
      |> replace_re(~r/>[ \t]+</, ">" <> @space_sentinel <> "<")

    case Floki.parse_fragment(parse_html) do
      {:ok, nodes} ->
        nodes
        |> convert_nodes(options)
        |> preserve_root_inline_whitespace(html, nodes, options)

      {:error, _} ->
        convert_nodes([], options)
    end
  end

  defp preserve_root_inline_whitespace(text, _html, _nodes, %{strip_document: strip_document})
       when strip_document != nil do
    text
  end

  defp preserve_root_inline_whitespace(text, html, nodes, _options) do
    preserve? = Enum.any?(nodes, &element_node?/1)

    text =
      if preserve? and Regex.match?(~r/^\s/, html) and not String.starts_with?(text, "\n") do
        " " <> text
      else
        text
      end

    if preserve? and Regex.match?(~r/\s$/, html) and not String.ends_with?(text, "\n") do
      text <> " "
    else
      text
    end
  end

  @doc """
  Alias for `markdownify/2`.

  ## Example

      iex> Markdownify.convert("<em>Hello</em>")
      "*Hello*"
  """
  @spec convert(String.t(), [option()] | map()) :: String.t()
  def convert(html, options \\ []), do: markdownify(html, options)

  defp convert_nodes(nodes, options) do
    document = {"[document]", [], nodes}

    document
    |> process_tag(%{
      options: options,
      parent_tags: MapSet.new(),
      parent: nil,
      prev: nil,
      next: nil,
      index: nil,
      siblings: [],
      ancestors: []
    })
  end

  defp normalize_options(options) do
    opts =
      options
      |> Enum.into(%{})
      |> Map.new(fn {k, v} -> {normalize_key(k), normalize_value(k, v)} end)

    if Map.get(opts, :strip) != nil and Map.get(opts, :convert) != nil do
      raise ArgumentError,
            "You may specify either tags to strip or tags to convert, but not both."
    end

    @defaults
    |> Map.merge(opts)
    |> Map.update!(:strip, &normalize_tag_list/1)
    |> Map.update!(:convert, &normalize_tag_list/1)
    |> Map.update!(:keep_inline_images_in, &normalize_tag_list/1)
    |> Map.update!(:heading_style, &normalize_style/1)
    |> Map.update!(:newline_style, &normalize_style/1)
    |> Map.update!(:strip_document, &normalize_style/1)
    |> Map.update!(:strip_pre, &normalize_style/1)
  end

  defp normalize_key(key) when is_atom(key), do: key

  defp normalize_key(key) when is_binary(key) do
    normalized = String.trim_leading(key, ":")

    case Map.fetch(@option_keys, normalized) do
      {:ok, option_key} -> option_key
      :error -> raise ArgumentError, "Unknown Markdownify option: #{inspect(key)}"
    end
  end

  defp normalize_value(_key, value), do: value

  defp normalize_tag_list(nil), do: nil
  defp normalize_tag_list(tags), do: Enum.map(tags, &tag_name/1)

  defp normalize_style(nil), do: nil
  defp normalize_style(value) when is_atom(value), do: value

  defp normalize_style(value) when is_binary(value) do
    normalized = String.downcase(value)

    case Map.fetch(@style_values, normalized) do
      {:ok, style} -> style
      :error -> raise ArgumentError, "Unknown Markdownify style value: #{inspect(value)}"
    end
  end

  defp process_element(text, ctx) when is_binary(text), do: process_text(text, ctx)
  defp process_element({_tag, _attrs, _children} = node, ctx), do: process_tag(node, ctx)
  defp process_element(_node, _ctx), do: ""

  defp process_tag({tag, _attrs, children} = node, ctx) do
    tag = tag_name(tag)
    node = set_tag(node, tag)
    remove_inside? = remove_whitespace_inside?(node)
    children = reject_ignored_children(children, remove_inside?)
    child_parent_tags = ctx.parent_tags |> MapSet.put(tag)

    child_parent_tags =
      if heading_tag?(tag) or tag in ["td", "th"] do
        MapSet.put(child_parent_tags, "_inline")
      else
        child_parent_tags
      end

    child_parent_tags =
      if tag in ["pre", "code", "kbd", "samp"] do
        MapSet.put(child_parent_tags, "_noformat")
      else
        child_parent_tags
      end

    child_strings =
      children
      |> Enum.with_index()
      |> Enum.map(fn {child, index} ->
        process_element(child, %{
          ctx
          | parent_tags: child_parent_tags,
            parent: node,
            prev: sibling_at(children, index - 1),
            next: sibling_at(children, index + 1),
            index: index,
            siblings: children,
            ancestors: [node | ctx.ancestors]
        })
      end)
      |> Enum.reject(&(&1 == ""))

    text =
      if tag == "pre" or Enum.any?(ctx.ancestors, &(node_tag(&1) == "pre")) do
        Enum.join(child_strings)
      else
        collapse_child_boundaries(child_strings)
      end

    if should_convert_tag?(tag, ctx.options) do
      convert_with_custom_converter(tag, node, text, ctx)
    else
      text
    end
  end

  defp convert_with_custom_converter(tag, node, text, ctx) do
    default = fn -> convert_tag(tag, node, text, ctx) end

    case ctx.options.converter do
      nil ->
        default.()

      module when is_atom(module) ->
        if function_exported?(module, :convert, 5) do
          case module.convert(tag, node, text, public_context(ctx), default) do
            :default -> default.()
            converted when is_binary(converted) -> converted
          end
        else
          default.()
        end
    end
  end

  defp public_context(ctx) do
    %{
      parent_tags: ctx.parent_tags,
      parent: ctx.parent,
      previous_sibling: ctx.prev,
      next_sibling: ctx.next,
      ancestors: ctx.ancestors,
      options: ctx.options
    }
  end

  defp reject_ignored_children(children, remove_inside?) do
    children
    |> Enum.with_index()
    |> Enum.reject(fn {child, index} ->
      prev = sibling_at(children, index - 1)
      next = sibling_at(children, index + 1)

      cond do
        element_node?(child) ->
          false

        is_binary(child) and trim_ascii(child) != "" ->
          false

        is_binary(child) and remove_inside? and (is_nil(prev) or is_nil(next)) ->
          true

        is_binary(child) and
            (remove_whitespace_outside?(prev) or remove_whitespace_outside?(next)) ->
          true

        is_nil(child) ->
          true

        true ->
          false
      end
    end)
    |> Enum.map(&elem(&1, 0))
  end

  defp collapse_child_boundaries(child_strings) do
    child_strings
    |> Enum.reduce([], fn child, acc ->
      {leading, content, trailing} = extract_newlines(child)

      case acc do
        [prev | rest] when prev != "" and leading != "" ->
          nl = String.duplicate("\n", min(2, max(String.length(prev), String.length(leading))))
          [trailing, content, nl | rest]

        _ ->
          [trailing, content, leading | acc]
      end
    end)
    |> Enum.reverse()
    |> Enum.join()
  end

  defp extract_newlines(text) do
    leading = Regex.run(~r/^\n*/, text) |> hd()
    trailing = Regex.run(~r/\n*$/, text) |> hd()

    content =
      text
      |> String.slice(String.length(leading)..-1//1)
      |> String.slice(
        0,
        max(0, String.length(text) - String.length(leading) - String.length(trailing))
      )

    {leading, content || "", trailing}
  end

  defp process_text(text, ctx) do
    text =
      if MapSet.member?(ctx.parent_tags, "pre") do
        text
      else
        if ctx.options.wrap do
          Regex.replace(~r/[\t \r\n]+/, text, " ")
        else
          text
          |> replace_re(~r/[\t \r\n]*[\r\n][\t \r\n]*/, "\n")
          |> replace_re(~r/[\t ]+/, " ")
        end
      end

    text =
      if MapSet.member?(ctx.parent_tags, "_noformat") do
        text
      else
        escape(text, ctx.options)
      end

    text =
      if remove_whitespace_outside?(ctx.prev) or
           (remove_whitespace_inside?(ctx.parent) and is_nil(ctx.prev)) do
        trim_leading_ascii(text)
      else
        text
      end

    text =
      if remove_whitespace_outside?(ctx.next) or
           (remove_whitespace_inside?(ctx.parent) and is_nil(ctx.next)) do
        trim_trailing_ascii(text)
      else
        text
      end

    String.replace(text, @space_sentinel, " ")
  end

  defp should_convert_tag?(tag, options) do
    cond do
      is_list(options.strip) -> tag not in options.strip
      is_list(options.convert) -> tag in options.convert
      true -> true
    end
  end

  defp convert_tag("[document]", _node, text, ctx) do
    case ctx.options.strip_document do
      @lstrip -> String.trim_leading(text, "\n")
      @rstrip -> String.trim_trailing(text, "\n")
      @strip -> String.trim(text, "\n")
      nil -> text
      other -> raise ArgumentError, "Invalid value for strip_document: #{inspect(other)}"
    end
  end

  defp convert_tag("a", node, text, ctx) do
    if MapSet.member?(ctx.parent_tags, "_noformat") do
      text
    else
      {prefix, suffix, text} = chomp(text)
      href = attr(node, "href")
      title = attr(node, "title")

      cond do
        text == "" ->
          ""

        ctx.options.autolinks and String.replace(text, "\\_", "_") == href and is_nil(title) and
            not ctx.options.default_title ->
          "<#{href}>"

        is_binary(href) ->
          title = if ctx.options.default_title and is_nil(title), do: href, else: title
          title_part = if title, do: " \"#{String.replace(title, "\"", "\\\"")}\"", else: ""
          "#{prefix}[#{text}](#{href}#{title_part})#{suffix}"

        true ->
          text
      end
    end
  end

  defp convert_tag("b", node, text, ctx),
    do: inline(node, text, ctx, ctx.options.strong_em_symbol <> ctx.options.strong_em_symbol)

  defp convert_tag("strong", node, text, ctx), do: convert_tag("b", node, text, ctx)

  defp convert_tag("em", node, text, ctx),
    do: inline(node, text, ctx, ctx.options.strong_em_symbol)

  defp convert_tag("i", node, text, ctx), do: convert_tag("em", node, text, ctx)
  defp convert_tag("del", node, text, ctx), do: inline(node, text, ctx, "~~")
  defp convert_tag("s", node, text, ctx), do: convert_tag("del", node, text, ctx)
  defp convert_tag("sub", node, text, ctx), do: inline(node, text, ctx, ctx.options.sub_symbol)
  defp convert_tag("sup", node, text, ctx), do: inline(node, text, ctx, ctx.options.sup_symbol)

  defp convert_tag("blockquote", _node, text, ctx) do
    text = trim_ascii(text || "")

    cond do
      MapSet.member?(ctx.parent_tags, "_inline") ->
        " #{text} "

      text == "" ->
        "\n"

      true ->
        "\n" <>
          Regex.replace(~r/^(.*)/m, text, fn _, line ->
            if line == "", do: ">", else: "> " <> line
          end) <> "\n\n"
    end
  end

  defp convert_tag("br", _node, _text, ctx) do
    cond do
      MapSet.member?(ctx.parent_tags, "_inline") -> " "
      ctx.options.newline_style == @backslash -> "\\\n"
      true -> "  \n"
    end
  end

  defp convert_tag(tag, _node, text, ctx) when tag in ["code", "kbd", "samp"] do
    if MapSet.member?(ctx.parent_tags, "_noformat") do
      text
    else
      {prefix, suffix, text} = chomp(text)

      if text == "" do
        ""
      else
        max_ticks =
          Regex.scan(~r/`+/, text)
          |> Enum.map(fn [ticks] -> String.length(ticks) end)
          |> Enum.max(fn -> 0 end)

        delimiter = String.duplicate("`", max_ticks + 1)
        text = if max_ticks > 0, do: " #{text} ", else: text
        "#{prefix}#{delimiter}#{text}#{delimiter}#{suffix}"
      end
    end
  end

  defp convert_tag(tag, _node, text, ctx) when tag in ["div", "article", "section", "dl"] do
    if MapSet.member?(ctx.parent_tags, "_inline") do
      " #{trim_ascii(text)} "
    else
      text = trim_ascii(text)
      if text == "", do: "", else: "\n\n#{text}\n\n"
    end
  end

  defp convert_tag("dd", _node, text, ctx) do
    text = trim_ascii(text || "")

    cond do
      MapSet.member?(ctx.parent_tags, "_inline") ->
        " #{text} "

      text == "" ->
        "\n"

      true ->
        Regex.replace(~r/^(.*)/m, text, fn _, line ->
          if line == "", do: "", else: "    " <> line
        end)
        |> String.replace_prefix("    ", ":   ")
        |> Kernel.<>("\n")
    end
  end

  defp convert_tag("dt", _node, text, ctx) do
    text = text |> trim_ascii() |> replace_re(~r/[\t \r\n]+/, " ")

    cond do
      MapSet.member?(ctx.parent_tags, "_inline") -> " #{text} "
      text == "" -> "\n"
      true -> "\n\n#{text}\n"
    end
  end

  defp convert_tag(tag, _node, text, ctx) when tag in ["h1", "h2", "h3", "h4", "h5", "h6"] do
    [_, n] = Regex.run(~r/^h(\d+)$/, tag)
    convert_heading(String.to_integer(n), text, ctx)
  end

  defp convert_tag(tag, node, text, ctx) do
    case Regex.run(~r/^h(\d+)$/, tag) do
      [_, n] -> convert_heading(String.to_integer(n), text, ctx)
      _ -> convert_known_tag(tag, node, text, ctx)
    end
  end

  defp convert_known_tag("hr", _node, _text, _ctx), do: "\n\n---\n\n"

  defp convert_known_tag("img", node, _text, ctx) do
    alt = attr(node, "alt") || ""
    src = attr(node, "src") || ""
    title = attr(node, "title") || ""
    title_part = if title != "", do: " \"#{String.replace(title, "\"", "\\\"")}\"", else: ""
    parent_name = ctx.parent && node_tag(ctx.parent)

    if MapSet.member?(ctx.parent_tags, "_inline") and
         parent_name not in ctx.options.keep_inline_images_in do
      alt
    else
      "![#{alt}](#{src}#{title_part})"
    end
  end

  defp convert_known_tag("video", node, text, ctx) do
    parent_name = ctx.parent && node_tag(ctx.parent)

    if MapSet.member?(ctx.parent_tags, "_inline") and
         parent_name not in ctx.options.keep_inline_images_in do
      text
    else
      src = attr(node, "src") || source_src(node) || ""
      poster = attr(node, "poster") || ""

      cond do
        src != "" and poster != "" -> "[![#{text}](#{poster})](#{src})"
        src != "" -> "[#{text}](#{src})"
        poster != "" -> "![#{text}](#{poster})"
        true -> text
      end
    end
  end

  defp convert_known_tag(tag, _node, text, ctx) when tag in ["ul", "ol"] do
    before_paragraph? = block_content_tag?(ctx.next) and node_tag(ctx.next) not in ["ul", "ol"]

    if MapSet.member?(ctx.parent_tags, "li") do
      "\n" <> trim_trailing_ascii(text)
    else
      "\n\n" <> text <> if(before_paragraph?, do: "\n", else: "")
    end
  end

  defp convert_known_tag("li", _node, text, ctx) do
    text = trim_ascii(text || "")

    if text == "" do
      "\n"
    else
      bullet =
        case node_tag(ctx.parent) do
          "ol" ->
            "#{ol_start(ctx.parent) + previous_li_count(ctx)}."

          _ ->
            bullets = ctx.options.bullets
            depth = ul_depth(ctx)
            String.at(bullets, rem(depth, String.length(bullets)))
        end

      bullet = bullet <> " "
      width = String.length(bullet)
      indent = String.duplicate(" ", width)

      text =
        Regex.replace(~r/^(.*)/m, text, fn _, line ->
          if line == "", do: "", else: indent <> line
        end)

      bullet <> String.slice(text, width..-1//1) <> "\n"
    end
  end

  defp convert_known_tag("p", _node, text, ctx) do
    if MapSet.member?(ctx.parent_tags, "_inline") do
      " #{trim_ascii(text)} "
    else
      text = trim_ascii(text)
      text = if ctx.options.wrap, do: wrap_text(text, ctx.options.wrap_width), else: text
      if text == "", do: "", else: "\n\n#{text}\n\n"
    end
  end

  defp convert_known_tag("pre", node, text, ctx) do
    if text == "" do
      ""
    else
      code_language =
        if is_function(ctx.options.code_language_callback, 1) do
          ctx.options.code_language_callback.(node) || ctx.options.code_language
        else
          ctx.options.code_language
        end

      text =
        case ctx.options.strip_pre do
          @strip -> strip_pre(text)
          @strip_one -> strip1_pre(text)
          nil -> text
          other -> raise ArgumentError, "Invalid value for strip_pre: #{inspect(other)}"
        end

      "\n\n```#{code_language}\n#{text}\n```\n\n"
    end
  end

  defp convert_known_tag("q", _node, text, _ctx), do: "\"" <> text <> "\""
  defp convert_known_tag("script", _node, _text, _ctx), do: ""
  defp convert_known_tag("style", _node, _text, _ctx), do: ""
  defp convert_known_tag("table", _node, text, _ctx), do: "\n\n" <> trim_ascii(text) <> "\n\n"
  defp convert_known_tag("caption", _node, text, _ctx), do: trim_ascii(text) <> "\n\n"

  defp convert_known_tag("figcaption", _node, text, _ctx),
    do: "\n\n" <> trim_ascii(text) <> "\n\n"

  defp convert_known_tag(tag, node, text, _ctx) when tag in ["td", "th"] do
    colspan = colspan(node)
    " " <> (text |> trim_ascii() |> String.replace("\n", " ")) <> String.duplicate(" |", colspan)
  end

  defp convert_known_tag("tr", node, text, ctx) do
    cells = find_all(node, ["td", "th"])
    first_row? = previous_tag_sibling(ctx) == nil
    parent = node_tag(ctx.parent)

    headrow? =
      (cells != [] and Enum.all?(cells, &(node_tag(&1) == "th"))) or
        (parent == "thead" and length(find_all(ctx.parent, ["tr"])) == 1)

    head_missing? =
      (first_row? and parent != "tbody") or
        (first_row? and parent == "tbody" and not table_has_thead?(ctx))

    full_colspan = Enum.reduce(cells, 0, fn cell, acc -> acc + colspan(cell) end)

    cond do
      (headrow? or (head_missing? and ctx.options.table_infer_header)) and first_row? ->
        "|" <> text <> "\n" <> table_rule(full_colspan)

      (head_missing? and not ctx.options.table_infer_header) or
          (first_row? and
             (parent == "table" or (parent == "tbody" and tbody_at_table_begin?(ctx)))) ->
        empty = "| " <> Enum.join(List.duplicate("", full_colspan), " | ") <> " |\n"
        empty <> table_rule(full_colspan) <> "|" <> text <> "\n"

      true ->
        "|" <> text <> "\n"
    end
  end

  defp convert_known_tag(_tag, _node, text, _ctx), do: text

  defp convert_heading(n, text, ctx) do
    if MapSet.member?(ctx.parent_tags, "_inline") do
      text
    else
      do_convert_heading(n, text, ctx)
    end
  end

  defp do_convert_heading(n, text, ctx) do
    n = max(1, min(6, n))
    text = trim_ascii(text)

    if ctx.options.heading_style == @underlined and n <= 2 do
      char = if n == 1, do: "=", else: "-"

      if text == "",
        do: "",
        else:
          "\n\n#{trim_trailing_ascii(text)}\n#{String.duplicate(char, String.length(trim_trailing_ascii(text)))}\n\n"
    else
      text = Regex.replace(~r/[\t \r\n]+/, text, " ")
      hashes = String.duplicate("#", n)

      if ctx.options.heading_style == @atx_closed do
        "\n\n#{hashes} #{text} #{hashes}\n\n"
      else
        "\n\n#{hashes} #{text}\n\n"
      end
    end
  end

  defp inline(_node, text, ctx, markup) do
    if MapSet.member?(ctx.parent_tags, "_noformat") do
      text
    else
      suffix_markup =
        if String.starts_with?(markup, "<") and String.ends_with?(markup, ">"),
          do: "</" <> String.slice(markup, 1..-1//1),
          else: markup

      {prefix, suffix, text} = chomp(text)
      if text == "", do: "", else: "#{prefix}#{markup}#{text}#{suffix_markup}#{suffix}"
    end
  end

  defp chomp(text) do
    prefix = if text != "" and String.starts_with?(text, " "), do: " ", else: ""
    suffix = if text != "" and String.ends_with?(text, " "), do: " ", else: ""
    {prefix, suffix, trim_ascii(text)}
  end

  defp escape("", _options), do: ""

  defp escape(text, options) do
    text =
      if options.escape_misc do
        text
        |> replace_re(~r/([]\\&<`[>~=+|])/, "\\\\\\1")
        |> replace_re(~r/(\s|^)(-+(?:\s|$))/, "\\1\\\\\\2")
        |> replace_re(~r/(\s|^)(\#{1,6}(?:\s|$))/, "\\1\\\\\\2")
        |> replace_re(~r/((?:\s|^)[0-9]{1,9})([.)](?:\s|$))/, "\\1\\\\\\2")
      else
        text
      end

    text = if options.escape_asterisks, do: String.replace(text, "*", "\\*"), else: text
    if options.escape_underscores, do: String.replace(text, "_", "\\_"), else: text
  end

  defp wrap_text(text, nil), do: text

  defp wrap_text(text, width) do
    text
    |> String.split("\n")
    |> Enum.map(fn line ->
      trailing = Regex.run(~r/[ \t\r\n]*$/, line) |> hd()
      content = line |> trim_leading_ascii() |> trim_trailing_ascii()
      wrapped = wrap_line(content, width)
      wrapped <> trailing
    end)
    |> Enum.join("\n")
  end

  defp wrap_line(line, width) when byte_size(line) <= width, do: line

  defp wrap_line(line, width) do
    line
    |> String.split(" ")
    |> Enum.reduce([], fn word, lines ->
      case lines do
        [] ->
          [word]

        [current | rest] ->
          if String.length(current) + 1 + String.length(word) <= width do
            [current <> " " <> word | rest]
          else
            [word, current | rest]
          end
      end
    end)
    |> Enum.reverse()
    |> Enum.join("\n")
  end

  defp strip1_pre(text) do
    text
    |> replace_re(~r/^ *\n/, "")
    |> replace_re(~r/\n *$/, "")
  end

  defp strip_pre(text) do
    text
    |> replace_re(~r/^[ \n]*\n/, "")
    |> replace_re(~r/[ \n]*$/, "")
  end

  defp replace_re(text, regex, replacement), do: Regex.replace(regex, text, replacement)

  defp trim_ascii(text), do: text |> trim_leading_ascii() |> trim_trailing_ascii()
  defp trim_leading_ascii(text), do: Regex.replace(~r/^[\x{E000}\t \r\n]+/u, text, "")
  defp trim_trailing_ascii(text), do: Regex.replace(~r/[\x{E000}\t \r\n]+$/u, text, "")

  defp sibling_at(_children, index) when index < 0, do: nil
  defp sibling_at(children, index), do: Enum.at(children, index)

  defp remove_whitespace_inside?(nil), do: false

  defp remove_whitespace_inside?(node) do
    tag = node_tag(node)

    heading_tag?(tag) or
      tag in ~w(p blockquote article div section ol ul li dl dt dd table thead tbody tfoot tr td th)
  end

  defp remove_whitespace_outside?(node),
    do: remove_whitespace_inside?(node) or node_tag(node) == "pre"

  defp element_node?({_tag, _attrs, _children}), do: true
  defp element_node?(_), do: false

  defp heading_tag?(tag), do: Regex.match?(~r/^h\d+$/, tag || "")

  defp tag_name(tag) when is_atom(tag), do: Atom.to_string(tag)
  defp tag_name(tag) when is_binary(tag), do: String.downcase(tag)

  defp set_tag({_tag, attrs, children}, tag), do: {tag, attrs, children}

  defp node_tag({tag, _attrs, _children}), do: tag_name(tag)
  defp node_tag(_), do: nil

  defp attr({_tag, attrs, _children}, name) do
    attrs
    |> Enum.find_value(fn
      {k, v} when k == name -> v
      {k, v} when is_atom(k) -> if Atom.to_string(k) == name, do: v
      _ -> nil
    end)
  end

  defp source_src(node) do
    node
    |> find_all(["source"])
    |> Enum.find_value(&attr(&1, "src"))
  end

  defp colspan(node) do
    case attr(node, "colspan") do
      value when is_binary(value) ->
        if Regex.match?(~r/^\d+$/, value),
          do: value |> String.to_integer() |> max(1) |> min(1000),
          else: 1

      _ ->
        1
    end
  end

  defp table_rule(count), do: "| " <> Enum.join(List.duplicate("---", count), " | ") <> " |\n"

  # Floki nodes do not include parent pointers. The table/list helpers below are
  # intentionally conservative and cover normal parsed fragments; context-driven
  # traversal handles the formatting-critical parent state.
  defp previous_tag_sibling(%{siblings: siblings, index: index}) when is_integer(index) do
    siblings
    |> Enum.take(index)
    |> Enum.reverse()
    |> Enum.find(&element_node?/1)
  end

  defp previous_tag_sibling(_ctx), do: nil

  defp previous_li_count(%{siblings: siblings, index: index}) when is_integer(index) do
    siblings
    |> Enum.take(index)
    |> Enum.count(&(node_tag(&1) == "li"))
  end

  defp previous_li_count(_ctx), do: 0

  defp ol_start(node) do
    case attr(node, "start") do
      value when is_binary(value) ->
        if Regex.match?(~r/^\d+$/, value), do: String.to_integer(value), else: 1

      _ ->
        1
    end
  end

  defp ul_depth(%{ancestors: ancestors}) do
    ancestors
    |> Enum.count(&(node_tag(&1) == "ul"))
    |> Kernel.-(1)
    |> max(0)
  end

  defp table_has_thead?(%{ancestors: ancestors}) do
    ancestors
    |> Enum.find(&(node_tag(&1) == "table"))
    |> case do
      nil -> false
      table -> find_all(table, ["thead"]) != []
    end
  end

  defp tbody_at_table_begin?(%{parent: tbody, ancestors: ancestors}) do
    case Enum.find(ancestors, &(node_tag(&1) == "table")) do
      nil ->
        false

      {_tag, _attrs, children} ->
        children
        |> Enum.filter(&element_node?/1)
        |> List.first()
        |> Kernel.==(tbody)
    end
  end

  defp block_content_tag?(node) when is_binary(node), do: trim_ascii(node) != ""
  defp block_content_tag?(node), do: element_node?(node)

  defp find_all({tag, _attrs, children} = node, tags) do
    current = if tag_name(tag) in tags, do: [node], else: []
    current ++ Enum.flat_map(children, &find_all(&1, tags))
  end

  defp find_all(_node, _tags), do: []
end
