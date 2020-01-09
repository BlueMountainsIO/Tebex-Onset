## Tebex.io for Onset

This packages integrates the Tebex.io service.
It follows the API as documented on this site: https://docs.tebex.io/plugin/

#### Installation
1. Copy the **tebex** folder to your server directory under the **packages** folder.
2. Edit *tebex_s.lua* and assign your secret key to the **secret** variable. You get the secret key from your Tebex control panel.
3. Edit your *server_config.json* file and add **tebex** as a package.

#### Event Usage
On an successful payment this package will call an event.
This is where you would give the player any items or subscriptions.
```Lua
--[[
"TebexPurchaseEvent"
 uuid: The SteamId64 of the player.
 cmd: The command string that you have configured in the Tebex control panel.
 packageid: The id of the package in your Tebex control panel.
 paymentid: The payment identifier.
]]--
AddEvent("TebexPurchaseEvent", function(uuid, cmd, packageid, paymentid)
	print("TebexPurchaseEvent", uuid, cmd, packageid, paymentid)
end)

