--!nonstrict
-- STUDIO-ONLY (NOT headless-analyzed). The client's single point of access to the server RemoteEvents. A
-- LocalScript cannot require the @src modules (they live under ServerScriptService), so every controller
-- talks to the server ONLY through these events (created server-side in WorldServer, in ReplicatedStorage).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function ev(name)
	return ReplicatedStorage:WaitForChild(name)
end

return {
	fire = ev("FireRequest"),
	cast = ev("FishingCast"),
	shop = ev("ShopRequest"),
	travel = ev("TravelRequest"),
}
