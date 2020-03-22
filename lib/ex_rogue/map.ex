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

  defmodule Tile.Hall do
    defstruct id: 0, position: {0, 0}
    @type t :: %__MODULE__{id: integer, position: {integer, integer}}
  end

  alias Tile.{Hall, Room, Wall}

  def build(options \\ []) do
    width = Keyword.get(options, :width, 50)
    height = Keyword.get(options, :height, 30)

    width
    |> new(height)
    |> place_rooms(options)
    |> carve_halls()
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

  defp carve_halls(%__MODULE__{} = map) do
    case find_empty(map) do
      nil ->
        map

      {_, _} = point ->
        points = trace_hall(map, point)
        id = System.unique_integer([:positive, :monotonic])

        with {:ok, map} <- carve_points(map, points, Hall, id) do
          map
          |> place_walls(points, 0)
          |> carve_halls()
        end
    end
  end

  def trace_hall(map, start_point) do
    trace_hall(map, [start_point], [start_point])
  end

  def trace_hall(_map, [], traced_points) do
    Enum.reverse(traced_points)
  end

  def trace_hall(%__MODULE__{width: width, height: height} = map, available_points, traced_points) do
    point = Enum.random(available_points)

    possible_points =
      point
      |> surrounding_points({width, height})
      |> Enum.shuffle()

    case Enum.find(possible_points, &can_trace_point?(map, traced_points, &1)) do
      {_, _} = new_point ->
        trace_hall(map, [new_point | available_points], [new_point | traced_points])

      nil ->
        trace_hall(map, List.delete(available_points, point), traced_points)
    end
  end

  defp can_trace_point?(map, [], point) do
    is_nil(get(map, point))
  end

  defp can_trace_point?(
         %__MODULE__{width: width, height: height} = map,
         [last_point | _] = traced_points,
         point
       ) do
    empty_tile = is_nil(get(map, point))
    in_traced = point in traced_points
    surrounding_points = surrounding_points(point, {width, height}) -- [last_point]
    any_surrounding_traced = Enum.any?(surrounding_points, &(&1 in traced_points))

    empty_tile and !in_traced and !any_surrounding_traced
  end

  def surrounding_points({x, y}, {max_x, max_y}) do
    points = [
      {x, y - 1},
      {x - 1, y},
      {x + 1, y},
      {x, y + 1}
    ]

    for {nx, ny} <- points,
        nx != 0,
        ny != 0,
        nx != max_x,
        ny != max_y do
      {nx, ny}
    end
  end

  def find_empty(%__MODULE__{width: width, height: height, map: data}) do
    data
    |> Enum.with_index()
    |> Enum.find_value(fn {row, ridx} ->
      cidx =
        row
        |> Enum.with_index()
        |> Enum.find_value(fn {x, cidx} ->
          case {x, cidx} do
            {_, 0} -> false
            {_, ^width} -> false
            {nil, _} -> cidx
            _ -> false
          end
        end)

      case {cidx, ridx} do
        {_, 0} -> false
        {_, ^height} -> false
        {nil, _} -> false
        {cidx, _} -> {cidx, ridx}
      end
    end)
  end

  defp do_place_room(%__MODULE__{} = map, _size, _, 0), do: map

  defp do_place_room(%__MODULE__{width: map_width, height: map_height} = map, size, id, attempts) do
    IO.inspect(size, label: "Size")
    IO.inspect(attempts, label: "Attempts")
    # +2 for walls
    width = Enum.random(1..floor(size / 2)) + 2
    # +2 for walls
    height = floor(size / width) + 2

    x_max = map_width - width - 1
    y_max = map_height - height - 1

    left = Enum.random(1..x_max)
    right = left + width - 1
    top = Enum.random(1..y_max)
    bottom = top + height - 1

    IO.inspect({width, height}, label: "WH")
    IO.inspect({left, right, top, bottom}, label: "Cords")

    map
    |> carve({left, top}, {right, bottom}, Room, id)
    |> case do
      {:ok, map} -> map
      {:error, :collision} -> do_place_room(map, size, id, attempts - 1)
    end
  end

  defp square_points({tx, ty}, {bx, by}) do
    for x <- tx..bx, y <- ty..by do
      {x, y}
    end
  end

  defp carve(%__MODULE__{} = map, top_left, bottom_right, type, id) do
    points = square_points(top_left, bottom_right)

    with {:ok, map} <- carve_points(map, points, type, id) do
      map = place_walls(map, points, id)
      {:ok, map}
    end
  end

  defp carve_points(%__MODULE__{} = map, points, type, id) do
    case Enum.any?(points, fn point -> !is_nil(get(map, point)) end) do
      true ->
        {:error, :collision}

      false ->
        map =
          Enum.reduce(points, map, fn point, map ->
            update(map, point, struct(type, %{id: id, position: point}))
          end)

        {:ok, map}
    end
  end

  def place_walls(%__MODULE__{width: width, height: height} = map, points, id) do
    points
    |> Enum.flat_map(&adjacent_points(&1, {width, height}))
    |> Enum.uniq()
    |> Enum.filter(fn point ->
      is_nil(get(map, point))
    end)
    |> Enum.reduce(map, fn point, map ->
      update(map, point, %Wall{id: id, position: point})
    end)
  end

  defp adjacent_points({x, y}, {max_x, max_y}) do
    for nx <- (x - 1)..(x + 1),
        ny <- (y - 1)..(y + 1),
        nx != 0,
        ny != 0,
        {nx, ny} != {x, y},
        nx != max_x,
        ny != max_y do
      {nx, ny}
    end
  end

  def map_region(%__MODULE__{} = map, {tx, ty}, {bx, by}, fun) do
    tx..bx
    |> Enum.reduce_while({:ok, map}, fn x, {:ok, map} ->
      ty..by
      |> Enum.reduce_while({:ok, map}, fn y, {:ok, map} ->
        value = get(map, {x, y})

        fun.({x, y}, value)
        |> case do
          {:ok, value} ->
            {:cont, {:ok, update(map, {x, y}, value)}}

          {:error, reason} ->
            {:halt, {:error, reason}}
        end
      end)
      |> case do
        {:ok, map} -> {:cont, {:ok, map}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp get(%__MODULE__{map: map}, {x, y}) do
    get_in(map, [Access.at(y), Access.at(x)])
  end

  defp update(%__MODULE__{map: data} = map, {x, y}, value) do
    data = put_in(data, [Access.at(y), Access.at(x)], value)
    %__MODULE__{map | map: data}
  end

  defp get_and_update(%__MODULE__{map: data} = map, {x, y}, value) do
    {old_val, data} = get_and_update_in(data, [Access.at(y), Access.at(x)], &{&1, value})
    {old_val, %__MODULE__{map | map: data}}
  end
end

defimpl Inspect, for: ExRogue.Map do
  import Inspect.Algebra
  alias ExRogue.Map
  alias ExRogue.Map.Tile.{Hall, Room, Wall}

  def inspect(%Map{width: width, map: map}, _opts) do
    data =
      [
        String.duplicate("_", width + 2),
        for row <- map do
          col_string =
            for col <- row, into: "" do
              case col do
                nil -> " "
                %Room{} -> "."
                %Wall{} -> "#"
                %Hall{} -> "*"
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
