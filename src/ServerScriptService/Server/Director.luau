-- The Director runs the story: chapters, scripted scares, hunts, respawns and endings.
-- One "round" is one night at Camp Hollow Pines. When it ends, the camp is rebuilt and it starts again.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Story = require(Shared:WaitForChild("Story"))

local MapBuilder = require(script.Parent.MapBuilder)
local Monster = require(script.Parent.Monster)
local Flares = require(script.Parent.Flares)
local Monetization = require(script.Parent.Monetization)

local M = Config.Monster
local GameState = ReplicatedStorage -- story state for clients lives in its attributes

local RED = Color3.fromRGB(255, 70, 70)
local GOLD = Color3.fromRGB(255, 210, 110)

local Director = {}

local Remotes
local map
local monster
local S = {}
local roundId = 0
local sceneToken = 0
local zoneHandlers = {}

local startChapter, startFinale -- defined further down

local function newState()
	return {
		Chapter = 0,
		Checkpoint = "Car",
		Pages = {},
		PageCount = 0,
		Counted = {},
		CountedNames = {},
		KitOpened = false,
		AtGate = false,
		RadioFound = false,
		Sighting = false,
		SightingDone = false,
		CanoeFlipped = false,
		LakeChase = false,
		LakeChaseOver = false,
		DoorBarred = false,
		Fuses = 0,
		GeneratorOn = false,
		BigChase = false,
		BigChaseOver = false,
		FirstKill = false,
		HasKey = false,
		OfficeOpen = false,
		SecretFound = false,
		AtFlagpole = false,
		Finale = false,
		Victory = false,
		RosterHits = 0,
		LightsOut = false,
		HuntsEnabled = false,
		NextHuntAt = math.huge,
		RespawnToken = 0,
		DownedUntil = 0,
		Ending = nil,
		WipePending = false,
		LastResistLine = 0,
	}
end

------------------------------------------------------------------ messaging

local function say(speaker, text, seconds, target)
	seconds = seconds or 3.5
	if target then
		Remotes.Dialogue:FireClient(target, speaker, text, seconds)
	else
		Remotes.Dialogue:FireAllClients(speaker, text, seconds)
	end
	return seconds
end

-- Plays a scene and yields until it finishes. A newer scene interrupts an older one.
local function playScene(name)
	sceneToken += 1
	local token, r = sceneToken, roundId
	for _, line in ipairs(Story.Scenes[name]) do
		if token ~= sceneToken or r ~= roundId then
			return false
		end
		task.wait(say(line[1], line[2], line[3]))
	end
	return token == sceneToken and r == roundId
end

local function runScene(name)
	task.spawn(playScene, name)
end

local function sceneFor(player, name)
	task.spawn(function()
		for _, line in ipairs(Story.Scenes[name]) do
			task.wait(say(line[1], line[2], line[3], player))
		end
	end)
end

local function fx(kind, ...)
	Remotes.Effect:FireAllClients(kind, ...)
end

local function notify(text, color)
	Remotes.Notify:FireAllClients(text, color)
end

local function whistles(pos, distant)
	fx("Whistles", pos, distant)
end

local function waitRound(r, seconds)
	task.wait(seconds)
	return r == roundId
end

------------------------------------------------------------------ players

local function aliveTargets()
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if not S.Counted[p] then
			local char = p.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if hum and root and hum.Health > 0 and not root.Anchored then
				table.insert(list, { Player = p, Root = root })
			end
		end
	end
	return list
end

local function nearestTarget(pos)
	local best, bestDist
	for _, t in ipairs(aliveTargets()) do
		local d = (t.Root.Position - pos).Magnitude
		if not bestDist or d < bestDist then
			best, bestDist = t, d
		end
	end
	return best, bestDist
end

local function facingNearest(pos)
	local t = nearestTarget(pos)
	if t then
		local tp = t.Root.Position
		local flat = Vector3.new(tp.X, pos.Y, tp.Z)
		if (flat - pos).Magnitude > 0.5 then
			return CFrame.lookAt(pos, flat)
		end
	end
	return CFrame.new(pos)
end

local function setCheckpoint(name)
	S.Checkpoint = name
	map.Spawn.CFrame = map.Checkpoints[name] * CFrame.new(0, 0.5, 0)
end

local function spawnPlayer(player)
	if not player.Parent or not map then
		return
	end
	S.Counted[player] = nil
	player:SetAttribute("Counted", false)
	pcall(player.LoadCharacter, player)
end

local function styleFlashlight(player, beam)
	local strong = player:GetAttribute("SurvivorKit") == true
	beam.Range = strong and 64 or 46
	beam.Brightness = strong and 3.2 or 2.4
	beam.Color = player:GetAttribute("VIP") and Color3.fromRGB(255, 214, 120) or Color3.fromRGB(255, 244, 225)
end

local function onCharacter(player, char)
	local hum = char:WaitForChild("Humanoid", 10)
	local head = char:WaitForChild("Head", 10)
	if not hum or not head then
		return
	end
	hum.WalkSpeed = Config.WalkSpeed
	hum.NameDisplayDistance = 30
	local beam = Instance.new("SpotLight")
	beam.Name = "Flashlight"
	beam.Face = Enum.NormalId.Front
	beam.Angle = 70
	beam.Shadows = true
	styleFlashlight(player, beam)
	beam.Parent = head
	if S.KitOpened then
		Flares.giveGun(player, false)
	end
	local r = roundId
	hum.Died:Connect(function()
		if S.Counted[player] or S.Ending then
			return
		end
		task.delay(3, function()
			if r == roundId and player.Parent and player.Character == char and not S.Counted[player] and not S.Ending then
				spawnPlayer(player)
			end
		end)
	end)
end

local function reviveCounted()
	for player in pairs(S.Counted) do
		if player.Parent then
			task.spawn(spawnPlayer, player)
			sceneFor(player, "Revived")
		end
	end
end

local function checkWipe()
	if S.Ending or S.WipePending or #Players:GetPlayers() == 0 or #aliveTargets() > 0 then
		return
	end
	S.WipePending = true
	local r = roundId
	notify("Everyone has been counted...", RED)
	task.delay(Config.WipeGraceTime, function()
		if r ~= roundId then
			return
		end
		S.WipePending = false
		if not S.Ending and #aliveTargets() == 0 then
			Director.endRound("B")
		end
	end)
end

local function countPlayer(player)
	if S.Counted[player] or S.Ending or not player.Parent then
		return
	end
	local char = player.Character
	S.Counted[player] = true
	player:SetAttribute("Counted", true)
	table.insert(S.CountedNames, player.DisplayName)
	Remotes.Effect:FireClient(player, "Jumpscare")
	fx("Sound", "Screech", monster:GetPosition())
	notify(player.DisplayName .. " was counted...", RED)
	Monetization.AwardBadge(player, "Counted")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root then
		root.Anchored = true
	end
	task.delay(1.3, function()
		if S.Counted[player] and char and player.Character == char then
			char:Destroy()
		end
	end)
	checkWipe()
end

function Director.revive(player)
	if S.Counted[player] and not S.Ending then
		spawnPlayer(player)
		notify(player.DisplayName .. " got a Second Chance!", GOLD)
	else
		Flares.give(player, 3)
	end
	return true
end

------------------------------------------------------------------ world state

local DARK_BULB = Color3.fromRGB(40, 38, 34)

local function setLamp(l, on)
	if l.On == on then
		return
	end
	l.On = on
	l.Light.Enabled = on
	l.Bulb.Material = on and l.OnMaterial or Enum.Material.SmoothPlastic
	l.Bulb.Color = on and l.OnColor or DARK_BULB
end

-- Lamps die whenever The Twelfth is close. If the lamps start going out, run.
local function lampLoop(r)
	while r == roundId do
		local mPos = monster:IsVisible() and monster:GetPosition() or nil
		for _, l in ipairs(map.Lamps) do
			local want = not (l.Dead or S.LightsOut or (l.Group == "Hall" and not S.GeneratorOn))
			if want and mPos then
				local d = (l.Bulb.Position - mPos).Magnitude
				if d < M.LampOffRange then
					want = false
				elseif d < M.LampFlickerRange then
					want = math.random() < 0.5
				end
			end
			setLamp(l, want)
		end
		task.wait(0.12)
	end
end

local function tweenAtmosphere(props, seconds)
	local atm = Lighting:FindFirstChildOfClass("Atmosphere")
	if atm then
		TweenService:Create(atm, TweenInfo.new(seconds, Enum.EasingStyle.Sine), props):Play()
	end
end

local function dawn()
	local info = TweenInfo.new(7, Enum.EasingStyle.Sine)
	TweenService:Create(Lighting, info, {
		ClockTime = 6.4,
		Ambient = Color3.fromRGB(70, 62, 60),
		OutdoorAmbient = Color3.fromRGB(125, 112, 100),
	}):Play()
	tweenAtmosphere({ Density = 0.25, Color = Color3.fromRGB(199, 170, 140), Haze = 1 }, 7)
	local cc = Lighting:FindFirstChild("HeadcountCC")
	if cc then
		TweenService:Create(cc, info, { Saturation = 0, TintColor = Color3.fromRGB(255, 236, 215) }):Play()
	end
end

local function hideInteractable(part)
	part.Transparency = 1
	part.CanCollide = false
	for _, c in ipairs(part:GetDescendants()) do
		if c:IsA("Light") then
			c.Enabled = false
		elseif c:IsA("SurfaceGui") then
			c.Enabled = false
		end
	end
end

------------------------------------------------------------------ objective

local function refreshObjective()
	local o = ""
	if S.Finale then
		o = string.format("BURN THE ROSTER! Stun it with a flare, then hit the roster with another (%d/%d)", S.RosterHits, Config.RosterHitsNeeded)
	elseif S.Chapter == 0 then
		o = S.KitOpened and "Walk up the road to the camp and find help." or "Check the emergency kit in the car's trunk."
	elseif S.Chapter == 1 then
		if S.RadioFound then
			o = "Find Marcy's journal page on the gate."
		elseif S.AtGate then
			o = "Pick up the walkie-talkie hanging on the gate."
		else
			o = "Walk up the road to the camp and find help."
		end
	elseif S.Chapter == 2 then
		o = "Search the cabins around the campfire for Marcy's pages."
	elseif S.Chapter == 3 then
		if S.LakeChase and not S.LakeChaseOver then
			o = "RUN to the boathouse at the end of the dock! Bar the door!"
		elseif S.LakeChaseOver then
			o = "Search the boathouse for Marcy's pages."
		else
			o = "Head east to the lake."
		end
	elseif S.Chapter == 4 then
		if not S.GeneratorOn then
			if S.Fuses >= Config.FusesNeeded then
				o = "Start the generator in the back room of the mess hall."
			else
				o = string.format("Mess hall (west of camp): find fuses for the generator (%d/%d)", S.Fuses, Config.FusesNeeded)
			end
		elseif S.BigChase and not S.BigChaseOver then
			o = "SURVIVE! Flares stun it. 4 hits knock it down."
		else
			o = "Find Marcy's pages in the kitchen and the generator room."
		end
	elseif S.Chapter == 6 then
		o = S.AtFlagpole and "Take the page clipped behind the roster." or "Head north to the flagpole."
		if S.HasKey and not S.SecretFound then
			o ..= "\n(Optional) Unlock the Director's office on the hill."
		end
	end
	GameState:SetAttribute("Objective", o)
end

------------------------------------------------------------------ hunts

local function pickSpawn(minDist, maxDist)
	local targets = aliveTargets()
	local candidates, fallback, fallbackDist = {}, nil, math.huge
	for _, pos in ipairs(map.MonsterSpawns) do
		local nearest = math.huge
		for _, t in ipairs(targets) do
			nearest = math.min(nearest, (t.Root.Position - pos).Magnitude)
		end
		if nearest >= minDist and nearest <= maxDist then
			table.insert(candidates, pos)
		elseif nearest >= minDist and nearest < fallbackDist then
			fallback, fallbackDist = pos, nearest
		end
	end
	if #candidates > 0 then
		return candidates[math.random(#candidates)]
	end
	return fallback or map.MonsterSpawns[math.random(#map.MonsterSpawns)]
end

local function scheduleNextHunt()
	S.NextHuntAt = os.clock() + math.random(M.HuntIntervalMin, M.HuntIntervalMax)
end

-- Three whistles, then it comes.
local function startHunt(duration, spawnPos)
	local r = roundId
	task.spawn(function()
		spawnPos = spawnPos or pickSpawn(70, 160)
		whistles(spawnPos, false)
		runScene("Whistles")
		task.wait(2.5)
		if r ~= roundId or S.Ending or S.Finale or monster.State ~= "Hidden" then
			return
		end
		monster:Appear(facingNearest(spawnPos))
		monster:StartHunt(duration)
	end)
end

local function huntLoop(r)
	while r == roundId do
		task.wait(1)
		if S.HuntsEnabled and not S.Finale and not S.Ending and monster.State == "Hidden" and os.clock() >= S.NextHuntAt then
			S.NextHuntAt = math.huge
			startHunt(M.HuntDuration)
		end
	end
end

local function lakeChaseOver(barred)
	if S.LakeChaseOver then
		return
	end
	S.LakeChaseOver = true
	map.Prompts.BarDoor.Enabled = false
	runScene(barred and "SafeInBoathouse" or "LakeChaseOver")
	refreshObjective()
end

local function bigChaseOver(knockedDown)
	if S.BigChaseOver then
		return
	end
	S.BigChaseOver = true
	S.HuntsEnabled = true
	if not knockedDown then
		runScene("ChaseOverNoKill")
		scheduleNextHunt()
	end
	refreshObjective()
end

local function onHuntEnded()
	if S.LakeChase and not S.LakeChaseOver then
		lakeChaseOver(false)
	end
	if S.BigChase and not S.BigChaseOver then
		bigChaseOver(false)
	elseif S.HuntsEnabled then
		scheduleNextHunt()
	end
end

local function onDowned()
	S.RespawnToken += 1
	local token, r = S.RespawnToken, roundId
	local respawn = S.Finale and M.FinaleRespawnTime or M.RespawnTime
	S.DownedUntil = os.clock() + respawn
	fx("Sound", "Screech", monster:GetPosition())
	fx("Flash", Color3.fromRGB(255, 140, 60), 0.4)
	notify("The Twelfth is down... for now.", Color3.fromRGB(255, 170, 90))
	for _, t in ipairs(aliveTargets()) do
		Monetization.AwardBadge(t.Player, "KnockedDown")
	end
	local firstKill = not S.FirstKill
	if firstKill and not S.Finale then
		S.FirstKill = true
		task.delay(3.5, function()
			if r == roundId then
				runScene("FirstKill")
			end
		end)
	end
	if S.LakeChase and not S.LakeChaseOver then
		lakeChaseOver(false)
	end
	if S.BigChase and not S.BigChaseOver then
		bigChaseOver(true)
	end
	task.delay(respawn, function()
		if r ~= roundId or token ~= S.RespawnToken or S.Ending or monster.State ~= "Hidden" then
			return
		end
		if S.Finale then
			local spot = map.Points.FlagpoleBehind.Position
			whistles(spot, false)
			runScene("Whistles")
			if not waitRound(r, 2.5) or token ~= S.RespawnToken or S.Ending or S.Victory then
				return
			end
			monster:Appear(facingNearest(spot))
			monster:StartHunt(nil)
		elseif firstKill then
			whistles(nil, true)
			runScene("ItsBack")
			if S.HuntsEnabled then
				S.NextHuntAt = os.clock() + 25
			end
		elseif S.HuntsEnabled then
			startHunt(M.HuntDuration * 0.75)
		else
			whistles(nil, true)
			runScene("WhistlesFar")
		end
	end)
end

------------------------------------------------------------------ sighting

local function endSighting()
	if not S.Sighting then
		return
	end
	S.Sighting = false
	GameState:SetAttribute("Phase", "")
	if monster.State == "Visible" then
		monster:Hide()
	end
	local r = roundId
	task.delay(1.2, function()
		if r == roundId then
			runScene("FirstSighting")
		end
	end)
end

local function startSighting()
	if S.SightingDone or monster.State ~= "Hidden" then
		return
	end
	S.SightingDone = true
	S.Sighting = true
	monster:Appear(map.Points.Sighting)
	GameState:SetAttribute("Phase", "Sighting")
	fx("Sound", "Sting")
	local r = roundId
	task.delay(14, function()
		if r == roundId then
			endSighting()
		end
	end)
end

------------------------------------------------------------------ zones

local function inZone(pos, z)
	local rel = z.CFrame:PointToObjectSpace(pos)
	return math.abs(rel.X) <= z.Size.X / 2 and math.abs(rel.Y) <= z.Size.Y / 2 and math.abs(rel.Z) <= z.Size.Z / 2
end

-- fn(player) runs when a living player stands in the zone. For one-shot zones,
-- returning false means "not yet" and the zone keeps watching. fn must not yield.
local function onZone(name, fn, once)
	zoneHandlers[name] = { Fn = fn, Once = once ~= false, Fired = false, Cooldown = {} }
end

local function zoneLoop(r)
	while r == roundId do
		local targets = aliveTargets()
		for name, h in pairs(zoneHandlers) do
			local z = map.Zones[name]
			if z and not (h.Once and h.Fired) then
				for _, t in ipairs(targets) do
					if inZone(t.Root.Position, z) then
						if h.Once then
							if h.Fn(t.Player) ~= false then
								h.Fired = true
							end
							break
						elseif (h.Cooldown[t.Player] or 0) < os.clock() then
							h.Cooldown[t.Player] = os.clock() + 3
							task.spawn(h.Fn, t.Player)
						end
					end
				end
			end
		end
		task.wait(0.2)
	end
end

------------------------------------------------------------------ pages & chapters

local function enablePages(...)
	for _, i in ipairs({ ... }) do
		local p = map.Pages[i]
		if p and not S.Pages[i] then
			p.Prompt.Enabled = true
		end
	end
end

local function onPage(index, player)
	if S.Pages[index] or S.Ending then
		return
	end
	S.Pages[index] = true
	local p = map.Pages[index]
	p.Prompt.Enabled = false
	hideInteractable(p.Part)
	if index <= Config.TotalPages then
		S.PageCount += 1
	end
	GameState:SetAttribute("Pages", S.PageCount)
	local data = Story.Pages[index]
	Remotes.PageFound:FireAllClients(index, data.Title, data.Text, S.PageCount, Config.TotalPages)
	fx("Sound", "Pickup")
	Monetization.AddPage(player)
	if S.PageCount == 1 then
		for _, pl in ipairs(Players:GetPlayers()) do
			Monetization.AwardBadge(pl, "FirstPage")
		end
	end
	if not S.Finale then
		monster.Speed = M.BaseSpeed + M.SpeedPerPage * S.PageCount
	end

	if index == 9 then
		S.SecretFound = true
		notify("Secret found: the Director's letter", GOLD)
		runScene("OfficeLetter")
		refreshObjective()
	elseif index == 8 then
		startFinale()
	elseif index == 1 then
		startChapter(2)
	elseif S.Chapter == 2 and S.Pages[2] and S.Pages[3] then
		startChapter(3)
	elseif S.Chapter == 3 and S.Pages[4] and S.Pages[5] then
		startChapter(4)
	elseif S.Chapter == 4 and S.Pages[6] and S.Pages[7] then
		startChapter(6)
	end
end

startChapter = function(n)
	if S.Ending then
		return
	end
	S.Chapter = n
	GameState:SetAttribute("Chapter", n)
	fx("Chapter", Story.Chapters[n])
	reviveCounted()
	if n == 2 then
		setCheckpoint("Campfire")
		enablePages(2, 3)
	elseif n == 3 then
		setCheckpoint("Dock")
		enablePages(4, 5)
	elseif n == 4 then
		setCheckpoint("MessHall")
		for i, pp in ipairs(map.Prompts.Fuses) do
			pp.Enabled = map.Parts.Fuses[i].Transparency < 1
		end
		map.Prompts.Key.Enabled = not S.HasKey
	elseif n == 6 then
		setCheckpoint("Flagpole")
		runScene("ToFlagpole")
	end
	refreshObjective()
end

startFinale = function()
	if S.Finale or S.Ending then
		return
	end
	S.Finale = true
	S.HuntsEnabled = false
	S.RespawnToken += 1
	S.RosterHits = 0
	S.LightsOut = true
	GameState:SetAttribute("Phase", "Finale")
	GameState:SetAttribute("RosterHits", 0)
	reviveCounted()
	monster:Hide()
	monster.Hits = 0
	monster.Speed = M.FinaleSpeed
	local r = roundId
	task.spawn(function()
		local spot = map.Points.FlagpoleBehind.Position
		for _, off in ipairs({ Vector3.new(80, 0, 0), Vector3.new(-80, 0, 0), Vector3.new(0, 0, 80), Vector3.new(0, 0, -80) }) do
			whistles(spot + off, false)
		end
		playScene("FinaleWhistle")
		if r ~= roundId or S.Ending then
			return
		end
		monster:Appear(facingNearest(spot))
		fx("Flash", Color3.fromRGB(255, 0, 0), 0.25)
		fx("Shake", 1, 1.2)
		playScene("Headcount")
		if r ~= roundId or S.Ending then
			return
		end
		refreshObjective()
		monster:StartHunt(nil)
		runScene("Finale")
	end)
end

local function giveWhistle(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end
	local tool = Instance.new("Tool")
	tool.Name = "Marcy's Whistle"
	tool.CanBeDropped = false
	tool.ToolTip = "You can't let go of it."
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.3, 0.3, 0.8)
	handle.Color = Color3.fromRGB(200, 200, 205)
	handle.Material = Enum.Material.Metal
	handle.CanCollide = false
	handle.Parent = tool
	tool.Parent = backpack
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum:EquipTool(tool)
	end
end

function Director.endRound(kind)
	if S.Ending then
		return
	end
	S.Ending = kind
	S.HuntsEnabled = false
	S.RespawnToken += 1
	GameState:SetAttribute("Phase", "Ending")
	local r = roundId
	local ending = Story.Endings[kind]
	task.spawn(function()
		if kind == "B" then
			monster:Hide()
			fx("Fade", 0, 1.5)
			task.wait(1.8)
			fx("Roster", S.CountedNames)
			task.wait(1 + #S.CountedNames * 0.8)
			playScene("EndingB")
			fx("Ending", ending.Title, ending.Subtitle, kind)
			task.wait(8)
		else
			local survivors = aliveTargets()
			S.LightsOut = false
			dawn()
			for _, t in ipairs(survivors) do
				Monetization.AddEscape(t.Player)
				Monetization.AwardBadge(t.Player, "Escaped")
			end
			playScene("EndingA")
			if kind == "C" and #survivors > 0 then
				local chosen = survivors[math.random(#survivors)].Player
				giveWhistle(chosen)
				task.wait(say("SOUND", string.format(Story.WhistleLine, chosen.DisplayName), 4.5))
				playScene("EndingC")
				for _, t in ipairs(survivors) do
					Monetization.AwardBadge(t.Player, "SecretEnding")
				end
			end
			fx("Ending", ending.Title, ending.Subtitle, kind)
			task.wait(9)
			if kind == "A" then
				whistles(nil, true) -- post-credits: a single faint whistle far away
				task.wait(3)
			end
		end
		if r ~= roundId then
			return
		end
		fx("Fade", 0, 1.5)
		fx("ScreenText", "The next night begins...", 4, "date")
		task.wait(Config.IntermissionTime)
		if r == roundId then
			Director.startRound()
		end
	end)
end

local function victory()
	S.Victory = true
	S.RespawnToken += 1
	local r = roundId
	local roster = map.Parts.Roster
	local fire = map.Parts.RosterFire
	fire.Enabled = true
	fire.Size = 10
	fx("Sound", "Screech", monster:GetPosition())
	fx("Shake", 1, 2.5)
	fx("Flash", Color3.fromRGB(255, 150, 60), 0.6)
	runScene("Victory")
	task.delay(2.5, function()
		roster.Color = Color3.fromRGB(25, 20, 18)
		hideInteractable(roster)
		roster.Transparency = 0
		task.delay(2, function()
			roster.Transparency = 1
			fire.Enabled = false
		end)
	end)
	local function finish()
		task.wait(1)
		if r == roundId then
			Director.endRound(S.SecretFound and "C" or "A")
		end
	end
	if monster:IsVisible() then
		monster:Die(function()
			task.spawn(finish)
		end)
	else
		task.spawn(finish)
	end
end

local function onRosterHit(_player)
	if not S.Finale or S.Ending or S.Victory then
		return
	end
	local exposed = monster:IsStunned() or monster.State == "Downed" or (monster.State == "Hidden" and os.clock() < S.DownedUntil)
	if not exposed then
		if os.clock() - S.LastResistLine > 6 then
			S.LastResistLine = os.clock()
			runScene("RosterResist")
		end
		return
	end
	S.RosterHits += 1
	GameState:SetAttribute("RosterHits", S.RosterHits)
	map.Parts.RosterFire.Enabled = true
	map.Parts.RosterFire.Size = 2 + S.RosterHits * 2
	refreshObjective()
	if S.RosterHits >= Config.RosterHitsNeeded then
		victory()
	else
		runScene("RosterBurning")
	end
end

local function onMonsterHit(_player)
	if S.Sighting then
		endSighting()
		return
	end
	if monster:FlareHit() ~= "ignored" then
		fx("Sound", "Screech", monster:GetPosition(), 0.6)
	end
end

------------------------------------------------------------------ round wiring

local function onKit(_player)
	if S.KitOpened then
		return
	end
	S.KitOpened = true
	map.Prompts.Kit.Enabled = false
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			Flares.giveGun(p, true)
		end
	end
	notify(string.format("Picked up: Flare Gun (%d flares)", Config.StartingFlares), Color3.fromRGB(255, 150, 90))
	refreshObjective()
	local r = roundId
	task.spawn(function()
		playScene("KitOpened")
		if not waitRound(r, 0.8) then
			return
		end
		map.ShackLamp.Dead = false -- far up the road, a single cabin light flickers on
		if not waitRound(r, 3) then
			return
		end
		whistles(map.Points.Shack, true)
		runScene("PrologueWhistle")
		if not waitRound(r, 1.4) then
			return
		end
		map.ShackLamp.Dead = true
		if S.Chapter < 1 then
			S.Chapter = 1
			GameState:SetAttribute("Chapter", 1)
		end
		refreshObjective()
	end)
end

local function wireRound()
	local P = map.Prompts

	P.Kit.Triggered:Connect(onKit)
	for i, page in pairs(map.Pages) do
		page.Prompt.Triggered:Connect(function(player)
			onPage(i, player)
		end)
	end
	Flares.setupBoxes(map.FlareBoxes)

	-- Chapter 1: the gate
	onZone("RoadLoop", function(player)
		local char = player.Character
		if not char then
			return
		end
		Remotes.Effect:FireClient(player, "Blink")
		char:PivotTo(map.Checkpoints.Gate * CFrame.new(0, 3, 0))
		sceneFor(player, S.RadioFound and "RoadLoopRadio" or "RoadLoop")
	end, false)

	onZone("Gate", function(player)
		if not S.KitOpened then
			onKit(player)
		end
		S.AtGate = true
		if S.Chapter < 1 then
			S.Chapter = 1
			GameState:SetAttribute("Chapter", 1)
		end
		fx("Chapter", Story.Chapters[1])
		setCheckpoint("Gate")
		runScene("GateArrive")
		refreshObjective()
	end)

	P.Radio.Triggered:Connect(function()
		if S.RadioFound or S.Ending then
			return
		end
		S.RadioFound = true
		S.AtGate = true
		P.Radio.Enabled = false
		hideInteractable(map.Parts.Radio)
		fx("Sound", "Radio")
		enablePages(1)
		refreshObjective()
		runScene("GateRadio")
	end)

	-- Chapter 2: the cabins
	onZone("Campfire", function()
		if S.Chapter < 2 then
			return false
		end
		runScene("CabinsArrive")
	end)

	onZone("CabinC", function()
		if S.Chapter < 2 then
			return false
		end
		local r = roundId
		task.spawn(function()
			sceneToken += 1
			fx("Sound", "Knock", map.Points.Tape, 0.4)
			local count = ""
			for _, w in ipairs({ "One...", "two...", "three...", "four...", "five...", "six...", "seven...", "eight...", "nine...", "ten...", "eleven..." }) do
				count = count == "" and w or (count .. " " .. w)
				say("TAPE", count, 1.3)
				if not waitRound(r, 0.85) then
					return
				end
			end
			if not waitRound(r, 0.7) then
				return
			end
			say("WRONG", "...twelve.", 3)
			fx("Sound", "Sting")
			if not waitRound(r, 0.4) then
				return
			end
			for _, l in ipairs(map.Lamps) do
				if l.Group == "CabinC" then
					l.Dead = true
				end
			end
			fx("Shake", 0.5, 0.6)
			-- the first sighting waits until everyone has stepped back outside (or 20 s)
			local started = os.clock()
			while r == roundId and os.clock() - started < 20 do
				local inside = false
				for _, t in ipairs(aliveTargets()) do
					if inZone(t.Root.Position, map.Zones.CabinC) then
						inside = true
					end
				end
				if not inside then
					break
				end
				task.wait(0.3)
			end
			if waitRound(r, 1) and not S.Ending then
				startSighting()
			end
		end)
	end)

	-- Chapter 3: the lake
	onZone("Shore", function()
		if S.Chapter < 3 then
			return false
		end
		runScene("FlareBoxes")
	end)

	onZone("Canoes", function()
		if S.Chapter < 3 then
			return false
		end
		task.spawn(function()
			for _ = 1, 3 do
				fx("Sound", "Knock", map.Points.Canoe)
				task.wait(0.7)
			end
		end)
		runScene("CanoeKnock")
	end)

	P.CanoeFlip.Triggered:Connect(function()
		if S.CanoeFlipped then
			return
		end
		S.CanoeFlipped = true
		P.CanoeFlip.Enabled = false
		local hull = map.Parts.Canoe
		hull.CFrame = hull.CFrame * CFrame.new(1.6, 0.2, 0) * CFrame.Angles(0, 0, math.rad(160))
		hideInteractable(map.Parts.CanoeKeel)
		for _, fp in ipairs(map.Parts.Footprints) do
			fp.Transparency = 0.2
		end
		runScene("CanoeFlip")
	end)

	onZone("Dock", function()
		if S.Chapter < 3 or monster.State ~= "Hidden" then
			return false
		end
		S.LakeChase = true
		local r = roundId
		task.spawn(function()
			local rise = map.Points.LakeRise
			whistles(rise.Position, false)
			runScene("LakeWhistle")
			if not waitRound(r, 1.4) then
				return
			end
			monster:Rise(rise, 2.2)
			fx("Sound", "Splash", rise.Position)
			fx("Shake", 0.6, 1.2)
			task.spawn(function()
				for _, l in ipairs(map.DockLamps) do
					if r ~= roundId then
						return
					end
					l.Dead = true
					task.wait(0.55)
				end
			end)
			runScene("LakeChase")
			refreshObjective()
			P.BarDoor.Enabled = true
			if waitRound(r, 2.4) and monster.State == "Visible" then
				monster:StartHunt(M.HuntDuration)
			end
		end)
	end)

	P.BarDoor.Triggered:Connect(function()
		if S.DoorBarred or not S.LakeChase then
			return
		end
		S.DoorBarred = true
		P.BarDoor.Enabled = false
		local door = map.Parts.BoathouseDoor
		door.Transparency = 0
		door.CanCollide = true
		door.CanQuery = true
		fx("Sound", "Door", door.Position)
		if monster.State == "Hunting" or monster.State == "Visible" then
			monster:EndHunt(map.Points.LakeSink - Vector3.new(0, 14, 0)) -- walks back into the fog
		end
		lakeChaseOver(true)
		local r = roundId
		task.delay(18, function()
			if r == roundId then
				door.Transparency = 1
				door.CanCollide = false
				door.CanQuery = false
				notify("The boathouse door creaks open on its own...")
			end
		end)
	end)

	-- Chapter 4: the mess hall
	for _, pp in ipairs(P.Fuses) do
		pp.Enabled = false
	end
	P.Key.Enabled = false

	onZone("MessHall", function()
		if S.Chapter < 4 then
			return false
		end
		runScene("MessHall")
	end)

	for i, pp in ipairs(P.Fuses) do
		pp.Triggered:Connect(function()
			if S.Ending or not pp.Enabled then
				return
			end
			pp.Enabled = false
			hideInteractable(map.Parts.Fuses[i])
			S.Fuses += 1
			fx("Sound", "Pickup")
			notify(string.format("Fuse found (%d/%d)", S.Fuses, Config.FusesNeeded), Color3.fromRGB(255, 220, 110))
			refreshObjective()
		end)
	end

	P.Generator.Triggered:Connect(function(player)
		if S.GeneratorOn or S.Ending then
			return
		end
		if S.Chapter < 4 then
			Remotes.Notify:FireClient(player, "The generator is dead. There's nothing to plug it into... yet.")
			return
		end
		if S.Fuses < Config.FusesNeeded then
			Remotes.Notify:FireClient(player, string.format("The generator needs %d fuses (%d/%d)", Config.FusesNeeded, S.Fuses, Config.FusesNeeded))
			return
		end
		S.GeneratorOn = true
		P.Generator.Enabled = false
		fx("Sound", "Generator", map.Points.Generator)
		enablePages(6, 7)
		refreshObjective()
		local r = roundId
		task.spawn(function()
			if not waitRound(r, 1.5) then
				return
			end
			playScene("PA")
			if r ~= roundId or S.Ending then
				return
			end
			S.RespawnToken += 1
			monster:Hide()
			local kitchen = map.Points.Kitchen
			whistles(kitchen.Position, false)
			runScene("KitchenWhistle")
			if not waitRound(r, 2) or S.Ending then
				return
			end
			monster:Appear(kitchen)
			fx("Sound", "Door", kitchen.Position)
			fx("Shake", 0.8, 0.8)
			S.BigChase = true
			refreshObjective()
			runScene("BigChase")
			monster:StartHunt(75)
		end)
	end)

	P.Key.Triggered:Connect(function()
		if S.HasKey then
			return
		end
		S.HasKey = true
		P.Key.Enabled = false
		hideInteractable(map.Parts.Key)
		fx("Sound", "Pickup")
		notify("Found: a rusty key labeled DIRECTOR", GOLD)
		runScene("GotKey")
		refreshObjective()
	end)

	-- Chapter 5 (secret): the director's office
	P.OfficeDoor.Triggered:Connect(function(player)
		if S.OfficeOpen then
			return
		end
		local door = map.Parts.OfficeDoor
		fx("Sound", "Door", door.Position)
		if not S.HasKey then
			Remotes.Notify:FireClient(player, "Locked. The keyhole is stamped DIRECTOR.")
			return
		end
		S.OfficeOpen = true
		P.OfficeDoor.Enabled = false
		local hinge = door.CFrame * CFrame.new(-door.Size.X / 2, 0, 0)
		door.CFrame = hinge * CFrame.Angles(0, math.rad(100), 0) * CFrame.new(door.Size.X / 2, 0, 0)
		fx("Chapter", Story.Chapters[5])
		enablePages(9)
	end)

	-- Chapter 6: the flagpole
	onZone("Flagpole", function()
		if S.Chapter < 6 then
			return false
		end
		S.AtFlagpole = true
		tweenAtmosphere({ Density = 0.22, Haze = 1 }, 6) -- the fog pulls back; the moon is out
		runScene("Roster")
		enablePages(8)
		refreshObjective()
	end)
end

local function prologue(r)
	refreshObjective()
	if not waitRound(r, 1.2) then
		return
	end
	fx("ScreenText", "November 12.   11:47 PM.", 4, "date")
	if not waitRound(r, 4.8) then
		return
	end
	fx("Chapter", Story.Chapters[0])
	if not waitRound(r, 2) then
		return
	end
	runScene("Prologue")
end

function Director.startRound()
	roundId += 1
	local r = roundId
	sceneToken += 1
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			p.Character:Destroy()
		end
	end
	if monster then
		monster:Destroy()
	end
	S = newState()
	zoneHandlers = {}
	map = MapBuilder.build()
	MapBuilder.setupLighting()
	monster = Monster.new(map.Folder, aliveTargets)
	monster.OnCatch = countPlayer
	monster.OnDowned = onDowned
	monster.OnHuntEnded = onHuntEnded
	wireRound()
	setCheckpoint("Car")
	GameState:SetAttribute("Pages", 0)
	GameState:SetAttribute("Phase", "")
	GameState:SetAttribute("RosterHits", 0)
	GameState:SetAttribute("Chapter", 0)
	Monetization.ResetRoundStats()
	for _, p in ipairs(Players:GetPlayers()) do
		p:SetAttribute("Flares", Flares.starting(p))
		task.spawn(spawnPlayer, p)
	end
	fx("Fade", 1, 2.5)
	task.spawn(prologue, r)
	task.spawn(lampLoop, r)
	task.spawn(zoneLoop, r)
	task.spawn(huntLoop, r)
end

------------------------------------------------------------------ boot

local function onPlayerAdded(player)
	player:SetAttribute("Flares", Flares.starting(player))
	player:SetAttribute("Counted", false)
	player.CameraMaxZoomDistance = 14
	player.DevEnableMouseLock = false -- Shift is the run key
	player.CharacterAdded:Connect(function(char)
		onCharacter(player, char)
	end)
	task.spawn(Monetization.SetupPlayer, player)
	if map then
		task.spawn(spawnPlayer, player)
	end
end

function Director.start(remotes)
	Remotes = remotes

	Monetization.ProductHandlers.SecondChance = Director.revive
	Monetization.ProductHandlers.FlarePack = function(player)
		Flares.give(player, Config.FlarePackAmount)
		Remotes.Notify:FireClient(player, string.format("+%d flares", Config.FlarePackAmount), GOLD)
		return true
	end
	Monetization.OnPassGranted = function(player, name)
		if name == "SurvivorKit" then
			Flares.give(player, Config.SurvivorKitBonusFlares)
		end
		local head = player.Character and player.Character:FindFirstChild("Head")
		local beam = head and head:FindFirstChild("Flashlight")
		if beam then
			styleFlashlight(player, beam)
		end
	end
	Monetization.init()

	Flares.init(Remotes, {
		GetMonster = function()
			return monster
		end,
		GetRoster = function()
			return map and map.Parts.Roster
		end,
		IsFinale = function()
			return S.Finale
		end,
		CanFire = function(player)
			return not S.Counted[player] and not S.Ending
		end,
		OnMonsterHit = onMonsterHit,
		OnRosterHit = onRosterHit,
	})

	Remotes.Flashlight.OnServerEvent:Connect(function(player, on)
		local head = player.Character and player.Character:FindFirstChild("Head")
		local beam = head and head:FindFirstChild("Flashlight")
		if beam then
			beam.Enabled = on == true
		end
	end)
	Remotes.LookedAway.OnServerEvent:Connect(function()
		if S.Sighting then
			endSighting()
		end
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		S.Counted[player] = nil
		task.defer(checkWipe)
	end)
	for _, p in ipairs(Players:GetPlayers()) do
		onPlayerAdded(p)
	end
	Director.startRound()
end

return Director
