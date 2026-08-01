--!nonstrict
local ArtKit = require("./src/config/ArtKit")
local ArtGen = require("./src/logic/ArtGen")
local b = ArtGen.rifle(ArtKit.weapons.huntingRifle)
local lo, hi = ArtGen.bounds(b.model.parts)
print(("parts %d  extents %.2f x %.2f x %.2f"):format(#b.model.parts, hi.x-lo.x, hi.y-lo.y, hi.z-lo.z))
print(("muzzle %.2f,%.2f,%.2f   sightPoint %.2f,%.2f,%.2f  sightHeight %.2f  mag %dx  scope=%s")
  :format(b.muzzle.x,b.muzzle.y,b.muzzle.z, b.sightPoint.x,b.sightPoint.y,b.sightPoint.z, b.sightHeight, b.magnification, tostring(b.hasScope)))
local names = {}
for _, p in ipairs(b.model.parts) do names[p.name] = (names[p.name] or 0) + 1 end
local l = {} for k,v in pairs(names) do table.insert(l, k.."="..v) end
table.sort(l); print("parts: " .. table.concat(l, " "))
