defmodule ExRogue.Map do
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

  defmodule Tile.Door do
    defstruct id: 0, position: {0, 0}
    @type t :: %__MODULE__{id: integer, position: {integer, integer}}
  end

  alias Tile.{Door, Hall, Room, Wall}

  defstruct map: [], top_left: {0, 0}, bottom_right: {0, 0}

  @type point :: {non_neg_integer, non_neg_integer}

  @type t :: %__MODULE__{
          map: list(list(any)),
          top_left: point,
          bottom_right: point
        }

  @type iterate_mapper :: (t, point -> :ok | {:ok, t} | {:error, atom})

  @type tile :: Door.t() | Hall.t() | Room.t() | Wall.t()

  # Public Functions
  @spec build(keyword) :: {:ok, t()} | {:error, atom}
  def build(options \\ []) do
    width = Keyword.get(options, :width, 50)
    height = Keyword.get(options, :height, 30)

    width
    |> new(height)
    |> place_rooms(options)
    |> carve_halls()
    |> carve_doors()
    |> remove_dead_ends()
  end

  @spec new(integer, integer) :: t()
  def new(width, height) do
    map =
      for _ <- 0..(height - 1) do
        for _ <- 0..(width - 1) do
          nil
        end
      end

    %__MODULE__{map: map, top_left: {0, 0}, bottom_right: {width - 1, height - 1}}
  end

  # Public Functions

  @spec place_rooms(t(), keyword) :: t()
  def place_rooms(%__MODULE__{} = map, options \\ []) do
    rooms = Keyword.get(options, :rooms, 4)

    Enum.reduce(1..rooms, map, fn _, map -> place_room(map, options) end)
  end

  @spec place_room(t(), keyword, integer, integer) :: t()
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

  @spec carve_doors(t()) :: t()
  def carve_doors(%__MODULE__{map: data} = map) do
    data
    |> List.flatten()
    |> Enum.flat_map(fn tile ->
      case tile do
        %Wall{position: position} ->
          surrounding_points = surrounding_points(position, map)

          for {a, b} <- combinations(surrounding_points),
              %mod_a{id: a_id} = get(map, a),
              %mod_b{id: b_id} = get(map, b),
              a_id != b_id,
              mod_a != Wall,
              mod_b != Wall,
              !(mod_a == Hall and mod_b == Hall) do
            {position, Enum.sort([{mod_a, a_id}, {mod_b, b_id}])}
          end

        _ ->
          []
      end
    end)
    |> Enum.group_by(fn {_v, k} -> k end, fn {v, _k} -> v end)
    |> Enum.map(fn {_k, v} -> Enum.random(v) end)
    |> Enum.reduce(map, fn point, map ->
      id = System.unique_integer([:positive, :monotonic])
      update(map, point, %Door{id: id, position: point})
    end)
  end

  @spec remove_dead_ends(t()) :: {:ok, t()} | {:error, atom}
  def remove_dead_ends(%__MODULE__{top_left: top_left, bottom_right: bottom_right} = map) do
    top_left
    |> points_for_region(bottom_right)
    |> Enum.reduce(map, fn point, map ->
      case is_dead_end?(map, point) do
        true ->
          remove_dead_end(map, point)

        false ->
          map
      end
    end)
  end

  @spec remove_dead_end(t(), point) :: t()
  def remove_dead_end(%__MODULE__{} = map, point) do
    map = update(map, point, %Wall{id: 0, position: point})

    next =
      point
      |> surrounding_points(map)
      |> Enum.find(fn point ->
        tile = get(map, point)

        case tile do
          %Hall{} -> true
          %Door{} -> true
          _ -> false
        end
      end)

    case next do
      nil ->
        map

      next ->
        case is_dead_end?(map, next) do
          true ->
            remove_dead_end(map, next)

          false ->
            map
        end
    end
  end

  @spec place_walls(t(), list(point), integer) :: t()
  def place_walls(%__MODULE__{} = map, points, id) do
    points
    |> Enum.flat_map(&adjacent_points(&1, map))
    |> Enum.uniq()
    |> Enum.filter(fn point ->
      is_nil(get(map, point))
    end)
    |> Enum.reduce(map, fn point, map ->
      update(map, point, %Wall{id: id, position: point})
    end)
  end

  # Private Functions

  defp adjacent_points({x, y}, %__MODULE__{bottom_right: {max_x, max_y}}) do
    for nx <- (x - 1)..(x + 1),
        ny <- (y - 1)..(y + 1),
        nx >= 0,
        ny >= 0,
        {nx, ny} != {x, y},
        nx <= max_x,
        ny <= max_y do
      {nx, ny}
    end
  end

  @spec can_trace_point?(t(), list(point), point) :: boolean
  defp can_trace_point?(
         %__MODULE__{top_left: {min_x, min_y}, bottom_right: {max_x, max_y}},
         _,
         {x, y}
       )
       when x == max_x or y == max_y or x == min_x or y == min_y do
    false
  end

  @dialyzer [{:nowarn_function, can_trace_point?: 3}, :no_match]

  defp can_trace_point?(%__MODULE__{} = map, [], point) do
    is_nil(get(map, point))
  end

  defp can_trace_point?(
         %__MODULE__{} = map,
         [last_point | _] = traced_points,
         point
       ) do
    empty_tile = is_nil(get(map, point))
    in_traced = point in traced_points
    surrounding_points = surrounding_points(point, map) -- [last_point]
    any_surrounding_traced = Enum.any?(surrounding_points, &(&1 in traced_points))

    empty_tile and !in_traced and !any_surrounding_traced
  end

  @spec carve(t(), point, point, atom, integer) :: {:ok, t()} | {:error, atom}
  defp carve(%__MODULE__{} = map, top_left, bottom_right, type, id) do
    points = points_for_region(top_left, bottom_right)

    with {:ok, map} <- carve_points(map, points, type, id) do
      map = place_walls(map, points, id)
      {:ok, map}
    end
  end

  @spec carve_points(t(), list(point), atom, integer) :: {:ok, t()} | {:error, atom}
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

  @spec combinations(list()) :: list({any, any})
  defp combinations([]), do: []

  defp combinations([head | tail]) do
    for i <- tail do
      {head, i}
    end ++ combinations(tail)
  end

  @spec do_place_room(t(), non_neg_integer, non_neg_integer, non_neg_integer) :: t
  defp do_place_room(%__MODULE__{} = map, _size, _, 0), do: map

  defp do_place_room(%__MODULE__{bottom_right: {max_x, max_y}} = map, size, id, attempts) do
    width = Enum.random(2..floor(size / 2))
    height = floor(size / width)

    x_max = max_x - width - 1
    y_max = max_y - height - 1

    left = Enum.random(1..x_max)
    right = left + width - 1
    top = Enum.random(1..y_max)
    bottom = top + height - 1

    map
    |> carve({left, top}, {right, bottom}, Room, id)
    |> case do
      {:ok, map} -> map
      {:error, :collision} -> do_place_room(map, size, id, attempts - 1)
    end
  end

  @spec find_empty(t()) :: point | nil
  defp find_empty(%__MODULE__{top_left: top_left, bottom_right: bottom_right} = map) do
    top_left
    |> points_for_region(bottom_right)
    |> Enum.find(fn point ->
      is_nil(get(map, point))
    end)
  end

  @spec get(t(), point) :: tile
  defp get(%__MODULE__{map: map}, {x, y}) do
    get_in(map, [Access.at(y), Access.at(x)])
  end

  @spec is_dead_end?(t, point) :: boolean
  defp is_dead_end?(%__MODULE__{} = map, point) do
    case get(map, point) do
      %str{} when str == Hall or str == Door ->
        surrounding_points = surrounding_points(point, map)

        walls =
          surrounding_points
          |> Enum.filter(fn point ->
            tile = get(map, point)

            case tile do
              %Wall{} -> true
              nil -> true
              _ -> false
            end
          end)

        case length(surrounding_points) - length(walls) do
          0 -> true
          1 -> true
          _ -> false
        end

      _ ->
        false
    end
  end

  @spec points_for_region(point, point) :: list(point)
  defp points_for_region({tx, ty}, {bx, by}) do
    for x <- tx..bx, y <- ty..by do
      {x, y}
    end
  end

  @spec surrounding_points(point, t()) :: list(point)
  defp surrounding_points({x, y}, %__MODULE__{bottom_right: {max_x, max_y}}) do
    points = [
      {x, y - 1},
      {x - 1, y},
      {x + 1, y},
      {x, y + 1}
    ]

    for {nx, ny} <- points,
        nx >= 0,
        ny >= 0,
        nx <= max_x,
        ny <= max_y do
      {nx, ny}
    end
  end

  @spec trace_hall(t(), point) :: list(point)
  defp trace_hall(%__MODULE__{} = map, start_point) do
    trace_hall(map, [start_point], [start_point])
  end

  @spec trace_hall(t(), list(point), list(point)) :: list(point)
  defp trace_hall(%__MODULE__{}, [], traced_points) do
    Enum.reverse(traced_points)
  end

  defp trace_hall(%__MODULE__{} = map, available_points, traced_points) do
    point = Enum.random(available_points)

    possible_points =
      point
      |> surrounding_points(map)
      |> Enum.shuffle()

    case Enum.find(possible_points, &can_trace_point?(map, traced_points, &1)) do
      {_, _} = new_point ->
        trace_hall(map, [new_point | available_points], [new_point | traced_points])

      nil ->
        trace_hall(map, List.delete(available_points, point), traced_points)
    end
  end

  @spec update(t(), point, any) :: t()
  defp update(%__MODULE__{map: data} = map, {x, y}, value) do
    data = put_in(data, [Access.at(y), Access.at(x)], value)
    %__MODULE__{map | map: data}
  end
end

defimpl Inspect, for: ExRogue.Map do
  import Inspect.Algebra
  alias ExRogue.Map
  alias ExRogue.Map.Tile.{Door, Hall, Room, Wall}

  def inspect(%Map{map: map, bottom_right: {max_x, _}}, _opts) do
    data =
      [
        String.duplicate("_", max_x + 2),
        for row <- map do
          col_string =
            for col <- row, into: "" do
              case col do
                nil -> " "
                %Room{} -> "."
                %Wall{} -> "#"
                %Hall{} -> "."
                %Door{} -> "D"
              end
            end

          Enum.join(["|", col_string, "|"])
        end,
        String.duplicate("_", max_x + 2)
      ]
      |> List.flatten()

    data
    |> Enum.intersperse(break("\n"))
    |> concat()
  end
end
