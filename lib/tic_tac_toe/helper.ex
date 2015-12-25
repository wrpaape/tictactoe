defmodule TicTacToe.Helper do
  def wrap_app(left, right), do: {left, right}
  def wrap_pre(right, left), do: {left, right}

  def cap(str, lcap, rcap), do: lcap <> str <> rcap
  def cap(str, cap),        do:  cap <> str <> cap
end
