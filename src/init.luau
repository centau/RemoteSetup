--------------------------------------------------------------------------------
-- RemoteSetup.luau
-- v0.0.1
--------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

export type ClientEvent<T... = ...any> = {
    FireClient: (ClientEvent<T...>, Player, T...) -> ();
    FireAllClients: (ClientEvent<T...>, T...) -> ();
    ConnectClient: (ClientEvent<T...>, (T...) -> ()) -> RBXScriptConnection;
    WaitForServer: (ClientEvent<T...>) -> T...;
}

export type ServerEvent<T... = ...any> = {
    FireServer: (ServerEvent<T...>, T...) -> ();
    ConnectServer: (ServerEvent<T...>, (Player, T...) -> ()) -> RBXScriptConnection;
}

export type ServerFunction<T... = ...any, U... = ...any> = typeof(setmetatable(
    {} :: {
        OnServerInvoke: (Player, T...) -> U...
    }, {} :: {
        __call: (ServerFunction<T..., U...>, T...) -> U...
    }
))

local ClientEvent = {} do
    type _ClientEvent = ClientEvent & {
        _Remote: RemoteEvent
    }

    ClientEvent.__index = ClientEvent

    function ClientEvent.new(remote: RemoteEvent): ClientEvent<...any>
        return table.freeze(setmetatable({
            _Remote = remote,
        }, ClientEvent)) :: any
    end

    function ClientEvent.FireClient(self: _ClientEvent, player: Player, ...: any)
        self._Remote:FireClient(player, ...)
    end

    function ClientEvent.FireAllClients(self: _ClientEvent, ...: any)
        self._Remote:FireAllClients(...)
    end

    function ClientEvent.ConnectClient(self: _ClientEvent, listener: (...any) -> ()): RBXScriptConnection
        return self._Remote.OnClientEvent:Connect(listener)
    end

    function ClientEvent.WaitForServer(self: _ClientEvent, listener: (...any) -> ()): ...any
        return self._Remote.OnClientEvent:Wait()
    end
end

local ServerEvent = {} do
    type _ServerEvent = ServerEvent & {
        _Remote: RemoteEvent
    }

    ServerEvent.__index = ServerEvent

    function ServerEvent.new(remote: RemoteEvent): ServerEvent<...any>
        return table.freeze(setmetatable({
            _Remote = remote,
        }, ServerEvent)) :: any
    end

    function ServerEvent.FireServer(self: _ServerEvent, ...: any)
        self._Remote:FireServer(...)
    end

    function ServerEvent.ConnectServer(self: _ServerEvent, listener: (Player, ...any) -> ()): RBXScriptConnection
        return self._Remote.OnServerEvent:Connect(listener)
    end
end

local ServerFunction = {} do
    type _ServerFunction = ServerFunction & {
        _Remote: RemoteFunction,
        _Callback: { Value: (Player, ...any) -> ...any }
    }

    function ServerFunction.new(remote: RemoteFunction): ServerFunction<...any, ...any>
        return table.freeze(setmetatable({
            _Remote = remote,
            _Callback = { Value = nil }
        }, ServerFunction)) :: any
    end

    function ServerFunction.__newindex(self: _ServerFunction, index: "OnServerInvoke", callback: (Player, ...any) -> ...any)
        if index ~= "OnServerInvoke" then error("\""..index.."\" is not a valid member of ServerFunction", 2) end
        if self._Callback.Value then error("ServerFunction.OnServerInvoke has already been set", 2) end
        self._Callback.Value = callback :: any
        self._Remote.OnServerInvoke = callback
    end

    function ServerFunction.__call(self: _ServerFunction, ...: any): ...any
        return self._Remote:InvokeServer(...)
    end
end

local remotes: { RemoteEvent | RemoteFunction }
local id = 0

local setup: {
    ServerEvent: () -> ServerEvent<...any>;
    ClientEvent: () -> ClientEvent<...any>;
    ServerFunction: () -> ServerFunction<...any, ...any>;
}

if RunService:IsServer() then
    local replicator do
        replicator = Instance.new("RemoteEvent")
        replicator.Name = "RemoteSetupReplicator"
        replicator.Parent = ReplicatedStorage
    end

    remotes = {}

    task.defer(function()
        replicator:FireAllClients(remotes)
        Players.PlayerAdded:Connect(function(player)
            replicator:FireClient(player, remotes) 
        end)
    end)

    local createRemote = function(class: "RemoteEvent"): RemoteEvent
        local remote = Instance.new(class)
        id += 1
        remotes[id] = remote
        remote.Parent = replicator
        return remote
    end :: (("RemoteEvent") -> RemoteEvent) & (("RemoteFunction") -> RemoteFunction)

    setup = {
        ServerEvent = function()
            local remote = createRemote("RemoteEvent")
            return ServerEvent.new(remote)
        end,

        ClientEvent = function()
            local remote = createRemote("RemoteEvent")
            return ClientEvent.new(remote)
        end,

        ServerFunction = function()
            local remote = createRemote("RemoteFunction")
            return ServerFunction.new(remote)
        end
    }
else
    local replicator = ReplicatedStorage:WaitForChild("RemoteSetupReplicator")

    remotes = replicator.OnClientEvent:Wait()

    local getRemote = function(): RemoteEvent | RemoteFunction
        id += 1
        return remotes[id]
    end

    setup = {
        ServerEvent = function()
            local remote = getRemote()
            return ServerEvent.new(remote :: RemoteEvent)
        end,

        ClientEvent = function()
            local remote = getRemote()
            return ClientEvent.new(remote :: RemoteEvent)
        end,

        ServerFunction = function()
            local remote = getRemote()
            return ServerFunction.new(remote :: RemoteFunction)
        end
    }
end

return setup
