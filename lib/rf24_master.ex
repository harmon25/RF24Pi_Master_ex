
defmodule RfMaster.Msg do
  @derive [Poison.Encoder]
  defstruct [:type, :to_node, :msg]
end
  
defmodule RfMaster.State do
  @doc ~S"""
  socket :: %Socket
  count :: integer
  """
defstruct socket: nil, received: 0, sent: 0, socket_address: nil, handler: {nil, nil}
  #@type t :: %__MODULE__{socket: reference, count: integer, socket_address: String.t, handler: tuple}
end

defmodule RfMaster do
alias RfMaster.State
alias RfMaster.Msg
use GenServer

 def buildMsg({to_node, msg_type} = header, msg) when is_tuple(header) and is_bitstring(to_node) and is_integer(msg_type) do
     {:ok, %Msg{to_node: to_node, type: msg_type, msg: msg} }
 end
def buildMsg(_, _) do
    require Logger
    Logger.warn("Invalid Msg - pass a header and msg, header is a tuple {to_node, msg_type}")
end
def buildMsg(_, _, _) do
    require Logger
    Logger.warn("Invalid Msg - pass a header and msg, header is a tuple {to_node, msg_type}")
    {:err, "invalid msg"}
end
 
 def buildMsg!({to_node, msg_type} = header, msg) when is_tuple(header) and is_bitstring(to_node) and is_integer(msg_type) do
     %Msg{to_node: to_node, type: msg_type, msg: msg}
 end
 def buildMsg!(_, _) do
    require Logger
    Logger.warn("Invalid Msg - pass a header and msg, header is a tuple {to_node, msg_type}")
    {:err, "invalid msg"}
 end
 def buildMsg!(_, _, _) do
    require Logger
    Logger.warn("Invalid Msg - pass a header and msg, header is a tuple {to_node, msg_type}")
    {:err, "invalid msg"}
end

  def start_link() do
    {mod, fun} = Application.get_env :rf24_master, :msg_handler, {__MODULE__, :default_msg_handler}
    GenServer.start_link(__MODULE__, %State{ handler: {mod, fun}, socket_address: Application.get_env(:rf24_master, :socket_address, "ipc:///tmp/rf24d.ipc" ) }, name: __MODULE__)
  end 

  def sendMsg(%Msg{} = msgToJson, pid) do
    jsonMsg = Poison.encode!(msgToJson)
    GenServer.cast(pid, {:send, jsonMsg})
  end

  def sendMsg(_, _) do
    require Logger
    Logger.info("Invalid Msg - use buildMsg:2 or buildMsg!:2 to create a msg")
    {:err, "invalid msg"}
  end

  def getCounts(pid) do
    GenServer.call(pid, :counts)
  end

   def init(%State{} = state) do
    require Logger
    {:ok, nn_sock} = :enm.pair
    :enm.bind(nn_sock, state.socket_address )
    Logger.info("Bound NN pair socket to: #{state.socket_address}")
    {:ok, %{state | socket: nn_sock }}
  end

  def handle_call(:counts, _from,  %State{} = state) do
    {:reply, %{received: state.received, sent: state.sent}, state}
  end

  def handle_cast({:send, jsonMsg}, %State{socket: socket} = state) do
    :enm.send(socket, jsonMsg)
    sent_one = state.sent + 1 
    {:noreply, %State{state | sent: sent_one}}
  end

  def handle_info({_,_,msg}, %State{handler: {mod, fun}} = state) do
    require Logger
    received_one = state.received + 1
    jsonMsg = String.strip(msg) |> Poison.decode!
    apply(mod,fun,[jsonMsg])
    {:noreply, %State{state | received: received_one}}
  end

  def terminate(_reason, %State{socket: socket}) when socket != nil do
    require Logger
    Logger.info("closing NN socket")
    :ok = :enm.close(socket)
  end

  def default_msg_handler(msg) do
    IO.inspect msg
  end

end
