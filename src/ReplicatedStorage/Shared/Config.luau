-- HEADCOUNT: every tunable number in the game lives here.
-- Change values, press Play, feel the difference. No other file needs touching.

local Config = {}

Config.GameName = "HEADCOUNT"
Config.Version = "1.0.0"

------------------------------------------------------------------ Movement
Config.WalkSpeed = 12
Config.SprintSpeed = 21
Config.StaminaMax = 100
Config.StaminaDrain = 20 -- per second while sprinting
Config.StaminaRegen = 15 -- per second while not sprinting

------------------------------------------------------------------ Flare gun
Config.StartingFlares = 4
Config.SurvivorKitBonusFlares = 2 -- extra starting flares for Survivor Kit owners
Config.FlareBoxAmount = 2
Config.FlareBoxRespawn = 75 -- seconds before an emptied box refills
Config.FlareBoxRespawnFinale = 25
Config.FlareCooldown = 0.6
Config.FlareRange = 240
Config.FlareSpeed = 190 -- studs per second (visual travel time)
Config.FlareHitRadius = 4.5 -- generous aim assist around The Twelfth

------------------------------------------------------------------ The Twelfth
Config.Monster = {
	BaseSpeed = 11.5, -- players walk at 12 and sprint at 21
	SpeedPerPage = 1.0, -- every journal page makes it angrier
	FinaleSpeed = 20,
	StunTime = 2,
	HitsToDown = 4,
	RespawnTime = 40,
	FinaleRespawnTime = 20,
	CatchRange = 4.5,
	HuntDuration = 45,
	HuntIntervalMin = 60, -- seconds between random hunts (after the mess hall)
	HuntIntervalMax = 100,
	LampFlickerRange = 50,
	LampOffRange = 24,
}

------------------------------------------------------------------ Story
Config.TotalPages = 8
Config.FusesNeeded = 3
Config.RosterHitsNeeded = 3
Config.WipeGraceTime = 8 -- seconds to buy a Second Chance before "Counted" ending
Config.IntermissionTime = 14

------------------------------------------------------------------ Monetization
-- Create these on create.roblox.com (your experience > Monetization),
-- then paste the numeric IDs here. 0 = not set up yet.
Config.GamePasses = {
	SurvivorKit = 0, -- +2 starting flares, stronger flashlight
	VIP = 0, -- gold flashlight beam + [VIP] chat tag
}

Config.Products = {
	SecondChance = 0, -- revive instantly after being counted
	FlarePack = 0, -- +5 flares right now
}
Config.FlarePackAmount = 5

-- Badges (create under your experience > Badges, paste IDs). 0 = skip.
Config.Badges = {
	Welcome = 0,
	FirstPage = 0,
	KnockedDown = 0,
	Escaped = 0,
	Counted = 0,
	SecretEnding = 0,
}

------------------------------------------------------------------ Sounds
-- Built-in rbxasset sounds work everywhere but are placeholders.
-- For real horror audio: Studio > Toolbox > Audio, search the name,
-- right-click a Roblox-uploaded sound > Copy Asset ID, paste as "rbxassetid://ID".
-- Empty Id = that sound is skipped.
Config.Sounds = {
	Whistle = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 1, Speed = 1.25, Range = 400 },
	FlareFire = { Id = "rbxasset://sounds/Rocket shot.wav", Volume = 0.6, Speed = 1.4 },
	Pickup = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.4, Speed = 0.6 },
	Splash = { Id = "rbxasset://sounds/impact_water.mp3", Volume = 1, Speed = 0.5 },
	Knock = { Id = "rbxasset://sounds/action_jump_land.mp3", Volume = 1, Speed = 0.6 },
	Door = { Id = "rbxasset://sounds/action_jump_land.mp3", Volume = 0.8, Speed = 0.4 },
	Screech = { Id = "", Volume = 1, Speed = 1 }, -- try "monster scream"
	Jumpscare = { Id = "", Volume = 1, Speed = 1 }, -- try "jumpscare"
	Sting = { Id = "", Volume = 0.8, Speed = 1 }, -- try "horror sting"
	Radio = { Id = "", Volume = 0.4, Speed = 1 }, -- try "radio static"
	Generator = { Id = "", Volume = 0.6, Speed = 1 }, -- try "generator start"
	Ambience = { Id = "", Volume = 0.35, Speed = 1 }, -- try "night forest ambience" (loops)
	Heartbeat = { Id = "", Volume = 0.8, Speed = 1 }, -- try "heartbeat" (loops, louder when it's close)
}

return Config
