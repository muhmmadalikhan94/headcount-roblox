-- HEADCOUNT client: HUD, sounds, controls (run, flashlight, flare gun), camera effects, spectating, shop.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local MarketplaceService = game:GetService("MarketplaceService")
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local mouse = player:GetMouse()

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Story = require(Shared:WaitForChild("Story"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local UI = require(script.Parent:WaitForChild("UI"))

local isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local ui = UI.build(player:WaitForChild("PlayerGui"), isTouch)

local effects = Instance.new("Folder")
effects.Name = "LocalEffects"
effects.Parent = workspace
mouse.TargetFilter = effects

task.spawn(function()
	for _ = 1, 10 do
		if pcall(StarterGui.SetCore, StarterGui, "ResetButtonCallback", false) then
			break
		end
		task.wait(1)
	end
end)

------------------------------------------------------------------ sound

local function playSound(key, pos, volume)
	local def = Config.Sounds[key]
	if not def or def.Id == "" then
		return nil
	end
	local s = Instance.new("Sound")
	s.SoundId = def.Id
	s.Volume = (def.Volume or 1) * (volume or 1)
	s.PlaybackSpeed = def.Speed or 1
	if pos then
		local a = Instance.new("Attachment")
		a.Parent = workspace.Terrain
		a.WorldPosition = pos
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.RollOffMinDistance = 12
		s.RollOffMaxDistance = def.Range or 260
		s.Parent = a
		Debris:AddItem(a, 12)
	else
		s.Parent = SoundService
		Debris:AddItem(s, 12)
	end
	s:Play()
	return s
end

local function loopSound(key)
	local def = Config.Sounds[key]
	if not def or def.Id == "" then
		return nil
	end
	local s = Instance.new("Sound")
	s.SoundId = def.Id
	s.Looped = true
	s.Volume = def.Volume or 1
	s.PlaybackSpeed = def.Speed or 1
	s.Parent = SoundService
	s:Play()
	return s
end

loopSound("Ambience")
local heartbeat = loopSound("Heartbeat")
if heartbeat then
	heartbeat.Volume = 0
end

------------------------------------------------------------------ camera shake

local shakeUntil, shakeMag, dangerShake = 0, 0, 0

local function shake(magnitude, seconds)
	local now = os.clock()
	shakeMag = now < shakeUntil and math.max(shakeMag, magnitude) or magnitude
	shakeUntil = math.max(shakeUntil, now + seconds)
end

RunService:BindToRenderStep("HeadcountShake", Enum.RenderPriority.Camera.Value + 1, function()
	local mag = os.clock() < shakeUntil and shakeMag or 0
	mag = math.max(mag, dangerShake)
	if mag > 0 then
		camera.CFrame = camera.CFrame * CFrame.Angles(math.rad((math.random() - 0.5) * mag * 3), math.rad((math.random() - 0.5) * mag * 3), 0)
	end
end)

local function whistles(pos, distant)
	task.spawn(function()
		for _ = 1, 3 do
			playSound("Whistle", (not distant) and pos or nil, distant and 0.3 or 1)
			task.wait(0.55)
		end
	end)
	shake(distant and 0.1 or 0.3, 0.6)
end

------------------------------------------------------------------ flares (visuals)

local function flareVisual(origin, hitPos, kind)
	local dist = (hitPos - origin).Magnitude
	local travel = math.max(dist / Config.FlareSpeed, 0.05)
	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(0.7, 0.7, 0.7)
	ball.Material = Enum.Material.Neon
	ball.Color = Color3.fromRGB(255, 110, 50)
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.CastShadow = false
	ball.CFrame = CFrame.new(origin)
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 120, 60)
	glow.Range = 18
	glow.Brightness = 3
	glow.Shadows = true
	glow.Parent = ball
	local fire = Instance.new("Fire")
	fire.Size = 2
	fire.Heat = 6
	fire.Color = Color3.fromRGB(255, 140, 50)
	fire.SecondaryColor = Color3.fromRGB(255, 50, 0)
	fire.Parent = ball
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position = Vector3.new(0, 0.25, 0), Vector3.new(0, -0.25, 0)
	a0.Parent, a1.Parent = ball, ball
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Lifetime = 0.35
	trail.LightEmission = 1
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 170, 80), Color3.fromRGB(255, 60, 20))
	trail.Transparency = NumberSequence.new(0, 1)
	trail.Parent = ball
	ball.Parent = effects
	playSound("FlareFire", origin)
	TweenService:Create(ball, TweenInfo.new(travel, Enum.EasingStyle.Linear), { CFrame = CFrame.new(hitPos) }):Play()
	task.delay(travel, function()
		if kind == "monster" or kind == "roster" then
			glow.Range, glow.Brightness, fire.Size = 28, 6, 7
			if (hitPos - camera.CFrame.Position).Magnitude < 60 then
				shake(0.25, 0.3)
			end
			Debris:AddItem(ball, 0.6)
		elseif kind == "air" then
			Debris:AddItem(ball, 0.2)
		else
			-- a flare burning on the ground for a while
			trail.Enabled = false
			Debris:AddItem(ball, 9)
			local started = os.clock()
			while ball.Parent and os.clock() - started < 9 do
				glow.Brightness = 2.2 + math.random() * 1.6
				task.wait(0.08)
			end
		end
	end)
end

------------------------------------------------------------------ flare gun input

local hooked = setmetatable({}, { __mode = "k" })
local lastFire = 0

local function fireFlare()
	if player:GetAttribute("Counted") then
		return
	end
	local now = os.clock()
	if now - lastFire < Config.FlareCooldown then
		return
	end
	lastFire = now
	if (player:GetAttribute("Flares") or 0) <= 0 then
		ui.Toast("Out of flares! Find a red flare box.", Color3.fromRGB(255, 90, 90))
		return
	end
	local ray = camera:ScreenPointToRay(mouse.X, mouse.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character, effects }
	local result = workspace:Raycast(ray.Origin, ray.Direction * 500, params)
	Remotes.FireFlare:FireServer(result and result.Position or (ray.Origin + ray.Direction * 500))
end

local hasGun = false
local function refreshFlares()
	ui.SetFlares(player:GetAttribute("Flares") or 0, hasGun)
end

local function hookTool(tool)
	if not tool:IsA("Tool") or tool.Name ~= "Flare Gun" or hooked[tool] then
		return
	end
	hooked[tool] = true
	hasGun = true
	refreshFlares()
	tool.Activated:Connect(fireFlare)
	tool.Equipped:Connect(function()
		mouse.Icon = "rbxasset://textures/GunCursor.png"
	end)
	tool.Unequipped:Connect(function()
		mouse.Icon = ""
	end)
end

local function watch(container)
	for _, c in ipairs(container:GetChildren()) do
		hookTool(c)
	end
	container.ChildAdded:Connect(hookTool)
end

------------------------------------------------------------------ run + flashlight

local sprinting, exhausted = false, false
local stamina = Config.StaminaMax
local flashlightOn = true

ContextActionService:BindAction("HeadcountRun", function(_, state)
	if state == Enum.UserInputState.Begin then
		sprinting = true
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		sprinting = false
	end
	return Enum.ContextActionResult.Pass
end, true, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
ContextActionService:SetTitle("HeadcountRun", "RUN")
ContextActionService:SetPosition("HeadcountRun", UDim2.new(1, -190, 1, -130))

ContextActionService:BindAction("HeadcountLight", function(_, state)
	if state == Enum.UserInputState.Begin then
		flashlightOn = not flashlightOn
		Remotes.Flashlight:FireServer(flashlightOn)
		playSound("Pickup", nil, 0.4)
	end
	return Enum.ContextActionResult.Pass
end, true, Enum.KeyCode.F, Enum.KeyCode.ButtonY)
ContextActionService:SetTitle("HeadcountLight", "LIGHT")
ContextActionService:SetPosition("HeadcountLight", UDim2.new(1, -250, 1, -70))

player.CharacterAdded:Connect(function(char)
	flashlightOn = true
	stamina = Config.StaminaMax
	hasGun = false
	refreshFlares()
	watch(char)
	watch(player:WaitForChild("Backpack"))
end)
if player.Character then
	watch(player.Character)
	watch(player:WaitForChild("Backpack"))
end

------------------------------------------------------------------ spectating

local spectateIndex = 1

local function spectate(step)
	if not player:GetAttribute("Counted") then
		return
	end
	local others = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
		if p ~= player and not p:GetAttribute("Counted") and hum and hum.Health > 0 then
			table.insert(others, { Player = p, Humanoid = hum })
		end
	end
	if #others == 0 then
		ui.SetSpectating(nil)
		return
	end
	spectateIndex = ((spectateIndex - 1 + (step or 0)) % #others) + 1
	local t = others[spectateIndex]
	camera.CameraSubject = t.Humanoid
	ui.SetSpectating(t.Player.DisplayName)
end

ui.OnSpectate = spectate
ui.OnSecondChance = function()
	if Config.Products.SecondChance ~= 0 then
		MarketplaceService:PromptProductPurchase(player, Config.Products.SecondChance)
	else
		ui.Toast("Second Chance isn't set up yet (Config.Products.SecondChance)")
	end
end

task.spawn(function()
	while true do
		task.wait(1.5)
		spectate(0)
	end
end)

------------------------------------------------------------------ monster proximity, sighting, stamina

local monsterModel
local function getMonster()
	if monsterModel and monsterModel.Parent then
		return monsterModel
	end
	local camp = workspace:FindFirstChild("Camp")
	monsterModel = camp and camp:FindFirstChild("TheTwelfth")
	return monsterModel
end

local danger, seenFor, reported = 0, 0, false

RunService.Heartbeat:Connect(function(dt)
	local m = getMonster()
	local root = m and m.PrimaryPart
	local target = 0
	if root and root.Position.Y > -100 then
		local d = (root.Position - camera.CFrame.Position).Magnitude
		target = math.clamp(1 - (d - 8) / 50, 0, 1)
	end
	danger += (target - danger) * math.min(1, dt * 4)
	ui.SetDanger(danger)
	dangerShake = danger > 0.55 and (danger - 0.55) * 0.5 or 0
	if heartbeat then
		heartbeat.Volume = danger * Config.Sounds.Heartbeat.Volume
	end

	-- the first sighting: it's there... look away and it's gone
	if ReplicatedStorage:GetAttribute("Phase") == "Sighting" then
		local head = m and m:FindFirstChild("Head")
		if head and not reported then
			local p, onScreen = camera:WorldToViewportPoint(head.Position)
			if onScreen and p.Z > 0 then
				seenFor += dt
			elseif seenFor > 0.6 then
				reported = true
				Remotes.LookedAway:FireServer()
			end
		end
	else
		seenFor, reported = 0, false
	end

	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 then
		local running = sprinting and not exhausted and hum.MoveDirection.Magnitude > 0.1
		if running then
			stamina = math.max(0, stamina - Config.StaminaDrain * dt)
			if stamina <= 0 then
				exhausted = true
			end
		else
			stamina = math.min(Config.StaminaMax, stamina + Config.StaminaRegen * dt)
			if exhausted and stamina > Config.StaminaMax * 0.3 then
				exhausted = false
			end
		end
		hum.WalkSpeed = running and Config.SprintSpeed or Config.WalkSpeed
		ui.SetStamina(stamina / Config.StaminaMax)
	end
end)

------------------------------------------------------------------ server events

Remotes.Dialogue.OnClientEvent:Connect(function(speaker, text, seconds)
	ui.ShowSubtitle(speaker, text, seconds)
	local spk = Story.Speakers[speaker]
	if spk and spk.Radio then
		playSound("Radio", nil, 0.6)
	end
end)

Remotes.PageFound.OnClientEvent:Connect(function(index, title, text, count, total)
	ui.ShowPage(index, title, text, count, total)
end)

Remotes.Notify.OnClientEvent:Connect(function(text, color)
	ui.Toast(text, color)
end)

Remotes.Effect.OnClientEvent:Connect(function(kind, a, b, c)
	if kind == "Sound" then
		playSound(a, b, c)
	elseif kind == "Whistles" then
		whistles(a, b)
	elseif kind == "Shake" then
		shake(a, b)
	elseif kind == "Flash" then
		ui.Flash(a, b)
	elseif kind == "ScreenText" then
		ui.ShowScreenText(a, b, c)
	elseif kind == "Chapter" then
		ui.ShowChapter(a)
	elseif kind == "Jumpscare" then
		ui.Jumpscare()
		playSound("Jumpscare")
		shake(1.2, 1)
	elseif kind == "Flare" then
		flareVisual(a, b, c)
	elseif kind == "Fade" then
		ui.Fade(a, b)
	elseif kind == "Blink" then
		ui.Blink()
	elseif kind == "Ending" then
		ui.ShowEnding(a, b)
	elseif kind == "Roster" then
		ui.ShowRoster(a)
	end
end)

------------------------------------------------------------------ state

local function refreshState()
	ui.SetObjective(ReplicatedStorage:GetAttribute("Objective") or "")
	ui.SetPages(ReplicatedStorage:GetAttribute("Pages") or 0, Config.TotalPages)
end
ReplicatedStorage:GetAttributeChangedSignal("Objective"):Connect(refreshState)
ReplicatedStorage:GetAttributeChangedSignal("Pages"):Connect(refreshState)
ReplicatedStorage:GetAttributeChangedSignal("Phase"):Connect(function()
	if ReplicatedStorage:GetAttribute("Phase") ~= "Ending" then
		ui.HideEnding()
	end
end)
refreshState()

player:GetAttributeChangedSignal("Flares"):Connect(refreshFlares)
player:GetAttributeChangedSignal("Counted"):Connect(function()
	local counted = player:GetAttribute("Counted") == true
	ui.SetCounted(counted)
	if counted then
		task.delay(1.5, spectate, 0)
	end
end)

------------------------------------------------------------------ shop + VIP tag

local shopItems = {
	{ Name = "Survivor Kit", Description = "+2 starting flares every night and a stronger flashlight.", Kind = "Pass", Id = Config.GamePasses.SurvivorKit },
	{ Name = "VIP", Description = "Golden flashlight beam and a [VIP] chat tag.", Kind = "Pass", Id = Config.GamePasses.VIP },
	{ Name = "Flare Pack", Description = string.format("+%d flares right now.", Config.FlarePackAmount), Kind = "Product", Id = Config.Products.FlarePack },
	{ Name = "Second Chance", Description = "Revive instantly after being counted.", Kind = "Product", Id = Config.Products.SecondChance },
}
local setPrice = ui.BuildShop(shopItems, function(item)
	if item.Id == 0 then
		ui.Toast(item.Name .. " isn't set up yet (add its ID in Config)")
	elseif item.Kind == "Pass" then
		MarketplaceService:PromptGamePassPurchase(player, item.Id)
	else
		MarketplaceService:PromptProductPurchase(player, item.Id)
	end
end)
for i, item in ipairs(shopItems) do
	if item.Id ~= 0 then
		task.spawn(function()
			local infoType = item.Kind == "Pass" and Enum.InfoType.GamePass or Enum.InfoType.Product
			local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, item.Id, infoType)
			if ok and info and info.PriceInRobux then
				setPrice(i, "R$ " .. info.PriceInRobux)
			end
		end)
	end
end

TextChatService.OnIncomingMessage = function(message)
	local props = Instance.new("TextChatMessageProperties")
	local source = message.TextSource
	local sender = source and Players:GetPlayerByUserId(source.UserId)
	if sender and sender:GetAttribute("VIP") then
		props.PrefixText = '<font color="#FFD24A">[VIP]</font> ' .. message.PrefixText
	end
	return props
end

------------------------------------------------------------------ start

ui.Intro(Story.Quote, Story.QuoteSource)
ui.Fade(1, 2.5)
