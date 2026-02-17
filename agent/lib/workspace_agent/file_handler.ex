defmodule WorkspaceAgent.FileHandler do
  @moduledoc """
  Handles file operations: read, write, and directory listing.
  Restricts all operations to /home/user/ and /tmp/ to prevent path traversal.
  """

  import Plug.Conn

  require Logger

  @allowed_prefixes ["/home/user/", "/tmp/"]
  @ignored_dirs ~w(_build deps .elixir_ls node_modules .git .hex .mix .cache)

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

  def handle_read(conn, path) do
    resolved = Path.expand(path)

    if path_allowed?(resolved) do
      case File.read(resolved) do
        {:ok, content} ->
          conn
          |> put_resp_content_type("application/octet-stream")
          |> send_resp(200, content)

        {:error, :enoent} ->
          conn
          |> put_resp_content_type("application/json")
          |> send_resp(404, Jason.encode!(%{error: "file not found"}))

        {:error, reason} ->
          conn
          |> put_resp_content_type("application/json")
          |> send_resp(500, Jason.encode!(%{error: "read failed: #{inspect(reason)}"}))
      end
    else
      Logger.warning("Blocked file read from disallowed path: #{resolved}")

      conn
      |> put_resp_content_type("application/json")
      |> send_resp(403, Jason.encode!(%{error: "path not allowed"}))
    end
  end

  def handle_tree(conn, path) do
    resolved = Path.expand(path)

    if path_allowed?(resolved) do
      case File.stat(resolved) do
        {:ok, %{type: :directory}} ->
          files = build_tree(resolved)

          conn
          |> put_resp_content_type("application/json")
          |> send_resp(200, Jason.encode!(%{root: resolved, files: files}))

        {:ok, _} ->
          conn
          |> put_resp_content_type("application/json")
          |> send_resp(400, Jason.encode!(%{error: "path is not a directory"}))

        {:error, :enoent} ->
          conn
          |> put_resp_content_type("application/json")
          |> send_resp(404, Jason.encode!(%{error: "directory not found"}))

        {:error, reason} ->
          conn
          |> put_resp_content_type("application/json")
          |> send_resp(500, Jason.encode!(%{error: "stat failed: #{inspect(reason)}"}))
      end
    else
      Logger.warning("Blocked tree listing for disallowed path: #{resolved}")

      conn
      |> put_resp_content_type("application/json")
      |> send_resp(403, Jason.encode!(%{error: "path not allowed"}))
    end
  end

  defp path_allowed?(resolved) do
    Enum.any?(@allowed_prefixes, &String.starts_with?(resolved, &1))
  end

  defp build_tree(root) do
    root
    |> walk_dir([])
    |> Enum.map(&Path.relative_to(&1, root))
    |> Enum.sort()
  end

  defp walk_dir(dir, acc) do
    case File.ls(dir) do
      {:ok, entries} ->
        Enum.reduce(Enum.sort(entries), acc, fn entry, acc ->
          if entry in @ignored_dirs do
            acc
          else
            full = Path.join(dir, entry)

            case File.stat(full) do
              {:ok, %{type: :directory}} -> walk_dir(full, acc)
              {:ok, %{type: :regular}} -> [full | acc]
              _ -> acc
            end
          end
        end)

      {:error, _} ->
        acc
    end
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
