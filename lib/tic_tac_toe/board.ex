defmodule TicTacToe.Board do
  use GenServer
  
  alias TicTacToe.Board.Computer
  alias TicTacToe.Board.Printer
  alias TicTacToe.Board.StateMapBuilder

  @state_map StateMapBuilder.build

  def start_link(board_size), do: GenServer.start_link(__MODULE__, board_size, name: __MODULE__)

  def state,                  do: GenServer.call(__MODULE__, :state)

  def next_move(player_tup),  do: GenServer.call(__MODULE__, {:next_move, player_tup}, :infinity)

  def next_win_state(move, token, win_state), do: next_info(move, token, win_state, [])

  # external API ^
  
  def init(board_size) do
    {valid_moves, win_state, outcome_counts, move_map, move_cells} =
      @state_map
      |> Map.get(board_size)

    {move_map, move_cells, board_size}
    |> Printer.start_link

    {:ok, {valid_moves, win_state}}
  end

  def handle_call(:state, _from, state), do: {:reply, state, state}

  def handle_call({:next_move, {player, token = {_, char}}}, _from, state = {valid_moves, win_state}) do
    next_move =
      player
      |> apply_next_move(Printer.print, valid_moves, win_state)

    next_move
    |> Printer.update(token)

    next_move
    |> next_win_state(char, win_state)
    |> case do
      # {:game_over, go_msg} ->
        # Printer.print
        # |> IO.write
# {:game_over, var!(char) <> " W I N S !"}
# {:game_over, "C A T ' S   G A M E"}
        # {:stop, :normal, go_msg, state}

      next_win_state -> 
        {:reply, :cont, {List.delete(valid_moves, next_move), next_win_state}}
    end
  end

  # helpers v

  defmacrop recurse(next_acc_state) do
    quote do
      next_info(var!(move), var!(char), var!(rem_state), unquote(next_acc_state))
    end
  end

  defmacrop push_next(next_info) do
    quote do: recurse([unquote(next_info) | var!(acc_state)])
  end

  defmacrop reduce_owned_or_unclaimed_info_and_recurse do
    quote do
      var!(win_set)
      |> Set.delete(var!(move))
      |> case do
        %HashSet{size: ^var!(size)} -> push_next(var!(info))
        # %HashSet{size: 0}           -> {:game_over, var!(char) <> " W I N S !"}
        %HashSet{size: 0}           -> 1
        next_win_set                -> push_next({next_win_set, var!(char)})
      end
    end
  end

  def next_info(move, char, [info = win_set = %HashSet{size: size} | rem_state], acc_state) do
    reduce_owned_or_unclaimed_info_and_recurse
  end

  def next_info(move, char, [info = {win_set = %HashSet{size: size}, char} | rem_state], acc_state) do
    reduce_owned_or_unclaimed_info_and_recurse
  end

  def next_info(move, char, [occ_info | rem_state], acc_state) do
    occ_info
    |> elem(0)
    |> Set.member?(move)
    |> if do: recurse(acc_state), else: push_next(occ_info)
  end

  # def next_info(_move, _token, [], []),             do: {:game_over, "C A T ' S   G A M E"}
  def next_info(_move, _token, [], []),             do: 0
  def next_info(_move, _token, [], next_win_state), do: next_win_state


  defp apply_next_move(Computer, board, valid_moves, win_state) do
    {board, valid_moves, win_state}
    |> Computer.next_move
  end

  defp apply_next_move(Player, board, valid_moves, _) do
    board
    |> Player.next_move(valid_moves)
  end
end

