defmodule ExRogue.Map do
  defstruct width: 0, height: 0, map: []

  @type t :: %__MODULE__{width: integer, height: integer, map: list(list(any))}

  defmodule Tile.Wall do
    defstruct id: 0, position: {0, 0}
    @type t :: %__MODULE__{id: integer, position: {integer, integer}}
  end

  defmodule Tile.Room do
    defstruct id: 0, position: {0, 0}
    @type t :: %__MODULE__{id: integer, position: {integer, integer}}
  end

  alias Tile.{Room, Wall}

  def build(options \\ []) do
    width = Keyword.get(options, :width, 50)
    height = Keyword.get(options, :height, 30)

    width
    |> new(height)
    |> place_rooms(options)
    |> fill_space()
  end

  def new(width, height) do
    map =
      for _ <- 0..height do
        for _ <- 0..width do
          nil
        end
      end

    %__MODULE__{width: width, height: height, map: map}
  end

  def place_rooms(%__MODULE__{} = map, options \\ []) do
    rooms = Keyword.get(options, :rooms, 4)

    Enum.reduce(1..rooms, map, fn _, map -> place_room(map, options) end)
  end

  def place_room(
        %__MODULE__{} = map,
        options \\ [],
        id \\ System.unique_integer([:positive, :monotonic]),
        attempts \\ 10
      ) do
    min_size = Keyword.get(options, :min_size, 8)
    max_size = Keyword.get(options, :max_size, 60)
    size = Enum.random(min_size..max_size)
    do_place_room(map, size, id, attempts)
  end

  def fill_space(%__MODULE__{width: width, height: height} = map) do
    x_max = width - 1
    y_max = height - 1

    data =
      for y <- 0..y_max do
        for x <- 0..x_max do
          map
          |> get({x, y})
          |> case do
            nil -> nil
            v -> v
          end
        end
      end

    %__MODULE__{map | map: data}
  end

  defp do_place_room(%__MODULE__{} = map, _size, _, 0), do: map

  defp do_place_room(%__MODULE__{width: map_width, height: map_height} = map, size, id, attempts) do
    IO.inspect(size, label: "Size")
    IO.inspect(attempts, label: "Attempts")
    # +2 for walls
    width = Enum.random(1..floor(size / 2)) + 2
    # +2 for walls
    height = floor(size / width) + 2

    x_max = map_width - width
    y_max = map_height - height

    left = Enum.random(0..x_max)
    right = left + width - 1
    top = Enum.random(0..y_max)
    bottom = top + height - 1

    IO.inspect({width, height}, label: "WH")
    IO.inspect({left, right, top, bottom}, label: "Cords")

    left..right
    |> Enum.reduce_while({:ok, map}, fn x, {:ok, map} ->
      top..bottom
      |> Enum.reduce_while({:ok, map}, fn y, {:ok, map} ->
        tile =
          case {x, y} do
            {x, _} when x == left ->
              %Wall{id: id, position: {x, y}}

            {x, _} when x == right ->
              %Wall{id: id, position: {x, y}}

            {_, y} when y == top ->
              %Wall{id: id, position: {x, y}}

            {_, y} when y == bottom ->
              %Wall{id: id, position: {x, y}}

            _ ->
              %Room{id: id, position: {x, y}}
          end

        {old_val, map} = get_and_update(map, {x, y}, tile)

        case {old_val, tile} do
          {nil, _} -> {:cont, {:ok, map}}
          {%Wall{}, %Wall{}} -> {:cont, {:ok, map}}
          _ -> {:halt, :collision}
        end
      end)
      |> case do
        {:ok, map} -> {:cont, {:ok, map}}
        :collision -> {:halt, :collision}
      end
    end)
    |> case do
      {:ok, map} -> map
      :collision -> do_place_room(map, size, id, attempts - 1)
    end
  end

  defp get(%__MODULE__{map: map}, {x, y}) do
    get_in(map, [Access.at(y), Access.at(x)])
  end

  defp get_and_update(%__MODULE__{map: data} = map, {x, y}, value) do
    {old_val, data} = get_and_update_in(data, [Access.at(y), Access.at(x)], &{&1, value})
    {old_val, %__MODULE__{map | map: data}}
  end
end

defimpl Inspect, for: ExRogue.Map do
  import Inspect.Algebra
  alias ExRogue.Map
  alias ExRogue.Map.Tile.{Room, Wall}

  def inspect(%Map{width: width, map: map}, _opts) do
    data =
      [
        String.duplicate("_", width + 2),
        for row <- map do
          col_string =
            for col <- row, into: "" do
              case col do
                nil -> " "
                %Room{} -> "R"
                %Wall{} -> "W"
              end
            end

          Enum.join(["|", col_string, "|"])
        end,
        String.duplicate("_", width + 2)
      ]
      |> List.flatten()

    data
    |> Enum.intersperse(break("\n"))
    |> concat()
  end
end
