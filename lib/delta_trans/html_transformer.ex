defmodule DeltaTrans.HTMLTransformer do
  def to_html(delta, options \\ []) do
    container_tag = Keyword.get(options, :container_tag)

    delta
    |> denormalize()
    |> group_same_ops([])
    |> Enum.map(fn {grouped_ops, attributes} ->
      reduce_grouped_ops(grouped_ops, attributes, options)
    end)
    |> Enum.reduce("", fn html, acc ->
      "#{acc}#{html}"
    end)
    |> maybe_add_container_tag(container_tag)
  end

  defp denormalize(delta_ops) do
    delta_ops
    |> Enum.map(fn op ->
      insert = op["insert"]

      if not is_binary(insert) or insert == "\n" do
        op
      else
        insert
        |> String.split(~r/(\n)/, include_captures: true, trim: false)
        |> Enum.reject(&(&1 == ""))
        |> Enum.map(&%{"insert" => &1, "attributes" => op["attributes"] || nil})
      end
    end)
    |> List.flatten()
  end

  defp maybe_add_container_tag(html, nil) do
    html
  end

  defp maybe_add_container_tag(html, tag) do
    "<#{tag}>#{html}</#{tag}>"
  end

  defp group_same_ops([], acc) do
    acc
  end

  defp group_same_ops(delta_ops, acc) do
    {block, rest} = next_block(delta_ops, [])
    group_same_ops(rest, acc ++ [block])
  end

  defp next_block([], acc) do
    {acc, []}
  end

  defp next_block([%{"divider" => true} | rest], acc) do
    {{acc, nil}, rest}
  end

  defp next_block([%{"insert" => %{"image" => src}, "attributes" => attributes} | rest], _acc) do
    {{src, Map.put(attributes, "img", true)}, rest}
  end

  # list
  defp next_block(
         [
           %{"insert" => "\n", "attributes" => %{"list" => _list_type} = attributes}
           | rest
         ],
         acc
       ) do
    list_item = {acc, attributes}
    {rest, list} = next_list_item(rest, attributes, [list_item], [])
    {{list, attributes}, rest}
  end

  defp next_block([%{"insert" => "\n", "attributes" => attributes} | rest], acc) do
    {{acc, attributes}, rest}
  end

  # newline only
  defp next_block([%{"insert" => "\n"} = current | rest], []) do
    {{[{current["insert"], current["attributes"]}], nil}, rest}
  end

  # paragraph
  defp next_block([%{"insert" => "\n"} | rest], acc) do
    {{acc, nil}, rest}
  end

  defp next_block([current | rest], acc) do
    next_block(rest, acc ++ [{current["insert"], current["attributes"]}])
  end

  defp next_list_item(
         [%{"insert" => "\n", "attributes" => attribute = %{"list" => _}} | rest] = delta_ops,
         parent_attribute,
         list_acc,
         list_item_acc
       )
       when parent_attribute != attribute do
    current_indent = Map.get(attribute, "indent", 0)
    parent_indent = Map.get(parent_attribute, "indent", 0)

    if current_indent > parent_indent do
      list_item = {Enum.map(list_item_acc, &{&1["insert"], &1["attributes"]}), attribute}
      {other_ops, nested_list} = next_list_item(rest, attribute, [list_item], [])

      [{parent_acc, parent_attribute} | prev] = Enum.reverse(list_acc)

      updated_parent = {parent_acc ++ [{nested_list, attribute}], parent_attribute}
      updated_list_acc = Enum.reverse([updated_parent | prev])

      next_list_item(other_ops, parent_attribute, updated_list_acc, [])
    else
      {list_item_acc ++ delta_ops, list_acc}
    end
  end

  defp next_list_item(
         [%{"insert" => "\n", "attributes" => attribute} | rest],
         parent_list_attribute,
         list_acc,
         list_item_acc
       )
       when parent_list_attribute == attribute do
    list_item = {Enum.map(list_item_acc, &{&1["insert"], &1["attributes"]}), attribute}
    next_list_item(rest, parent_list_attribute, list_acc ++ [list_item], [])
  end

  defp next_list_item(
         [%{"insert" => "\n"} | rest],
         _parent_list_attribute,
         list_acc,
         _list_item_acc
       ) do
    {rest, list_acc}
  end

  defp next_list_item(
         [],
         _parent_list_attribute,
         list_acc,
         list_item_acc
       ) do
    {list_item_acc, list_acc}
  end

  defp next_list_item([current | rest], parent_list_attribute, list_acc, list_item_acc) do
    next_list_item(
      rest,
      parent_list_attribute,
      list_acc,
      list_item_acc ++ [current]
    )
  end

  defp reduce_grouped_ops([{"\n", nil}], nil, options) do
    render_explicit_line_break = Keyword.get(options, :render_explicit_line_break, true)

    if render_explicit_line_break do
      "<br />"
    else
      ""
    end
  end

  defp reduce_grouped_ops([{%{"divider" => true}, nil}], nil, _options) do
    "<hr />"
  end

  defp reduce_grouped_ops(grouped_ops, nil, options) do
    html_tag = Keyword.get(options, :paragraph_tag, "p")

    html =
      Enum.reduce(grouped_ops, "", fn {insert, attributes}, acc ->
        "#{acc}#{convert_single_insert(insert, attributes, options)}"
      end)

    "<#{html_tag}>#{html}</#{html_tag}>"
  end

  defp reduce_grouped_ops(src, %{"img" => true, "alt" => alt}, _options) do
    "<img src=\"#{src}\" alt=\"#{alt}\" />"
  end

  defp reduce_grouped_ops(grouped_ops, %{"list" => list_type}, options) do
    html_tag =
      case list_type do
        "bullet" -> "ul"
        "ordered" -> "ol"
      end

    li_tag = Keyword.get(options, :li_tag, "li")

    html =
      Enum.reduce(grouped_ops, "", fn list_item, acc ->
        "#{acc}<#{li_tag}>#{convert_list_item(list_item, options)}</#{li_tag}>"
      end)

    "<#{html_tag}>#{html}</#{html_tag}>"
  end

  defp reduce_grouped_ops(grouped_ops, attributes, options) do
    html_tag = attribute_to_html_tag(attributes, options)

    html =
      Enum.reduce(grouped_ops, "", fn {insert, attributes}, acc ->
        "#{acc}#{convert_single_insert(insert, attributes, options)}"
      end)

    "<#{html_tag}>#{html}</#{html_tag}>"
  end

  defp convert_single_insert(insert, nil, _options) when is_binary(insert) do
    insert
  end

  defp convert_single_insert(%{"divider" => true}, _attributes, _options) do
    "<hr />"
  end

  defp convert_single_insert(insert, attributes, options) do
    case attribute_to_html_tag(attributes, options) do
      {html_tag, attrs} ->
        html_attrs = Enum.map_join(attrs, " ", fn {k, v} -> to_string(k) <> "=" <> v end)
        "<#{html_tag} #{html_attrs}>#{insert}</#{html_tag}>"

      html_tag ->
        "<#{html_tag}>#{insert}</#{html_tag}>"
    end
  end

  defp convert_list_item({list_item_ops, _}, options) do
    Enum.reduce(list_item_ops, "", fn
      {ops, %{"list" => _list_type, "indent" => _indent} = attributes}, acc ->
        "#{acc}#{reduce_grouped_ops(ops, attributes, options)}"

      {insert, attributes}, acc ->
        "#{acc}#{convert_single_insert(insert, attributes, options)}"
    end)
  end

  # credo:disable-for-next-line
  defp attribute_to_html_tag(attribute, options) do
    case attribute do
      %{"header" => 1} -> Keyword.get(options, :h1_tag, "h1")
      %{"header" => 2} -> Keyword.get(options, :h2_tag, "h2")
      %{"header" => 3} -> Keyword.get(options, :h3_tag, "h3")
      %{"header" => 4} -> Keyword.get(options, :h4_tag, "h4")
      %{"header" => 5} -> Keyword.get(options, :h5_tag, "h5")
      %{"list" => _list} -> "li"
      %{"bold" => true} -> "strong"
      %{"italic" => true} -> "i"
      %{"strike" => true} -> "s"
      %{"link" => url} -> {"a", [href: url, target: "_blank"]}
      nil -> ""
      _ -> "span"
    end
  end
end
