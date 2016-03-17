defmodule RfMaster.Msg do
  @derive [Poison.Encoder]
  defstruct [:type, :node_id, :msg]
end
