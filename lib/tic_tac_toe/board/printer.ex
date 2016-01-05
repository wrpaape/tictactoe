defmodule TicTacToe.Board.Printer do
  use GenServer

  require Misc

  alias IO.ANSI

  # ┌──┬──┐   ┏━━┳━━┓   ╔══╦══╗ 
  # │  │  │   ┃  ┃  ┃   ║  ║  ║ 
  # ├──┼──┤   ┣━━╋━━┫   ╠══╬══╣ 
  # │  │  │   ┃  ┃  ┃   ║  ║  ║ 
  # └──┴──┘   ┗━━┻━━┛   ╚══╩══╝ 

  @token_space_ratio 8
  @board_fg          ANSI.normal <> ANSI.white_background <> ANSI.black
  @board_bg          ANSI.black_background
  @cell_join         @board_fg <> "║"

  def start_link(board_tup), do: GenServer.start_link(__MODULE__, board_tup, name: __MODULE__)
  
  def state, do: GenServer.call(__MODULE__, :state)

  def update(move, token), do: GenServer.cast(__MODULE__, {:update, move, token})

  def print,               do: GenServer.cast(__MODULE__, :print)

  # external API ^

  def init({move_map, move_cells, board_size}) do
    key_dims =
      {_board_res, cols} =
        fetch_key_dims!

    cell_pad =
      {cell_res, _outer_pad_len} =
        board_size
        |> cell_res_and_outer_pad_len(key_dims)

    {lines, row_caps} =
      board_size
      |> build_static_pieces(cell_pad)
 
    cell_builder =
      board_size
      |> build_cell_builder_fun(cell_res)

    board = 
      move_cells
      |> build_board(cell_builder, row_caps)

    {:ok, {{board, lines}, board_size, move_map, board_res, cols, row_caps, cell_builder}}
  end

  def handle_call(:state, _from, state), do: {:reply, state, state}

  def handle_cast(:print, state) do
    state
    |> elem(0)
    |> print

    {:noreply, state}
  end

  def handle_cast({:update, move, token}, {{board, lines}, b_size, moves, b_res, cols, caps, c_fun}) do
    next_board = 
      fetch_key_dims!
      |> case do
        # {^b_res, ^cols} ->
          _ ->
            board
            |> update_board(moves[move], c_fun.(token), caps)

        # {b_res, ^cols} ->


        # {^b_res, cols} ->


        # {b_res, cols} ->

      end

    {:noreply, {{next_board, lines}, b_size, moves, b_res, cols, caps, c_fun}}
  end

  # helpers v

  defp print({board, {mid, top_bot}}) do
    board
    |> Enum.map_join(mid, fn({_, {_, row}})->
      row
    end)
    |> Misc.cap(top_bot)
    |> IO.write
  end

  defp update_board(board, {row, col}, cell, caps) do
    board
    |> Keyword.update!(row, &update_row(&1, col, cell, caps))
  end

  defp update_row({cells, _row}, col, cell, caps) do
    {next_cells, next_cell_vals} =
      cells
      |> update_and_unzip(col, cell, Keyword.new, [])

    {next_cells, print_row(next_cell_vals, caps, "")}
  end

  defp update_and_unzip([{col, _} | rem_cells], col, cell, acc_cells, acc_vals) do
    rem_vals =
      rem_cells
      |> Keyword.values

    [{col, cell} | acc_cells]
    |> Enum.reverse(rem_cells)
    |> Misc.wrap_app(Enum.reverse([cell | acc_vals], rem_vals))
  end

  defp update_and_unzip([tup = {_, val} | rem_cells], col, cell, acc_cells, acc_vals) do
    rem_cells
    |> update_and_unzip(col, cell, [tup | acc_cells], [val | acc_vals])
  end

  defp build_board(move_cells, cell_builder, row_caps) do
    move_cells
    |> Enum.map(fn({row_key, row}) ->
      {cells, cell_vals} =
        fn({col_key, cell_move}, acc_cells)->
          cell = cell_builder.({ANSI.faint, cell_move})

          {{col_key, cell}, [cell | acc_cells]}
        end
        |> :lists.mapfoldr([], row)
      
      {row_key, {cells, print_row(cell_vals, row_caps, "")}}
    end)
  end

  defp print_row([[] | _], _, acc_row),               do: acc_row
  defp print_row(cells, caps = {lcap, rcap}, acc_row) do
    {next_cells, cell_row} =
      cells
      |> Enum.map_reduce(lcap, fn([next_cell_row | rem_cell_rows], acc_cell_row)->
       {rem_cell_rows, acc_cell_row <> next_cell_row <> @cell_join}
      end)

    next_cells
    |> print_row(caps, acc_row <> cell_row <> rcap)
  end

  defp fetch_key_dims! do
    {rows, cols} = Misc.fetch_dims!

    {min(rows, cols), cols}
  end

  defp cell_res_and_outer_pad_len(board_size, {board_res, cols}) do
    cell_res =
      board_res
      |> - (board_size + 1)
      |> div(board_size)

    {cell_res, cols - (cell_res + 1) * board_size - 1}
  end

  defp build_cell_builder_fun(board_size, cell_res) do
    cell_pad_len = 
      cell_res
      |> div(@token_space_ratio)

    token_space = cell_res - cell_pad_len * 2

    lr_pad =
      cell_pad_len
      |> Misc.pad

    tb_pad =
      cell_res
      |> Misc.pad
      |> List.duplicate(cell_pad_len)

    fn({color, char})->
      char
      |> String.duplicate(token_space)
      |> Misc.cap(color, @board_fg)
      |> List.duplicate(token_space)
      |> Enum.map(&Misc.cap(&1, lr_pad))
      |> Misc.cap_list(tb_pad)
    end
  end

  defp build_pads_tup(pad_len), do: Misc.ljust_pads(pad_len)

  defp build_lines(horiz_lines, pads_tup) do
    [top, mid, bot] =
      [{"╦", {"╔", "╗"}}, {"╬", {"╠", "╣"}}, {"╩", {"╚", "╝"}}]
      |> Enum.map(fn({join, caps})->
        horiz_lines
        |> Enum.join(join)
        |> Misc.cap(caps)
        |> Misc.cap(@board_fg, @board_bg)
        |> Misc.cap(pads_tup)
      end)

    {mid, {top, bot}}
  end

  defp build_static_pieces(board_size, {cell_res, pad_len}) do
    pads_tup =
      {lpad, rpad} =
        pad_len
        |> build_pads_tup
    
    "═"
    |> String.duplicate(cell_res)
    |> List.duplicate(board_size)
    |> build_lines(pads_tup)
    |> Misc.wrap_app({lpad <> @cell_join , @board_bg <> rpad})
  end
  # ┌──┬──┐   ┏━━┳━━┓   ╔══╦══╗ 
  # │  │  │   ┃  ┃  ┃   ║  ║  ║ 
  # ├──┼──┤   ┣━━╋━━┫   ╠══╬══╣ 
  # │  │  │   ┃  ┃  ┃   ║  ║  ║ 
  # └──┴──┘   ┗━━┻━━┛   ╚══╩══╝ 

  # defp allocate_dims(cols, board_size) do
  #   &div(&1 -  1, board_size)
  #   next_board =
  #     board
  #     |> List.update_at(row_fun.(next_move), fn(row)->
  #       row
  #       |> List.keyreplace_at(next_move, 0, {next_move, token})
  #     end)
    
  # end
end
