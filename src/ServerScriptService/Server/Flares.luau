-- Flare gun: ammo, firing, server-side hit detection and the red flare boxes.
-- Clients draw the flare itself (Effect "Flare"); the server decides what it hit.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Flares = {}
Flares.ToolName = "Flare Gun"

local remotes
local ctx -- callbacks supplied by the Director
local cooldowns = {}

function Flares.starting(player)
	local n = Config.StartingFlares
	if player:GetAttribute("SurvivorKit") then
		n += Config.SurvivorKitBonusFlares
	end
	return n
end

function Flares.give(player, amount)
	player:SetAttribute("Flares", (player:GetAttribute("Flares") or 0) + amount)
end

function Flares.giveGun(player, equip)
	local char = player.Character
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end
	if backpack:FindFirstChild(Flares.ToolName) or (char and char:FindFirstChild(Flares.ToolName)) then
		return
	end
	local tool = Instance.new("Tool")
	tool.Name = Flares.ToolName
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ToolTip = "Click / tap to fire a flare"
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.45, 0.9, 1.6)
	handle.Color = Color3.fromRGB(225, 75, 30)
	handle.Material = Enum.Material.SmoothPlastic
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool
	tool.Parent = backpack
	if equip and char then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum:EquipTool(tool)
		end
	end
end

local function onFire(player, target)
	if typeof(target) ~= "Vector3" or target ~= target then
		return
	end
	if not ctx.CanFire(player) then
		return
	end
	local char = player.Character
	local tool = char and char:FindFirstChild(Flares.ToolName)
	local head = char and char:FindFirstChild("Head")
	if not tool or not head then
		return
	end
	local now = os.clock()
	if (cooldowns[player] or 0) > now then
		return
	end
	cooldowns[player] = now + Config.FlareCooldown * 0.8 -- small allowance for latency
	local ammo = player:GetAttribute("Flares") or 0
	if ammo <= 0 then
		remotes.Notify:FireClient(player, "Out of flares! Find a red flare box.")
		return
	end
	player:SetAttribute("Flares", ammo - 1)

	local handle = tool:FindFirstChild("Handle")
	local origin = handle and handle.Position or head.Position
	if (origin - head.Position).Magnitude > 8 then
		origin = head.Position
	end
	local dir = target - origin
	if dir.Magnitude < 0.5 then
		return
	end
	local unit = dir.Unit

	local ignore = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	local monster = ctx.GetMonster()
	if monster then
		table.insert(ignore, monster.Model)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local result = workspace:Raycast(origin, unit * Config.FlareRange, params)

	local hitDist = result and result.Distance or Config.FlareRange
	local kind = result and "ground" or "air"
	local along = monster and monster:RayHit(origin, unit, hitDist + 1, Config.FlareHitRadius)
	if along then
		kind, hitDist = "monster", along
	elseif result and result.Instance == ctx.GetRoster() then
		kind = "roster"
	end
	remotes.Effect:FireAllClients("Flare", origin, origin + unit * hitDist, kind)
	task.delay(hitDist / Config.FlareSpeed, function()
		if kind == "monster" then
			ctx.OnMonsterHit(player)
		elseif kind == "roster" then
			ctx.OnRosterHit(player)
		end
	end)
end

function Flares.setupBoxes(boxes)
	for _, box in ipairs(boxes) do
		local closedLid = box.Lid.CFrame
		box.Prompt.Triggered:Connect(function(player)
			if box.Empty or not ctx.CanFire(player) then
				return
			end
			box.Empty = true
			box.Prompt.Enabled = false
			box.Light.Enabled = false
			box.Lid.CFrame = closedLid * CFrame.new(0, 0.7, 1) * CFrame.Angles(math.rad(-75), 0, 0)
			Flares.give(player, Config.FlareBoxAmount)
			remotes.Notify:FireClient(player, string.format("+%d flares", Config.FlareBoxAmount), Color3.fromRGB(255, 150, 90))
			remotes.Effect:FireClient(player, "Sound", "Pickup")
			task.delay(ctx.IsFinale() and Config.FlareBoxRespawnFinale or Config.FlareBoxRespawn, function()
				if not box.Body.Parent then
					return
				end
				box.Empty = false
				box.Prompt.Enabled = true
				box.Light.Enabled = true
				box.Lid.CFrame = closedLid
			end)
		end)
	end
end

function Flares.init(remoteFolder, context)
	remotes = remoteFolder
	ctx = context
	remotes.FireFlare.OnServerEvent:Connect(onFire)
	Players.PlayerRemoving:Connect(function(player)
		cooldowns[player] = nil
	end)
end

return Flares
