defmodule RfMaster do
  alias RfMaster.Msg

  def startIPC() do
    {:ok, s} = :enm.pair
    :enm.bind(s, "ipc:///tmp/rf24d.ipc")
    {:ok, s}
  end

 def createMsg(type, node_id, msg) do
     Poison.encode!(%Msg{type: type, node_id: node_id, msg: msg})
 end

 def greenMsg(s) do
    msg = createMsg(2,0o01, "HI")
   :enm.send(s, msg)
 end

 def redMsg(s) do
   msg = createMsg(1,0o01, "HI")
   :enm.send(s, msg)
 end

end
