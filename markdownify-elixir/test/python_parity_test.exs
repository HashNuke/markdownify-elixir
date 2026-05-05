defmodule Markdownify.PythonParityTest do
  use ExUnit.Case, async: true

  @script Path.expand("support/collect_python_asserts.py", __DIR__)

  test "literal assertions from the retained Python test suite" do
    {json, 0} = System.cmd("python3", [@script], stderr_to_stdout: true)
    cases = JSON.decode!(json)

    assert length(cases) > 50

    failures =
      cases
      |> Enum.map(&run_case/1)
      |> Enum.reject(&match?(:ok, &1))

    assert failures == []
  end

  defp run_case(case) do
    options =
      case["options"]
      |> Enum.map(fn {key, value} -> {String.to_atom(key), atomize_option(value)} end)
      |> maybe_disable_document_strip(case)

    actual = Markdownify.markdownify(case["html"], options)

    if actual == case["expected"] do
      :ok
    else
      {:error,
       %{
         source: "#{case["file"]}:#{case["line"]}",
         options: options,
         html: case["html"],
         expected: case["expected"],
         actual: actual
       }}
    end
  end

  defp atomize_option(value)
       when value in ["atx", "atx_closed", "underlined", "spaces", "backslash"],
       do: String.to_atom(value)

  defp atomize_option(value) when value in ["lstrip", "rstrip", "strip", "strip_one"],
    do: String.to_atom(value)

  defp atomize_option(value), do: value

  defp maybe_disable_document_strip(options, %{"function" => "md"}) do
    Keyword.put_new(options, :strip_document, nil)
  end

  defp maybe_disable_document_strip(options, _case), do: options
end
