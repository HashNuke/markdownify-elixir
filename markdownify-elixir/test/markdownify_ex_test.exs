defmodule MarkdownifyTest do
  use ExUnit.Case, async: true

  alias Markdownify, as: M

  defp md(html, opts \\ []) do
    M.markdownify(html, Keyword.merge([strip_document: nil], opts))
  end

  test "basic text and soup-like malformed input" do
    assert md("<span>Hello</span>") == "Hello"
    assert md(" a  b \t\t c ") == " a b c "
    assert md(" a  b \n\n c ") == " a b\nc "
  end

  test "links" do
    assert md(~s(<a href="https://google.com">Google</a>)) == "[Google](https://google.com)"
    assert md(~s(<a href="https://google.com">https://google.com</a>)) == "<https://google.com>"

    assert md(~s(<a href="https://google.com">https://google.com</a>), autolinks: false) ==
             "[https://google.com](https://google.com)"

    assert md(~s(<a href="http://google.com" title="The &quot;Goog&quot;">Google</a>)) ==
             ~S|[Google](http://google.com "The \"Goog\"")|
  end

  test "inline conversion and chomp" do
    assert md("<b>Hello</b>") == "**Hello**"
    assert md("foo <b>Hello</b> bar") == "foo **Hello** bar"
    assert md("foo<b> Hello</b> bar") == "foo **Hello** bar"
    assert md("foo <b>Hello </b>bar") == "foo **Hello** bar"
    assert md("<em>Hello</em>") == "*Hello*"
    assert md("<del>Hello</del>") == "~~Hello~~"
  end

  test "blocks and headings" do
    assert md("<blockquote>Hello</blockquote>") == "\n> Hello\n\n"
    assert md("<div>456</div>") == "\n\n456\n\n"
    assert md("<h1>Hello</h1>") == "\n\nHello\n=====\n\n"
    assert md("<h2>Hello</h2>") == "\n\nHello\n-----\n\n"
    assert md("<h3>Hello</h3>") == "\n\n### Hello\n\n"
    assert md("<h1>Hello</h1>", heading_style: :atx) == "\n\n# Hello\n\n"
    assert md("<h1>Hello</h1>", heading_style: :atx_closed) == "\n\n# Hello #\n\n"
  end

  test "line breaks, code, pre and escaping" do
    assert md("a<br />b<br />c") == "a  \nb  \nc"
    assert md("a<br />b<br />c", newline_style: :backslash) == "a\\\nb\\\nc"
    assert md("<code>*this_should_not_escape*</code>") == "`*this_should_not_escape*`"
    assert md("foo<code>`bar`</code>baz") == "foo`` `bar` ``baz"
    assert md("<pre>test\n    foo\nbar</pre>") == "\n\n```\ntest\n    foo\nbar\n```\n\n"
    assert md("*hey*dude*") == "\\*hey\\*dude\\*"
    assert md("_hey_dude_") == "\\_hey\\_dude\\_"
  end

  test "images, video and simple paragraphs" do
    assert md(~s(<img src="/path/to/img.jpg" alt="Alt text" title="Optional title" />)) ==
             ~S|![Alt text](/path/to/img.jpg "Optional title")|

    assert md(~s(<video src="/path/to/video.mp4" poster="/path/to/img.jpg">text</video>)) ==
             "[![text](/path/to/img.jpg)](/path/to/video.mp4)"

    assert md("<p>hello</p>") == "\n\nhello\n\n"
    assert md("First<p>Second</p><p>Third</p>Fourth") == "First\n\nSecond\n\nThird\n\nFourth"
  end

  test "strip and convert options" do
    assert md(~s(<a href="https://github.com/matthewwithanm">Some Text</a>), strip: ["a"]) ==
             "Some Text"

    assert md(~s(<a href="https://github.com/matthewwithanm">Some Text</a>), convert: []) ==
             "Some Text"

    assert M.markdownify("<p>Hello</p>") == "Hello"
    assert M.markdownify("<p>Hello</p>", strip_document: nil) == "\n\nHello\n\n"
  end

  test "string option keys and style values are normalized without creating atoms" do
    assert M.markdownify("<h1>Hello</h1>", %{"heading_style" => "atx"}) == "# Hello"
    assert M.markdownify("a<br>b", %{":newline_style" => "backslash"}) == "a\\\nb"

    assert_raise ArgumentError, ~r/Unknown Markdownify option/, fn ->
      M.markdownify("<p>Hello</p>", %{"not_an_option" => true})
    end

    assert_raise ArgumentError, ~r/Unknown Markdownify style value/, fn ->
      M.markdownify("<h1>Hello</h1>", %{"heading_style" => "made_up"})
    end
  end

  test "lists mirror python expectations" do
    assert md("<ol><li>a</li><li>b</li></ol>") == "\n\n1. a\n2. b\n"
    assert md(~s(<ol start="3"><li>a</li><li>b</li></ol>)) == "\n\n3. a\n4. b\n"
    assert md("<ul><li>a</li><li>b</li></ul>") == "\n\n* a\n* b\n"

    assert md(
             "<ul><li><p>first para</p><p>second para</p></li><li><p>third para</p><p>fourth para</p></li></ul>"
           ) ==
             "\n\n* first para\n\n  second para\n* third para\n\n  fourth para\n"
  end

  test "tables mirror python expectations" do
    table = """
    <table>
      <tr><th>Firstname</th><th>Lastname</th><th>Age</th></tr>
      <tr><td>Jill</td><td>Smith</td><td>50</td></tr>
      <tr><td>Eve</td><td>Jackson</td><td>94</td></tr>
    </table>
    """

    assert md(table) ==
             "\n\n| Firstname | Lastname | Age |\n| --- | --- | --- |\n| Jill | Smith | 50 |\n| Eve | Jackson | 94 |\n\n"

    missing_head = """
    <table>
      <tr><td>Firstname</td><td>Lastname</td><td>Age</td></tr>
      <tr><td>Jill</td><td>Smith</td><td>50</td></tr>
    </table>
    """

    assert md(missing_head) ==
             "\n\n|  |  |  |\n| --- | --- | --- |\n| Firstname | Lastname | Age |\n| Jill | Smith | 50 |\n\n"

    assert md(missing_head, table_infer_header: true) ==
             "\n\n| Firstname | Lastname | Age |\n| --- | --- | --- |\n| Jill | Smith | 50 |\n\n"
  end
end
