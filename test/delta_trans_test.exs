defmodule DeltaTransTest do
  use ExUnit.Case

  test "from_markdown/1 then to_html/2 returns html without linebreaks" do
    markdown = """
    # Heading
    paragraph 1

    paragraph 2

    ## Heading 2
    text
    1. ordered list item 1
    2. ordered list item 2

       paragraph in ordered list item 2

       paragraph 2 in ordered list item 2


        1. ordered list subitem 2.1
        2. ordered list subitem 2.2
    3. ordered list item 3
      - unorded list subitem
    4. ordered list item 4

    * list item 1
    * list item 2
    * list item 3

    ### Heading 3
    paragraph 3

    paragraph 4

    - list item 4

      paragraph in list item 4

    paragraph 5

    1. list item 5

        paragraph in list item 5

    """

    html =
      markdown
      |> DeltaTrans.from_markdown()
      |> DeltaTrans.to_html()

    assert """
           <h1>Heading</h1><p>paragraph 1</p><p>paragraph 2</p><h2>Heading 2</h2><p>text</p><ol><li>ordered list item 1</li><li>ordered list item 2</li><li>paragraph in ordered list item 2</li><li>paragraph 2 in ordered list item 2<ol><li>ordered list subitem 2.1</li><li>ordered list subitem 2.2</li></ol></li><li>ordered list item 3</li></ol><ul><li>unorded list subitem</li></ul><ol><li>ordered list item 4</li></ol><ul><li>list item 1</li><li>list item 2</li><li>list item 3</li></ul><p>paragraph 3</p><p>paragraph 4</p><ul><li>list item 4</li></ul><ol><li>list item 5</li></ol>
           """ == html <> "\n"
  end
end
