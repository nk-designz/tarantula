defmodule DiscourseApp.Analyzer do
  alias DiscourseApp.Settings

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
    settings = Settings.get_llm_settings()
    analyze_text(text, settings)
  end

  def analyze_text(text, settings) when is_binary(text) do
    with {:ok, json_content} <- call_llm(text, settings),
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

  # ── Provider routing ────────────────────────────────────────────────────────

  defp call_llm(text, %{provider: "ollama"} = settings), do: call_ollama(text, settings)
  defp call_llm(text, %{provider: "claude"} = settings), do: call_claude(text, settings)
  defp call_llm(text, %{provider: "openai"} = settings), do: call_openai(text, settings)

  defp call_llm(_text, %{provider: p}),
    do: {:error, "Unknown LLM provider: #{p}. Check Settings."}

  # ── Ollama ────────────────────────────────────────────────────────────────────

  defp call_ollama(text, settings) do
    base_url = String.trim_trailing(settings.ollama_url || "http://localhost:11434", "/")
    url = base_url <> "/api/chat"

    model =
      if settings.ollama_model && settings.ollama_model != "",
        do: settings.ollama_model,
        else: "llama3"

    payload = %{
      model: model,
      format: "json",
      stream: false,
      messages: [
        %{role: "system", content: @system_prompt},
        %{role: "user", content: text}
      ]
    }

    case Req.post(url, json: payload, receive_timeout: 1_000_000) do
      {:ok, %{status: 200, body: %{"message" => %{"content" => content}}}} ->
        {:ok, content}

      {:ok, %{status: 404}} ->
        {:error, "Model '#{model}' not found in Ollama. Run: ollama pull #{model}"}

      {:ok, response} ->
        {:error, "Unexpected Ollama status: #{response.status}"}

      {:error, reason} ->
        {:error, "Verbindungsfehler zu Ollama: #{inspect(reason)}"}
    end
  end

  # ── Claude (Anthropic) ────────────────────────────────────────────────────────

  defp call_claude(text, settings) do
    key = settings.claude_api_key || ""

    if key == "" do
      {:error, "No Claude API key configured. Add it in Settings."}
    else
      model =
        if settings.claude_model && settings.claude_model != "",
          do: settings.claude_model,
          else: "claude-opus-4-5"

      payload = %{
        model: model,
        max_tokens: 4096,
        system: @system_prompt,
        messages: [%{role: "user", content: text}]
      }

      headers = [
        {"x-api-key", key},
        {"anthropic-version", "2023-06-01"},
        {"content-type", "application/json"}
      ]

      case Req.post("https://api.anthropic.com/v1/messages",
             json: payload,
             headers: headers,
             receive_timeout: 120_000
           ) do
        {:ok, %{status: 200, body: %{"content" => [%{"text" => text_resp} | _]}}} ->
          {:ok, text_resp}

        {:ok, %{status: 401}} ->
          {:error, "Claude API key is invalid or expired."}

        {:ok, %{status: 429}} ->
          {:error, "Claude rate limit exceeded. Try again later."}

        {:ok, %{status: status, body: body}} ->
          msg = (is_map(body) && body["error"]["message"]) || "status #{status}"
          {:error, "Claude error: #{msg}"}

        {:error, reason} ->
          {:error, "Claude connection error: #{inspect(reason)}"}
      end
    end
  end

  # ── OpenAI ────────────────────────────────────────────────────────────────────

  defp call_openai(text, settings) do
    key = settings.openai_api_key || ""

    if key == "" do
      {:error, "No OpenAI API key configured. Add it in Settings."}
    else
      model =
        if settings.openai_model && settings.openai_model != "",
          do: settings.openai_model,
          else: "gpt-4o"

      payload = %{
        model: model,
        response_format: %{type: "json_object"},
        messages: [
          %{role: "system", content: @system_prompt},
          %{role: "user", content: text}
        ]
      }

      headers = [
        {"authorization", "Bearer #{key}"},
        {"content-type", "application/json"}
      ]

      case Req.post("https://api.openai.com/v1/chat/completions",
             json: payload,
             headers: headers,
             receive_timeout: 120_000
           ) do
        {:ok, %{status: 200, body: %{"choices" => [%{"message" => %{"content" => content}} | _]}}} ->
          {:ok, content}

        {:ok, %{status: 401}} ->
          {:error, "OpenAI API key is invalid or expired."}

        {:ok, %{status: 429}} ->
          {:error, "OpenAI rate limit exceeded. Try again later."}

        {:ok, %{status: status, body: body}} ->
          msg = (is_map(body) && get_in(body, ["error", "message"])) || "status #{status}"
          {:error, "OpenAI error: #{msg}"}

        {:error, reason} ->
          {:error, "OpenAI connection error: #{inspect(reason)}"}
      end
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
