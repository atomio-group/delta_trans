defmodule DeltaTrans.MarkdownTransformerTest do
  use ExUnit.Case

  doctest DeltaTrans.MarkdownTransformer

  @dir "test/fixtures/"

  test_types = File.ls!(@dir)

  for type <- test_types do
    describe "#{type} parsing" do
      context_dir = Path.join(@dir, "#{type}/")

      files =
        context_dir
        |> File.ls!()
        |> Enum.filter(&(Path.extname(&1) == ".md"))
        |> Enum.sort()

      for file <- files do
        test Path.rootname(file) do
          file_path = Path.join(unquote(context_dir), unquote(file))

          parsed =
            file_path
            |> File.read!()
            |> MdToDelta.parse()

          expected =
            file_path
            |> String.replace("md", "json")
            |> File.read!()
            |> Jason.decode!()

          assert parsed == expected
        end
      end
    end
  end
end
