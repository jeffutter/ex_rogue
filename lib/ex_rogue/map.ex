defmodule ExRogue.Map do
  def build(options \\ []) do
    width = Keyword.get(options, :width, 10)
    height = Keyword.get(options, :height, 10)

    width
    |> new(height)
    |> place_rooms(options)
    |> fill_space()
  end

  def new(width, height) do
    for _ <- 0..width do
      for _ <- 0..height do
        :e
      end
    end
  end

  def place_rooms(map, options \\ []) do
    rooms = Keyword.get(options, :rooms, 4)

    Enum.reduce(1..rooms, map, fn _, map -> place_room(map, options) end)
  end

  def place_room(
        map,
        options \\ [],
        id \\ System.unique_integer([:positive, :monotonic]),
        attempts \\ 10
      ) do
    min_size = Keyword.get(options, :min_size, 4)
    max_size = Keyword.get(options, :max_size, 6)
    size = Enum.random(min_size..max_size)
    do_place_room(map, size, id, attempts)
  end

  def fill_space(map) do
    x_max = length(List.first(map)) - 1
    y_max = length(map) - 1

    for x <- 0..x_max do
      for y <- 0..y_max do
        map
        |> get(x, y)
        |> case do
          :e -> :e
          v -> v
        end
      end
    end
  end

  defp do_place_room(map, _size, _, 0), do: map

  defp do_place_room(map, size, id, attempts) do
    width = Enum.random(1..floor(size / 2))
    height = floor(size / width)

    x_max = length(List.first(map)) - width
    y_max = length(map) - height

    left = Enum.random(0..x_max)
    right = left + width - 1
    top = Enum.random(0..y_max)
    bottom = top + height - 1

    left..right
    |> Enum.reduce_while({:ok, map}, fn x, {:ok, map} ->
      top..bottom
      |> Enum.reduce_while({:ok, map}, fn y, {:ok, map} ->
        {old_val, map} = get_and_update(map, x, y, {:r, id})

        case old_val do
          {:r, _} -> {:halt, :collision}
          _ -> {:cont, {:ok, map}}
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

  defp get(map, x, y) do
    get_in(map, [Access.at(y), Access.at(x)])
  end

  defp get_and_update(map, x, y, value) do
    get_and_update_in(map, [Access.at(y), Access.at(x)], &{&1, value})
  end
end
