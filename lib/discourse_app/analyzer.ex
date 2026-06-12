defmodule DiscourseApp.Analyzer do
  @ollama_url "http://localhost:11434/api/chat"

  @system_prompt """
  You are a precise data extraction algorithm for Discourse Network Analysis (DNA).
  Analyze the text provided by the user and extract all actors, their concepts/topics, their stance,
  and the shortest possible source excerpt that proves the stance.

  CRITICAL RULES:
  1. Extract every distinct substantive argument mentioned in the text.
  2. If multiple actors share a position, return a separate JSON object for each actor.
  3. Standardize repeated actor names consistently.
  4. Keep concept names concise but specific.
  5. Return evidence as a short direct quote or tight paraphrase from the text.
  6. The output must be a valid JSON array of objects with no markdown.

  JSON SCHEMA:
  [
    {
      "actor": "Standardized Name",
      "concept": "Specific Concept",
      "stance": "pro" | "contra" | "neutral",
      "evidence": "Quoted or paraphrased source excerpt"
    }
  ]
  """

  def analyze_markdown(markdown) do
    markdown
    |> markdown_to_text()
    |> analyze_text()
    |> case do
      {:ok, statements} -> {:ok, format_for_d3(statements)}
      {:error, reason} -> {:error, reason}
    end
  end

  def analyze_text(text) when is_binary(text) do
    with {:ok, json_content} <- call_ollama(text),
         {:ok, decoded} <- decode_json_payload(json_content) do
      statements =
        decoded
        |> normalize_statements()
        |> Enum.map(&prepare_statement/1)
        |> Enum.reject(&is_nil/1)

      if statements == [] do
        {:error, "Keine verwertbaren Aussagen aus LLM-Antwort extrahiert."}
      else
        {:ok, statements}
      end
    else
      {:error, reason} -> {:error, reason}
      other -> {:error, inspect(other)}
    end
  end

  def markdown_to_text(markdown) do
    {:ok, ast, _messages} = Earmark.as_ast(markdown)
    extract_strings(ast)
  end

  defp extract_strings(ast) when is_list(ast),
    do: ast |> Enum.map(&extract_strings/1) |> Enum.join(" ")

  defp extract_strings({_tag, _attrs, children, _meta}), do: extract_strings(children)
  defp extract_strings(text) when is_binary(text), do: text
  defp extract_strings(_value), do: ""

  defp call_ollama(text) do
    payload = %{
      model: "deepseek-coder-v2:latest",
      format: "json",
      stream: false,
      messages: [
        %{role: "system", content: @system_prompt},
        %{role: "user", content: text}
      ]
    }

    case Req.post(@ollama_url, json: payload, receive_timeout: 1_000_000) do
      {:ok, %{status: 200, body: %{"message" => %{"content" => content}}}} ->
        {:ok, content}

      {:ok, %{status: 404}} ->
        {:error,
         "Modell 'deepseek-coder-v2:latest' nicht in Ollama gefunden. Bitte 'ollama pull deepseek-coder-v2' ausfuehren."}

      {:ok, response} ->
        {:error, "Unerwarteter API-Status von Ollama: #{response.status}"}

      {:error, reason} ->
        {:error, "Verbindungsfehler zu Ollama: #{inspect(reason)}"}
    end
  end

  defp decode_json_payload(content) when is_binary(content) do
    trimmed = String.trim(content)

    case Jason.decode(trimmed) do
      {:ok, decoded} -> {:ok, decoded}
      _ -> decode_json_fallback(trimmed)
    end
  end

  defp decode_json_fallback(content) do
    candidates = [extract_fenced_json(content), extract_json_fragment(content)]

    candidates
    |> Enum.reject(&is_nil/1)
    |> Enum.find_value(fn candidate ->
      case Jason.decode(candidate) do
        {:ok, decoded} -> {:ok, decoded}
        _ -> nil
      end
    end)
    |> case do
      nil -> {:error, "LLM-Antwort war kein gueltiges JSON."}
      result -> result
    end
  end

  defp extract_fenced_json(content) do
    case Regex.run(~r/```(?:json)?\s*(\{[\s\S]*\}|\[[\s\S]*\])\s*```/i, content) do
      [_, json] -> String.trim(json)
      _ -> nil
    end
  end

  defp extract_json_fragment(content) do
    object = Regex.run(~r/(\{[\s\S]*\})/, content)
    array = Regex.run(~r/(\[[\s\S]*\])/, content)

    candidate =
      [object, array]
      |> Enum.map(fn
        [_, match] -> match
        _ -> nil
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.max_by(&String.length/1, fn -> nil end)

    if candidate, do: String.trim(candidate), else: nil
  end

  defp normalize_statements(list) when is_list(list), do: list
  defp normalize_statements(%{"actors" => list}) when is_list(list), do: list
  defp normalize_statements(%{"statements" => list}) when is_list(list), do: list
  defp normalize_statements(%{"results" => list}) when is_list(list), do: list
  defp normalize_statements(%{"items" => list}) when is_list(list), do: list
  defp normalize_statements(%{"data" => data}), do: normalize_statements(data)
  defp normalize_statements(%{"output" => data}), do: normalize_statements(data)

  defp normalize_statements(map) when is_map(map) do
    cond do
      statement_map?(map) ->
        [map]

      true ->
        map
        |> Map.values()
        |> Enum.find([], fn
          value when is_list(value) -> value
          _ -> []
        end)
    end
  end

  defp normalize_statements(_other), do: []

  defp prepare_statement(statement) when is_map(statement) do
    actor =
      statement |> get_first_value(["actor", "name", "entity", "subject"]) |> normalize_label()

    concept =
      statement
      |> get_first_value(["concept", "topic", "issue", "claim", "theme"])
      |> normalize_label()

    stance =
      statement
      |> get_first_value(["stance", "position", "sentiment", "polarity"])
      |> normalize_stance()

    evidence =
      statement
      |> get_first_value(["evidence", "excerpt", "quote", "rationale", "reason"])
      |> clean_excerpt()

    if actor == "" or concept == "" or is_nil(stance) do
      nil
    else
      %{
        "actor" => actor,
        "concept" => concept,
        "stance" => stance,
        "evidence" => evidence
      }
    end
  end

  defp prepare_statement(_other), do: nil

  defp statement_map?(map) when is_map(map) do
    get_first_value(map, ["actor", "name", "entity", "subject"]) != nil and
      get_first_value(map, ["concept", "topic", "issue", "claim", "theme"]) != nil
  end

  defp get_first_value(map, keys) when is_map(map) do
    Enum.find_value(keys, fn key -> get_value(map, key) end)
  end

  defp get_value(map, key) when is_map(map) and is_binary(key) do
    expected = String.downcase(key)

    Enum.find_value(map, fn
      {k, v} when is_binary(k) -> if String.downcase(k) == expected, do: v
      {k, v} when is_atom(k) -> if String.downcase(Atom.to_string(k)) == expected, do: v
      _ -> nil
    end)
  end

  defp normalize_label(nil), do: ""

  defp normalize_label(value) do
    value
    |> to_string()
    |> String.trim()
    |> String.replace(~r/\s+/, " ")
  end

  defp normalize_stance(nil), do: nil

  defp normalize_stance(value) do
    case value |> to_string() |> String.trim() |> String.downcase() do
      "pro" -> "pro"
      "support" -> "pro"
      "supports" -> "pro"
      "contra" -> "contra"
      "con" -> "contra"
      "oppose" -> "contra"
      "opposes" -> "contra"
      "against" -> "contra"
      "neutral" -> "neutral"
      "mixed" -> "neutral"
      "unknown" -> "neutral"
      _ -> nil
    end
  end

  defp clean_excerpt(nil), do: nil

  defp clean_excerpt(value) do
    value
    |> to_string()
    |> String.trim()
    |> String.replace(~r/\s+/, " ")
    |> case do
      "" -> nil
      excerpt -> String.slice(excerpt, 0, 280)
    end
  end

  defp format_for_d3(statements) do
    actor_nodes =
      statements
      |> Enum.map(& &1["actor"])
      |> Enum.uniq()
      |> Enum.map(fn actor ->
        %{id: "actor:#{actor}", label: actor, group: "actor", weight: 1}
      end)

    concept_nodes =
      statements
      |> Enum.map(& &1["concept"])
      |> Enum.uniq()
      |> Enum.map(fn concept ->
        %{id: "concept:#{concept}", label: concept, group: "concept", weight: 1}
      end)

    links =
      Enum.map(statements, fn statement ->
        %{
          source: "actor:#{statement["actor"]}",
          target: "concept:#{statement["concept"]}",
          stance: statement["stance"],
          weight: 1
        }
      end)

    %{nodes: actor_nodes ++ concept_nodes, links: links}
  end
end
