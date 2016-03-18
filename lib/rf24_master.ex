
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
use GenServer

  def start_link() do
    {mod, fun} = Application.get_env :rf24_master, :msg_handler, {__MODULE__, :default_msg_handler}
    GenServer.start_link(__MODULE__, %State{ handler: {mod, fun}, socket_address: Application.get_env(:rf24_master, :socket_address, "ipc:///tmp/rf24d.ipc" ) }, name: __MODULE__)
  end 

  def sendMsg(pid, jsonMsg) do
    GenServer.cast(pid, {:send, jsonMsg})
  end

  def recivedCount(pid) do
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

  def handle_info({_,_,msg}, %State{socket: socket, handler: {mod, fun}} = state) do
    require Logger
    received_one = state.received + 1
    jsonMsg = String.strip(msg) |> Poison.decode!
    apply(mod,fun,[jsonMsg])
    {:noreply, %State{state | received: received_one}}
  end

  def terminate(_reason, %State{socket: socket} = state) when socket != nil do
    require Logger
    Logger.info("closing NN socket")
    :ok = :enm.close(socket)
  end

  def default_msg_handler(msg) do
    IO.inspect msg
  end

end
