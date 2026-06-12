defmodule DiscourseApp.Analyzer do
  alias DiscourseApp.Settings

  @system_prompt """
  You are a precise data extraction algorithm for Discourse Network Analysis (DNA).
  Analyze the text provided by the user and extract all actors, their concepts/topics, their stance,
  and the shortest possible source excerpt that proves the stance.

  CRITICAL RULES:
  1. Extract every distinct substantive argument mentioned in the text.
  2. DO NOT GROUP BY ACTOR. You MUST return a completely FLAT JSON array. Every single concept gets its own separate object. Do not nest arrays.
  3. ACTORS MUST BE REAL: Extract only actual people, organizations, or specific groups of people. NEVER extract document structure, section headings (like "Gemeinsame Schnittmengen", "Konsenspunkte"), or abstract concepts as actors.
  4. STANDARDIZE ACTORS: Use short, consistent names without academic titles (e.g., use "Johannes Varwick" instead of "Prof. Dr. Johannes Varwick").
  5. Keep concept names concise but specific.
  6. Return evidence as a short direct quote or tight paraphrase from the text.
  7. The output must be a valid JSON array of objects with no markdown.

  EXAMPLE OUTPUT (STRICTLY FOLLOW THIS FLAT STRUCTURE):
  [
    {
      "actor": "Johannes Varwick",
      "concept": "Waffenlieferungen an die Ukraine",
      "stance": "contra",
      "evidence": "Varwick sprach sich deutlich contra eine Ausweitung von schweren Waffenlieferungen aus."
    },
    {
      "actor": "Johannes Varwick",
      "concept": "Diplomatische Verhandlungen",
      "stance": "pro",
      "evidence": "Er plädierte vehement pro sofortige diplomatische Verhandlungen."
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
    with {:ok, json_content} <- call_llm(@system_prompt, text, settings),
         {:ok, decoded} <- decode_json_payload(json_content) do
      statements =
        decoded
        |> normalize_statements()
        |> Enum.map(&prepare_statement/1)
        |> Enum.reject(&is_nil/1)

      if statements == [] do
        # WICHTIG: Druckt den abgelehnten LLM-Output ins Terminal zur Fehlerdiagnose
        IO.inspect(decoded, label: "--- ABGELEHNTER ODER LEERER LLM OUTPUT ---")

        {:error,
         "Keine verwertbaren Aussagen aus LLM-Antwort extrahiert. Siehe Terminal-Log für Details."}
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

  defp call_llm(system_prompt, text, %{provider: "ollama"} = settings), do: call_ollama(system_prompt, text, settings)
  defp call_llm(system_prompt, text, %{provider: "claude"} = settings), do: call_claude(system_prompt, text, settings)
  defp call_llm(system_prompt, text, %{provider: "openai"} = settings), do: call_openai(system_prompt, text, settings)

  defp call_llm(_system_prompt, _text, %{provider: p}),
    do: {:error, "Unknown LLM provider: #{p}. Check Settings."}

  # ── Ollama ────────────────────────────────────────────────────────────────────

  defp call_ollama(system_prompt, text, settings) do
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
        %{role: "system", content: system_prompt},
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

  defp call_claude(system_prompt, text, settings) do
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
        system: system_prompt,
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

  defp call_openai(system_prompt, text, settings) do
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
          %{role: "system", content: system_prompt},
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
    # WORKAROUND: Die drei Backticks werden dynamisch zusammengesetzt,
    # damit die UI beim Kopieren nicht abstürzt.
    ticks = "`" <> "`" <> "`"

    case Regex.run(~r/#{ticks}(?:json)?\s*(\{[\s\S]*\}|\[[\s\S]*\])\s*#{ticks}/i, content) do
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

  defp normalize_statements(list) when is_list(list), do: flatten_nested_actors(list)

  defp normalize_statements(%{"actors" => list}) when is_list(list),
    do: flatten_nested_actors(list)

  defp normalize_statements(%{"statements" => list}) when is_list(list),
    do: flatten_nested_actors(list)

  defp normalize_statements(%{"results" => list}) when is_list(list),
    do: flatten_nested_actors(list)

  defp normalize_statements(%{"items" => list}) when is_list(list),
    do: flatten_nested_actors(list)

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
          value when is_list(value) -> flatten_nested_actors(value)
          _ -> []
        end)
    end
  end

  defp normalize_statements(_other), do: []

  defp flatten_nested_actors(list) do
    Enum.flat_map(list, fn
      %{"actor" => actor, "concepts" => concepts} when is_list(concepts) ->
        Enum.map(concepts, fn concept_map -> Map.put(concept_map, "actor", actor) end)

      %{"name" => actor, "concepts" => concepts} when is_list(concepts) ->
        Enum.map(concepts, fn concept_map -> Map.put(concept_map, "actor", actor) end)

      %{"actor" => actor, "statements" => statements} when is_list(statements) ->
        Enum.map(statements, fn stmt -> Map.put(stmt, "actor", actor) end)

      other ->
        [other]
    end)
  end

  defp prepare_statement(statement) when is_map(statement) do
    actor =
      statement |> get_first_value(["actor", "name", "entity", "subject"]) |> normalize_label()

    concept =
      statement
      |> get_first_value(["concept", "topic", "issue", "claim", "theme", "name"])
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
      get_first_value(map, ["concept", "topic", "issue", "claim", "theme", "name"]) != nil
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

  defp normalize_stance(value) when is_map(value) or is_list(value), do: nil
  defp normalize_stance(nil), do: nil

  defp normalize_stance(value) do
    case value |> to_string() |> String.trim() |> String.downcase() do
      "pro" -> "pro"
      "support" -> "pro"
      "supports" -> "pro"
      "dafür" -> "pro"
      "befürwortend" -> "pro"
      "zustimmend" -> "pro"
      "contra" -> "contra"
      "con" -> "contra"
      "oppose" -> "contra"
      "opposes" -> "contra"
      "against" -> "contra"
      "dagegen" -> "contra"
      "ablehnend" -> "contra"
      "kritisch" -> "contra"
      "neutral" -> "neutral"
      "mixed" -> "neutral"
      "unknown" -> "neutral"
      "unentschlossen" -> "neutral"
      "ausgewogen" -> "neutral"
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

  # ── Chunked document analysis ─────────────────────────────────────────────────
  # Splits long texts into overlapping word-windows so no single LLM call
  # exceeds safe context lengths. Results are merged and deduplicated.

  @chunk_words 2_000
  @overlap_words 200
  @min_chunk_words 50

  def analyze_text_chunked(text) when is_binary(text) do
    settings = Settings.get_llm_settings()
    analyze_text_chunked(text, settings)
  end

  def analyze_text_chunked(text, settings) when is_binary(text) do
    case chunk_text(text) do
      [_single] ->
        analyze_text(text, settings)

      chunks ->
        all_statements =
          Enum.reduce(chunks, [], fn chunk, acc ->
            case analyze_text(chunk, settings) do
              {:ok, statements} -> acc ++ statements
              {:error, _} -> acc
            end
          end)

        if all_statements == [] do
          {:error, "Keine verwertbaren Aussagen aus keinem Textabschnitt extrahiert."}
        else
          {:ok, deduplicate_statements(all_statements)}
        end
    end
  end

  defp chunk_text(text) do
    words = String.split(text, ~r/\s+/, trim: true)
    total = length(words)

    if total <= @chunk_words do
      [text]
    else
      build_chunks(words, 0, total, [])
    end
  end

  defp build_chunks(_words, start, total, acc) when start >= total, do: Enum.reverse(acc)

  defp build_chunks(words, start, total, acc) do
    chunk_end = min(start + @chunk_words, total)
    slice = Enum.slice(words, start, chunk_end - start)

    if length(slice) < @min_chunk_words do
      Enum.reverse(acc)
    else
      next_start = start + @chunk_words - @overlap_words
      build_chunks(words, next_start, total, [Enum.join(slice, " ") | acc])
    end
  end

  # Deduplicates on (actor, concept, stance) — keeps the entry with evidence when both halves of
  # an overlap window produce the same statement.
  defp deduplicate_statements(statements) do
    statements
    |> Enum.group_by(fn s ->
      actor = s["actor"] |> to_string() |> String.downcase() |> String.trim()
      concept = s["concept"] |> to_string() |> String.downcase() |> String.trim()
      {actor, concept, to_string(s["stance"])}
    end)
    |> Enum.map(fn {_key, [first | _] = group} ->
      Enum.max_by(group, fn s -> if s["evidence"] && s["evidence"] != "", do: 1, else: 0 end,
        fn -> first end)
    end)
  end

  # ── Actor disambiguation (second LLM pass) ────────────────────────────────────
  # Sends the full list of extracted actor names to the LLM asking it to map
  # variants ("J. Varwick", "Prof. Varwick") to a single canonical form.

  @disambiguate_actors_prompt """
  You are a data normalization assistant for Discourse Network Analysis.
  You receive a JSON array of actor names extracted from political discourse documents.
  Names may refer to the same person or organization under different spellings, abbreviations, or academic titles.

  TASK: Return a flat JSON object mapping each input name to its canonical form.
  - Group names that refer to the same entity under one canonical label.
  - The canonical label MUST be one of the exact input strings (choose the most complete and correct spelling).
  - If a name has no near-duplicate, map it to itself.
  - Every input name must appear as a key in the output object.
  - Return ONLY the JSON object. No markdown. No explanation.

  EXAMPLE:
  Input: ["J. Varwick", "Johannes Varwick", "Prof. Varwick", "SPD", "Sozialdemokratische Partei Deutschlands"]
  Output: {"J. Varwick": "Johannes Varwick", "Johannes Varwick": "Johannes Varwick", "Prof. Varwick": "Johannes Varwick", "SPD": "SPD", "Sozialdemokratische Partei Deutschlands": "SPD"}
  """

  def disambiguate_actors(actor_names, settings) when is_list(actor_names) do
    unique = actor_names |> Enum.reject(&is_nil/1) |> Enum.uniq()

    case unique do
      [] -> {:ok, %{}}
      [single] -> {:ok, %{single => single}}
      _ -> do_disambiguate(@disambiguate_actors_prompt, unique, settings)
    end
  end

  # ── Concept deduplication (second LLM pass) ───────────────────────────────────
  # Semantically similar concepts (e.g. "Waffenlieferungen" / "Waffenexporte")
  # are clustered by the LLM into one canonical label.

  @deduplicate_concepts_prompt """
  You are a data normalization assistant for Discourse Network Analysis.
  You receive a JSON array of concept/topic names from political discourse analysis.
  Concepts that are semantically equivalent or near-synonymous should be merged
  (e.g. "Waffenlieferungen an die Ukraine" and "Waffenexporte Ukraine" refer to the same policy debate).

  TASK: Return a flat JSON object mapping each input concept to its canonical form.
  - Group semantically equivalent or highly similar concepts under one canonical label.
  - The canonical label MUST be one of the exact input strings (choose the clearest and most descriptive one).
  - If a concept has no near-duplicate, map it to itself.
  - Every input concept must appear as a key in the output object.
  - Return ONLY the JSON object. No markdown. No explanation.
  """

  def deduplicate_concepts(concept_names, settings) when is_list(concept_names) do
    unique = concept_names |> Enum.reject(&is_nil/1) |> Enum.uniq()

    case unique do
      [] -> {:ok, %{}}
      [single] -> {:ok, %{single => single}}
      _ -> do_disambiguate(@deduplicate_concepts_prompt, unique, settings)
    end
  end

  defp do_disambiguate(system_prompt, names, settings) do
    input_json = Jason.encode!(names)

    with {:ok, raw} <- call_llm(system_prompt, input_json, settings),
         {:ok, decoded} <- decode_json_payload(raw) do
      case decoded do
        map when is_map(map) ->
          {:ok, Map.new(map, fn {k, v} -> {to_string(k), to_string(v)} end)}

        _ ->
          {:error, "Disambiguation returned unexpected JSON shape."}
      end
    end
  end

  defp format_for_d3(statements) do
    actor_nodes =
      statements
      |> Enum.map(& &1["actor"])
      |> Enum.uniq()
      |> Enum.map(fn actor ->
        %{id: "actor_#{actor}", label: actor, group: "actor", weight: 1}
      end)

    concept_nodes =
      statements
      |> Enum.map(& &1["concept"])
      |> Enum.uniq()
      |> Enum.map(fn concept ->
        %{id: "concept_#{concept}", label: concept, group: "concept", weight: 1}
      end)

    links =
      Enum.map(statements, fn statement ->
        %{
          source: "actor_#{statement["actor"]}",
          target: "concept_#{statement["concept"]}",
          stance: statement["stance"],
          evidence: statement["evidence"],
          weight: 1
        }
      end)

    %{nodes: actor_nodes ++ concept_nodes, links: links}
  end
end
