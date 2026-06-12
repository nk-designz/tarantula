defmodule DiscourseApp.Analyzer do
  @ollama_url "http://localhost:11434/api/chat"

  @system_prompt """
  You are a precise data extraction algorithm for Discourse Network Analysis (DNA).
  Analyze the text provided by the user and extract all actors, their concepts/topics, and their stance.

  CRITICAL RULES:
  1. Extract EVERY distinct political or substantive argument mentioned in the text. Do not compress different topics into a single concept.
  2. If a sentence states that MULTIPLE actors share the same position (e.g., "Both Actor A and Actor B support Concept X"), you MUST create separate JSON objects for each individual actor.
  3. For ACTOR names: Use short, standardized group names or individual names (e.g., use "Johannes Varwick" instead of "Prof. Dr. Johannes Varwick"). If an actor or group is mentioned with slight variations, always use the EXACT same standardized name.
  4. For CONCEPT names: Keep them concise but specific to the political topic (e.g., "Waffenlieferungen", "NATO-Mitgliedschaft", "Diplomatische Verhandlungen").
  5. The output MUST be a valid JSON array of objects. Do not wrap it in an outer object, and do not include markdown formatting.

  JSON SCHEMA:
  [
    {
      "actor": "Standardized Name",
      "concept": "Specific Political Concept",
      "stance": "pro" | "contra" | "neutral"
    }
  ]
  """

  @doc """
  Hauptfunktion: Parsed das Markdown, sendet den reinen Text an DeepSeek
  und bereitet die Daten strukturiert für D3.js vor.
  """
  def analyze_markdown(markdown) do
    text = extract_text(markdown)

    with {:ok, json_content} <- call_ollama(text),
         {:ok, decoded} <- Jason.decode(json_content) do
      IO.inspect(decoded, label: "Decoded JSON from DeepSeek")
      statements = normalize_statements(decoded)
      {:ok, format_for_d3(statements)}
    else
      error -> {:error, "Analyse mit DeepSeek fehlgeschlagen: #{inspect(error)}"}
    end
  end

  # Extrahiert den reinen Text aus dem Markdown, um Tokens zu sparen
  defp extract_text(markdown) do
    {:ok, ast, _} = Earmark.as_ast(markdown)
    extract_strings(ast)
  end

  defp extract_strings(ast) when is_list(ast),
    do: ast |> Enum.map(&extract_strings/1) |> Enum.join(" ")

  defp extract_strings({_tag, _attrs, children, _meta}), do: extract_strings(children)
  defp extract_strings(text) when is_binary(text), do: text

  # HTTP-Request an dein lokales Ollama mit DeepSeek-Coder-V2
  defp call_ollama(text) do
    payload = %{
      # Kleingeschrieben für Ollama
      model: "deepseek-coder-v2:latest",
      # Zwingt DeepSeek in den JSON-Modus
      format: "json",
      stream: false,
      messages: [
        %{role: "system", content: @system_prompt},
        %{role: "user", content: text}
      ]
    }

    # Hoher Timeout für das große MoE-Modell
    case Req.post(@ollama_url, json: payload, receive_timeout: 1_000_000) do
      {:ok, %{status: 200, body: %{"message" => %{"content" => content}}}} ->
        {:ok, content}

      {:ok, %{status: 404}} ->
        {:error,
         "Modell 'deepseek-coder-v2:latest' nicht in Ollama gefunden. Bitte 'ollama pull deepseek-coder-v2' ausführen."}

      {:ok, response} ->
        {:error, "Unerwarteter API-Status von Ollama: #{response.status}"}

      {:error, reason} ->
        {:error, "Verbindungsfehler zu Ollama: #{inspect(reason)}"}
    end
  end

  # Fall 1: Das LLM liefert das nackte Array (wie gewünscht)
  defp normalize_statements(list) when is_list(list), do: list

  # Fall 2: DeepSeek versteckt es in "actors" (Das ist dein aktueller Fall!)
  defp normalize_statements(%{"actors" => list}) when is_list(list), do: list

  # Fall 3: Ein anderes Modell versteckt es in "statements"
  defp normalize_statements(%{"statements" => list}) when is_list(list), do: list

  # Fall 4: Das Modell liefert nur eine einzige Aussage als direkte Map
  defp normalize_statements(map) when is_map(map), do: [map]

  # Fall 5: Sicherheitsnetz für unvorhergesehene Strukturen
  defp normalize_statements(_), do: []

  # Formatiert die Statements in das von D3.js erwartete Nodes/Links-Schema
  defp format_for_d3(statements) do
    valid_statements =
      Enum.filter(statements, fn s ->
        is_map(s) and s["actor"] != nil and s["concept"] != nil and s["stance"] != nil
      end)

    actors =
      valid_statements
      |> Enum.map(&%{id: &1["actor"], group: "actor"})
      |> Enum.uniq()

    concepts =
      valid_statements
      |> Enum.map(&%{id: &1["concept"], group: "concept"})
      |> Enum.uniq()

    links =
      Enum.map(valid_statements, fn stmt ->
        %{
          source: stmt["actor"],
          target: stmt["concept"],
          stance: String.downcase(to_string(stmt["stance"]))
        }
      end)

    %{nodes: actors ++ concepts, links: links}
  end
end
