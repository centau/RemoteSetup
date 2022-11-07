# RemoteSetup

Simple library for Roblox used to setup remote events and remote functions programatically (with optional typechecking too).

The module is designed to be required by a module in ReplicatedStorage, which can be required by both client and server scripts.

## Sample Use

```lua
-- ReplicatedStorage/remote

local setup = require(RemoteSetup)

type ServerEvent<T...> = setup.ServerEvent<T...>
type ClientEvent<T...> = setup.ClientEvent<T...>
type ServerFunction<T..., U...> = setup.ServerFunction<T..., U...>

return {
    OnDeath = setup.ClientEvent() :: ClientEvent<string>
    OnWeaponChange = setup.ServerEvent() :: ServerEvent<string>,
    GetDataAsync = setup.ServerFunction() :: ServerFunction<(string), (number)>,
}
```

```lua
-- ServerScriptService/server

local remote = require(ReplicatedStorage.remote)

local function onPlayerDeath(player, msg)
    remote.OnDeath:FireClient(player, msg)
end

remote.OnWeaponChanged:ConnectServer(function(player, weapon)
    changeWeapon(player, weapon)
end)

function remote.GetDataAsync.OnServerInvoke(player, category)
    return data[player][category]
end
```

```lua
-- StarterPlayerScripts/client

local remote = require(ReplicatedStorage.remote)

remote.OnDeath:ConnectClient(playDeathScreen)

remote.OnWeaponChanged:FireServer("AK-47")
local kills = remote.GetDataAsync("Kills")
```

Note that the library relies on `ClientEvent()`, `ServerEvent()` and `ServerFunction()` all being called in the same order on both client and server so that they can be matched correctly.

These functions must be called during the same frame that the library is required in, no yielding is allowed between.

When required on the client, the client will yield briefly to get the remote data.

## API

### RemoteSetup

```lua
function RemoteSetup.ClientEvent(): ClientEvent<...any>
function RemoteSetup.ServerEvent(): ServerEvent<...any>
function RemoteSetup.ServerFunction(): ServerFunction<...any, ...any>
```

### ClientEvent

```lua
function ClientEvent:FireClient<T...>(client: Player, args: T...)
function ClientEvent:FireAllClients<T...>(args: T...)
function ClientEvent:ConnectClient<T...>(listener: (T...) -> ()): RBXScriptConnection
function ClientEvent:WaitForServer<T...>(): T...
```

### ServerEvent

```lua
function ServerEvent:FireServer<T...>(args: T...)
function ServerEvent:ConnectServer<T...>(listener: (Player, T...) -> ()): RBXScriptConnection
```

### ServerFunction

```lua
function ServerEvent.OnServerInvoke<T..., U...>(Player, T...): U...
function ServerEvent<T..., U...>(args: T...): U...
```
