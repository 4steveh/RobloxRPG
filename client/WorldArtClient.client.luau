--!nonstrict
-- ════════════════════════════════════════════════════════════════════════════════════════════════════
-- STUDIO-ONLY client FX for the visual overhaul (NOT headless-analyzed). Additive; no gameplay coupling.
-- Owns the client-only pieces of the art layer: the graphics-quality toggle (low-end fallback — cull
-- distant creatures/foliage, drop decorative shadows + heavy post-FX), the ADS / photo-mode DepthOfField
-- enable (off during normal play), and ambient client sprites (dragonflies, fireflies). The server art
-- script (WorldArt.server.luau) owns the world build + the creature upgrade + cosmetic animation.
-- Spec: docs/superpowers/specs/2026-06-18-bayou-visual-overhaul-design.md
-- ════════════════════════════════════════════════════════════════════════════════════════════════════

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

-- (client FX — quality toggle / ADS depth-of-field / ambient sprites — are added by the plan's Phase E tasks)

print("[WildWorldArtClient] online (scaffold; FX land per task)")
