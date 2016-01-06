defmodule TicTacToe.Board.InitialState do
  require Utils

  alias TicTacToe.Board.EndGame
  
  @dir             Utils.module_path
  @min_board_size  Utils.get_config(:min_board_size)
  @max_board_size  Utils.get_config(:max_board_size)
  @move_lists      Utils.get_config(:move_lists)
  @max_num_cells   @max_board_size * @max_board_size
  @timeout         1000
  @factorial_cache 1..@max_board_size
    |> Enum.scan(&(&1 * &2))
    |> Enum.reverse

  def get(size) do
    __MODULE__
    |> Module.safe_concat("BoardSize" <> Integer.to_string(size))
    |> apply(:get, [])
  end

  # def size_module, do: Module.concat(__MODULE__, "BoardSize" <> Integer.to_string(size))

  def build do
    @min_board_size..@max_board_size
    |> Enum.each(fn(board_size)->
      num_cells = board_size * board_size

      valid_moves =
        @move_lists
        |> Map.get_lazy(board_size, fn ->
          num_cells
          |> default_move_list
        end)

      row_chunks =
        valid_moves
        |> Enum.chunk(board_size)

      win_state =
        row_chunks
        |> win_lists

      # outcome_counts =
      #   valid_moves
      #   |> num_possible_outcomes_by_turn(win_state)

      {move_cells, move_map} =
        row_chunks
        |> printer_tup

      file_contents =
        [valid_moves: valid_moves,
         win_state:   win_state,
         # outcome_counts: outcome_counts,
         move_cells:  move_cells,
         move_map:    move_map]
         |> Enum.map(fn({name, contents})->
           contents
           |> inspect(pretty: true, as_lists: true) 
           |> Utils.wrap_pre(name)
         end)
         |> Keyword.update!(:win_state, &(&1 <> "\n|> Enum.map(&Enum.into(&1, HashSet.new))"))
         |> Enum.map_join("\n\n", fn({name, contents})->
           contents
           |> String.replace(~r/(?<=\n)/, "    ")
           |> Utils.cap("  defp #{name} do\n", "\n  end")
         end)
         |> Utils.str_pre("  def get do\n    {valid_moves, win_state, move_map, move_cells}\n  end")
         |> Utils.cap("defmodule #{__MODULE__}.BoardSize#{board_size} do\n", "\nend")

      file_name =
        board_size
        |> Integer.to_string
        |> Utils.cap("board_size_", ".ex")

      @dir
      |> Path.join(file_name)
      |> File.write(file_contents)
    end)
  end

  #external API ^

  def collector(root_pid) do
    countdown = fn ->
      @timeout
      |> :timer.send_after({:return, root_pid})
      |> elem(1)
    end

    Map.new
    |> collect(countdown.(), countdown)
  end

  def collect(results, tref, countdown) do
    receive do
      {:return, root_pid} ->
        root_pid
        |> send(results)

      {:record, turn} ->
        tref
        |> :timer.cancel

        results
        |> Map.update(turn, 1, &(&1 + 1))
        |> collect(countdown.(), countdown)
    end
  end

  def recurse(rem_moves, token, win_state, turn, collector_pid) do
    rem_moves
    |> Enum.reduce({[], tl(rem_moves)}, fn(move, {other_before, other_after})->
      move
      |> Board.next_win_state(token, win_state)
      |> case do
        end_game when is_integer(end_game) -> 
          collector_pid
          |> send({:record, turn})

        next_win_state ->
          __MODULE__
          |> spawn(:recurse, [other_before ++ other_after, not token, next_win_state, turn + 1, collector_pid])
      end

      {[move | other_before], tl(other_after)}
    end)
  end

  def num_possible_outcomes_by_turn(valid_moves, win_state) do
    collector_pid =
      __MODULE__
      |> spawn(:collector, [self])

    __MODULE__
    |> spawn(:recurse, [valid_moves, true, win_state, 1, collector_pid])


    receive do
      results -> 
        results
        |> Enum.sort(&>=/2)
        |> Enum.map(&elem(&1, 1))
      
      # after 5000 -> throw("taking too long")
    end
  end

  def printer_tup(row_chunks) do
    {rows, {move_map, _}} =
      row_chunks
      |> Enum.map_reduce({Map.new, 0}, fn(row_moves, {move_map, row_index})->
        row_key =
         "row_" 
          <> Integer.to_string(row_index)
          |> String.to_atom

        {cols, {move_map, _}} =
          row_moves
          |> Enum.map_reduce({move_map, 0}, fn(move, {move_map, col_index})->
            col_key =
             "col_" 
              <> Integer.to_string(col_index)
              |> String.to_atom

            move_map = 
              move_map
              |> Map.put(move, {row_key, col_key})

            {{col_key, move}, {move_map, col_index + 1}}
          end)

        {{row_key, cols}, {move_map, row_index + 1}}
      end)

    {rows, move_map}
  end

  # def win_sets(row_chunks) do
  #   rows =
  #     row_chunks
  #     |> Enum.map(&Enum.into(&1, HashSet.new))

  #   rows_cols =
  #     row_chunks
  #     |> List.zip
  #     |> Enum.reduce(rows, fn(chunk_tup, rows_cols)->
  #       chunk_tup 
  #       |> Tuple.to_list
  #       |> Enum.into(HashSet.new)
  #       |> Utils.push_in(rows_cols)
  #     end)

  #   row_chunks
  #   |> Enum.reduce([{HashSet.new, 0, 1}, {HashSet.new, -1, -1}], fn(chunk, diag_tups)->
  #     diag_tups
  #     |> Enum.map(fn({diag, at, inc})->
  #       diag
  #       |> Set.put(Enum.at(chunk, at)) 
  #       |> Utils.wrap_app(at + inc)
  #       |> Tuple.append(inc)
  #     end)
  #   end)
  #   |> Enum.reduce(rows_cols, &[elem(&1, 0) | &2])
  # end

  def win_lists(cell_chunk = [[_]]), do: cell_chunk
  def win_lists(row_chunks)          do
    ~w(rows_and_columns diagonals)a
    |> Enum.flat_map(fn(fun)->
      __MODULE__
      |> apply(fun, [row_chunks])
    end)
  end

  def rows_and_columns(row_chunks) do
    row_chunks
    |> List.zip
    |> Enum.reduce(row_chunks, &[Tuple.to_list(&1) | &2])
  end

  def diagonals(row_chunks) do
    row_chunks
    |> Enum.reduce([{[], 0, 1}, {[], -1, -1}], fn(chunk, diag_tups)->
      diag_tups
      |> Enum.map(fn({diag, n, inc})->
        chunk
        |> Enum.at(n)
        |> Utils.push_in(diag)
        |> Utils.wrap_app(n + inc)
        |> Tuple.append(inc)
      end)
    end)
    |> Enum.map(&elem(&1, 0))
  end

  defp default_move_list(num_cells) do
    0..(num_cells - 1)
    |> Enum.map(fn(int)->
      int
      |> inspect(base: :hex)
      |> String.slice(2..-1)
      |> String.downcase
    end)
  end

  def clean do
   @dir 
   |> Path.join("**")
   |> Path.wildcard
   |> Enum.each(&File.rm_rf!/1)
  end
end
