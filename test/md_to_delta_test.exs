defmodule MdToDeltaTest do
  use ExUnit.Case
  doctest MdToDelta

  @fixtures_dir "test/fixtures"
  @expected_dir "test/expected"

  test_types = File.ls!(@fixtures_dir)

  for type <- test_types do
    describe "#{type} parsing" do
      test_dir = @fixtures_dir <> "/#{type}"

      test_file_names =
        test_dir
        |> File.ls!()
        |> Enum.map(&String.replace(&1, ".md", ""))
        |> Enum.sort()

      for file_name <- test_file_names do
        test file_name do
          file_name = unquote(file_name)
          type = unquote(type)

          file_path = "/#{type}/" <> file_name

          expected =
            @expected_dir
            |> Kernel.<>(file_path)
            |> Kernel.<>(".json")
            |> File.read!()
            |> Jason.decode!()

          actual =
            @fixtures_dir
            |> Kernel.<>(file_path)
            |> Kernel.<>(".md")
            |> File.read!()
            |> MdToDelta.parse()

          assert actual == expected
        end
      end
    end
  end
end
