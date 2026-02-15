defmodule WorkspaceAgent.FileHandler do
  @moduledoc """
  Handles PUT /files requests — writes file content to disk.
  Restricts writes to /home/user/ to prevent path traversal.
  """

  import Plug.Conn

  require Logger

  @allowed_prefixes ["/home/user/", "/tmp/"]

  def handle(conn, path, content, mode) do
    resolved = Path.expand(path)

    if path_allowed?(resolved) do
      write_file(conn, resolved, content, mode)
    else
      Logger.warning("Blocked file write to disallowed path: #{resolved}")

      conn
      |> put_resp_content_type("application/json")
      |> send_resp(403, Jason.encode!(%{error: "path not allowed"}))
    end
  end

  defp path_allowed?(resolved) do
    Enum.any?(@allowed_prefixes, &String.starts_with?(resolved, &1))
  end

  defp write_file(conn, path, content, mode) do
    with :ok <- ensure_parent_dir(path),
         :ok <- File.write(path, content),
         :ok <- maybe_set_mode(path, mode) do
      Logger.debug("Wrote #{byte_size(content)} bytes to #{path}")

      conn
      |> put_resp_content_type("application/json")
      |> send_resp(200, Jason.encode!(%{status: "ok", path: path}))
    else
      {:error, reason} ->
        Logger.error("Failed to write #{path}: #{inspect(reason)}")

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(500, Jason.encode!(%{error: "write failed: #{inspect(reason)}"}))
    end
  end

  defp ensure_parent_dir(path) do
    dir = Path.dirname(path)
    File.mkdir_p(dir)
  end

  defp maybe_set_mode(_path, nil), do: :ok

  defp maybe_set_mode(path, mode_str) do
    case Integer.parse(mode_str, 8) do
      {mode, ""} -> File.chmod(path, mode)
      _ -> :ok
    end
  end
end
