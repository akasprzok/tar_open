defmodule MemoTar do
  @moduledoc """
  A convenience for creating tar files in memory.
  """

  use TypedStruct

  alias MemoTar.Tar

  typedstruct do
    field :file_device, IO.device()
    field :tar_device, IO.device()
  end

  @spec open :: {:ok, t()} | {:error, term()}
  def open do
    with {:ok, file_device} <- File.open("", [:read, :write, :ram]),
      {:ok, tar_device} <- Tar.open({:file, file_device}, [:write]) do
      {:ok, %__MODULE__{
        file_device: file_device,
        tar_device: tar_device
      }}
    end
  end

  @spec add_file(t(), Path.t(), binary()) :: :ok
  def add_file(tar, path, content) do
    Tar.add(tar.tar_device, content, String.to_charlist(path), [])
  end

  @spec add_directory(t(), Path.t()) :: :ok
  def add_directory(tar, path) do
    Tar.add_directory(tar.tar_device, String.to_charlist(path), [])
  end

  @spec close(t()) :: {:ok, binary()}
  def close(%__MODULE__{} = tar) do
    with :ok <- Tar.close(tar.tar_device),
      content <- read(tar.file_device),
      :ok <- File.close(tar.file_device) do
      {:ok, content}
    end
  end

  @spec create([{Path.t(), binary()}]) :: {:ok, binary()} | {:error, term()}
  def create(files) do
    dirs = Enum.map(files, fn {path, _content} -> Path.dirname(path) end) |> Enum.uniq() |> Enum.reject(&(&1 == "."))
    with {:ok, tar} <- open(),
      :ok <- Enum.each(dirs, &add_directory(tar, &1)),
      :ok <- Enum.each(files, fn {path, content} -> add_file(tar, path, content) end) do
      close(tar)
    end
  end

  defp read(file) do
    file
    |> do_read(0, [])
    |> Enum.reverse()
    |> IO.iodata_to_binary()
  end

  defp do_read(file, position, acc) do
    chunk_size = 1024

    case :file.pread(file, position, chunk_size) do
      {:ok, data} ->
        do_read(file, position + chunk_size, [data | acc])

      :eof ->
        acc
    end
  end

end
