defmodule TicTacToe.CLI do
  alias IO.ANSI
  alias TicTacToe.Helper
  alias TicTacToe.Board
  
  @valid_sizes  1..4
  @default_size 3
  @parse_opts   [
    switches: [help: :boolean],
    aliases:  [h:    :help]
  ]

  def main(argv) do
    argv
    |> parse_args
    |> process
  end

  #external API ^

  def process({board_size, _}) when board_size in @valid_sizes, do: process(board_size)
  def process({board_size, _}), do: alert_and_halt("board_size must be an integer > 0 and < 5")
  def process(:help),           do: alert_and_halt("usage: tic_tac_toe <board_size>", ANSI.blue)
  def process(:error),          do: alert_and_halt("failed to parse board_size (integer)")
  def process(board_size),      do: Board.start_link(board_size)

  def parse_args(argv) do
    argv
    |> OptionParser.parse(@parse_opts)
    |> case do
      {[help: true], _, _ }         -> :help
       
      {_, [], _}                    -> @default_size
 
      {_, [board_size_str | _], _}  -> Integer.parse(board_size_str)
    end
  end

  #helpers V

  defp alert_and_halt(msg, color \\ ANSI.red) do
    msg   
    |> Helper.cap(color, ANSI.reset)
    |> IO.puts

    System.halt(0)
  end
end
