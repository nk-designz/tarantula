defmodule DiscourseApp.TextExtractor do
  alias DiscourseApp.Analyzer
  alias DiscourseApp.Projects.Document

  def extract(%Document{} = document) do
    extension = document.original_filename |> Path.extname() |> String.downcase()
    absolute_path = absolute_path(document.storage_path)

    case extension do
      ".md" -> extract_markdown(absolute_path)
      ".txt" -> File.read(absolute_path)
      ".pdf" -> extract_pdf(absolute_path)
      _ -> {:error, "Dateityp #{extension} wird nicht unterstuetzt."}
    end
  end

  defp extract_markdown(path) do
    with {:ok, markdown} <- File.read(path) do
      {:ok, Analyzer.markdown_to_text(markdown)}
    end
  end

  defp extract_pdf(path) do
    case System.find_executable("pdftotext") do
      nil ->
        {:error,
         "PDF-Analyse benoetigt das Kommando pdftotext im Systempfad. Bitte poppler-utils installieren."}

      executable ->
        case System.cmd(executable, [path, "-"], stderr_to_stdout: true) do
          {output, 0} -> {:ok, output |> String.replace("\u0000", "") |> String.trim()}
          {message, _code} -> {:error, String.trim(message)}
        end
    end
  end

  defp absolute_path(path) do
    Path.expand(Path.join([File.cwd!(), "priv/static", path]))
  end
end
