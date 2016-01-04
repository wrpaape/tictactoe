defmodule TicTacToe.CLI do
  alias TicTacToe.Board
  alias TicTacToe.Computer
  alias TicTacToe.Player
  
  require Misc

  @colors     Misc.get_config(:colors)
  @min        Misc.get_config(:min_board_size)
  @max        Misc.get_config(:max_board_size)
  @def        Misc.get_config(:def_board_size)
  @move_sets  Misc.get_config(:move_sets)
  @colors     Misc.get_config(:colors)
  @cursor     Misc.cap_reset("\n > ", :blink_slow)

  @coin_flip_prompt "heads or tails (h/t)?" <> @cursor
  @selection_prompt "choose a valid token character:\n(printable, not whitespace, and not present in the moveset below)\n"

  @parse_opts [
    switches: [help: :boolean],
    aliases:  [h:    :help]
  ]

  def main(argv) do
    argv
    |> parse_args
    |> process
  end

  #external API ^

  def process({board_size, __}) when board_size in @min..@max, do: process(board_size)
  def process({_board_size, _}), do: alert("board size must be >= #{@min} and <= #{@max}")
  def process(:error),           do: alert("failed to parse integer from board size")
  def process(:help),            do: alert("usage: tic_tac_toe (<board size>)", :blue)
  def process(board_size)        do
    board_size
    |> Board.start_link
    
    {wrap_dir, turn_str} =
      @coin_flip_prompt
      |> IO.getn
      |> String.match?(coin_flip_reg)
      |> if do: {:app, "first"}, else: {:pre, "second"}

    {valids, move_set_str} =
      @move_sets
      |> Map.get(board_size)

    token_prompt =
      move_set_str
      |> Misc.cap(@selection_prompt, @cursor)

    turn_str
    |> Misc.cap("\nyou will have the ", " move.\n")
    |> IO.puts

    token_prompt
    |> assign_tokens(wrap_dir, valids)
    |> TicTacToe.start
  end

  def parse_args(argv) do
    argv
    |> OptionParser.parse(@parse_opts)
    |> case do
      {[help: true], _, _ }  -> :help
       
      {_, [], _}             -> @def
 
      {_, [size_str | _], _} -> Integer.parse(size_str)
    end
  end

  #helpers v 

  defp coin_flip_reg do
    ~w(h t)
    |> Enum.random
    |> Misc.str_pre("^")
    |> Regex.compile!("i")
  end

  def assign_tokens(prompt, wrap_dir, valids) do
    char =
      prompt
      |> IO.getn

    valids
    |> Set.member?(char)
    |> if do
      [player_color, computer_color] =
        @colors
        |> Enum.take_random(2)

      valids
      |> Set.delete(char)
      |> Enum.random
      |> Misc.wrap_pre(computer_color)
      |> Misc.wrap_pre(Computer)
      |> Misc.wrap({Player, {player_color, char}}, wrap_dir)
    else
      "invalid token"
      |> Misc.cap_reset(:red)
      |> IO.puts

      prompt
      |> assign_tokens(wrap_dir, valids)
    end
  end

  defp alert(msg, color \\ :red) do
    msg   
    |> Misc.cap_reset(color)
    |> IO.puts

    System.halt(0)
  end
end
