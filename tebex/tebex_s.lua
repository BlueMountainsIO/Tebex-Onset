--[[

	Tebex Settings

]]--
-- Your Tebex secret.
local tebex_secret = ""
-- Tebex API url
local tebex_host = "plugin.tebex.io"
-- Only trigger the purchase event if the player is online, otherwise retry
local require_online = false
-- How often to check for new purchases (milliseconds)
local check_interval = 60000
-- Delete processed commands interval, if any
local delete_interval = 30000


--[[

	Internal

]]--
json = require("packages/"..GetPackageName().."/json")
local check_timer = 0
local delete_timer = 0
-- Holding processed command ids that will be deleted
local pending_delete = { }

function table_count(t)
    local count = 0
    for _, _ in pairs(t) do
        count = count + 1
    end
    return count
end

function table_index(t, val)
    local index = nil
    for i, v in ipairs(t) do 
		if v.id == val then
			index = i 
		end
    end
    return index
end

AddEvent("OnPackageStart", function()

	if check_interval < 1000 then
		check_interval = 1000
	end
	
	if delete_interval < 1000 then
		delete_interval = 1000
	end

	Tebex_VerifySecret()
	
end)

AddEvent("OnPackageStop", function()

	DestroyTimer(check_timer)
	check_timer = 0
	DestroyTimer(delete_timer)
	delete_timer = 0
	
end)

function CreateTebexRequest()

	local r = http_create()
	http_set_protocol(r, "https")
	http_set_host(r, tebex_host)
	http_set_port(r, 443)
	http_set_verifymode(r, "verify_peer")
	http_set_verb(r, "get")
	http_set_timeout(r, 30000)
	http_set_version(r, 11)
	http_set_keepalive(r, false)
	http_set_field(r, "user-agent", "Onset Server "..GetGameVersionString())
	http_set_field(r, "X-Tebex-Secret", tebex_secret)
	
	return r
	
end

function Tebex_VerifySecret()

	local r = CreateTebexRequest()
	http_set_target(r, "/information")
	
	if not http_send(r, OnTebexVerifySecret, r) then
		print("Tebex: Failed to send secret validation request")
		http_destroy(r)
	end
	
end

function OnTebexVerifySecret(http)

	if http_is_error(http) then
		print("Tebex: OnTebexVerifySecret failed: "..http_result_error(http))
	else
		local status = http_result_status(http)
	
		if status ~= 200 then
			print("Tebex: Invalid secret")
			print("Tebex: Enter your corrent secret in file "..debug.getinfo(1).source)
		else
			print("Tebex: Secret validated")
			
			-- Launch request workers
			check_timer = CreateTimer(Tebex_CheckForPurchase, check_interval)
			delete_timer = CreateTimer(Tebex_DeleteProcessed, delete_interval)
		end
	end
	
	http_destroy(http)
	
end

function Tebex_CheckForPurchase()

	local r = CreateTebexRequest()
	http_set_target(r, "/queue/offline-commands")
	
	if not http_send(r, OnTebexCheckForPurcahse, r) then
		print("Tebex: Failed to send purchase check request")
		http_destroy(r)
	end
	
end

function OnTebexCheckForPurcahse(http)

	if http_is_error(http) then
		print("Tebex: OnTebexCheckForPurcahse failed: "..http_result_error(http))
	else
		local status = http_result_status(http)
	
		if status ~= 200 then
			print("Tebex: OnTebexCheckForPurcahse received error code: "..status)
		else
			local body = http_result_body(http)
			
			if string.len(body) > 0 then
				-- Decode json result to a table
				local decoded = json.decode(body)
				
				Tebex_ProcessPurchaseResponse(decoded)
			end
		end
	end
	
	http_destroy(http)
	
end

function Tebex_ProcessPurchaseResponse(response)

	local num_cmds = table_count(response.commands)
	if num_cmds > 0 then
		for i=1,num_cmds do
			Tebex_ProcessCommand(response.commands[i])
		end
	end
	
end

function Tebex_ProcessCommand(cmd)
	
	if require_online == true then
		local player = GetPlayerBySteamId(cmd.uuid)
		if player == false then
			return
		end
	end

	CallEvent("TebexPurchaseEventRaw", cmd)
	CallEvent("TebexPurchaseEvent", cmd.player.uuid, cmd.command, cmd.package, cmd.payment)
	
	pending_delete[cmd.id] = true
	
end

function Tebex_DeleteProcessed()

	if table_count(pending_delete) == 0 then
		return
	end

	local r = CreateTebexRequest()
	http_set_verb(r, "delete")
	
	local target = "/queue?"
	local delim = ""
	for k,_ in pairs(pending_delete) do
		target = target .. delim .. "ids[]=" .. k
		delim = "&"
	end
	
	http_set_target(r, target)
	
	if not http_send(r, OnTebexDeleteProcessed, r, pending_delete) then
		print("Tebex: Failed to send delete request")
		http_destroy(r)
	end
	
end

function OnTebexDeleteProcessed(http, deleted_ids)

	if http_is_error(http) then
		print("Tebex: OnTebexDeleteProcessed failed: "..http_result_error(http))
	else
		local status = http_result_status(http)
	
		if status ~= 204 then
			print("Tebex: OnTebexDeleteProcessed failed to delete purchase ids, status:", status)
		else
			for k,_ in pairs(deleted_ids) do
				pending_delete[k] = nil
			end
		end
	end
	
	http_destroy(http)
	
end
