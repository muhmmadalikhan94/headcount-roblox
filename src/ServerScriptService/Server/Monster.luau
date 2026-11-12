-- The Twelfth: a tall, faceless black figure with two glowing red eyes.
-- It is anchored and glides (moved every frame), using PathfindingService to get around walls.
-- The Director decides when it appears, hunts, leaves and respawns; this module only does the doing.

local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local M = Config.Monster

local Monster = {}
Monster.__index = Monster

local HIDDEN = CFrame.new(0, -300, 0)
local ROOT_HEIGHT = 5.5 -- root sits at hip height above its feet
local HEAD_OFFSET = CFrame.new(0, 6, 0)
local BLACK = Color3.fromRGB(8, 8, 10)
local EYE_RED = Color3.fromRGB(255, 20, 20)

local BODY = {
	{ "LeftLeg", Vector3.new(0.9, 5.6, 0.9), CFrame.new(-0.7, -2.8, 0) },
	{ "RightLeg", Vector3.new(0.9, 5.6, 0.9), CFrame.new(0.7, -2.8, 0) },
	{ "Torso", Vector3.new(2.6, 4.4, 1.2), CFrame.new(0, 2.2, 0) },
	{ "LeftArm", Vector3.new(0.7, 6.8, 0.7), CFrame.new(-1.75, 0.8, 0) * CFrame.Angles(0, 0, math.rad(-4)) },
	{ "RightArm", Vector3.new(0.7, 6.8, 0.7), CFrame.new(1.75, 0.8, 0) * CFrame.Angles(0, 0, math.rad(4)) },
	{ "Neck", Vector3.new(0.6, 0.9, 0.6), CFrame.new(0, 4.7, 0) },
}

function Monster.new(parent, getTargets)
	local self = setmetatable({}, Monster)
	self.GetTargets = getTargets
	self.Speed = M.BaseSpeed
	self.State = "Hidden" -- Hidden, Visible, Hunting, Leaving, Downed, Dead
	self.Hits = 0
	self.StunnedUntil = 0
	self.PauseUntil = 0
	self.CFrame = HIDDEN
	self.HeadTwitch = CFrame.identity
	self.NextTwitch = 0
	self.Fade = 0
	self.Parts, self.Offsets, self.FollowHead, self.Base, self.Eyes = {}, {}, {}, {}, {}
	self.Alive = true

	local model = Instance.new("Model")
	model.Name = "TheTwelfth"
	self.Model = model

	local function add(name, size, offset, color, material, followHead)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color or BLACK
		p.Material = material or Enum.Material.SmoothPlastic
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CFrame = HIDDEN * offset
		p.Parent = model
		table.insert(self.Parts, p)
		table.insert(self.Offsets, offset)
		table.insert(self.FollowHead, followHead == true)
		self.Base[p] = 0
		return p
	end

	local root = add("Root", Vector3.new(2, 2, 1), CFrame.identity)
	root.Transparency = 1
	self.Base[root] = 1
	self.Root = root
	model.PrimaryPart = root
	for _, b in ipairs(BODY) do
		local p = add(b[1], b[2], b[3])
		if b[1] == "Torso" then
			self.Torso = p
		end
	end
	local head = add("Head", Vector3.new(1.5, 2.1, 1.5), CFrame.identity, nil, nil, true)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Head
	mesh.Parent = head
	self.Head = head
	for _, x in ipairs({ -0.33, 0.33 }) do
		table.insert(self.Eyes, add("Eye", Vector3.new(0.32, 0.18, 0.1), CFrame.new(x, 0.25, -0.74), EYE_RED, Enum.Material.Neon, true))
	end
	local glow = Instance.new("PointLight")
	glow.Color = EYE_RED
	glow.Range = 10
	glow.Brightness = 3
	glow.Parent = self.Eyes[1]
	self.EyeLight = glow
	add("Whistle", Vector3.new(0.25, 0.25, 0.6), CFrame.new(0, 3.3, -0.7), Color3.fromRGB(190, 190, 195), Enum.Material.Metal)

	local fire = Instance.new("Fire")
	fire.Enabled = false
	fire.Size = 7
	fire.Heat = 14
	fire.Color = Color3.fromRGB(255, 130, 40)
	fire.SecondaryColor = Color3.fromRGB(255, 40, 0)
	fire.Parent = self.Torso
	self.Fire = fire

	self.RayParams = RaycastParams.new()
	self.RayParams.FilterType = Enum.RaycastFilterType.Exclude
	self.RayParams.IgnoreWater = false
	self.RayParams.RespectCanCollide = true
	self.Path = PathfindingService:CreatePath({ AgentRadius = 1.5, AgentHeight = 6, AgentCanJump = false, WaypointSpacing = 6 })

	model.Parent = parent
	self.Conn = RunService.Heartbeat:Connect(function(dt)
		self:_step(dt)
	end)
	task.spawn(function()
		self:_pathLoop()
	end)
	return self
end

------------------------------------------------------------------ internals

function Monster:_apply(rootCf)
	local headCf = rootCf * HEAD_OFFSET * self.HeadTwitch
	local cfs = table.create(#self.Parts)
	for i, _ in ipairs(self.Parts) do
		cfs[i] = (self.FollowHead[i] and headCf or rootCf) * self.Offsets[i]
	end
	workspace:BulkMoveTo(self.Parts, cfs, Enum.BulkMoveMode.FireAllEvents)
end

function Monster:_setFade(alpha)
	self.Fade = alpha
	for _, p in ipairs(self.Parts) do
		p.Transparency = math.max(self.Base[p], alpha)
	end
end

function Monster:_fadeTo(alpha, duration, delay)
	if self.FadeTween then
		self.FadeTween:Cancel()
	end
	local value = Instance.new("NumberValue")
	value.Value = self.Fade
	value.Changed:Connect(function(v)
		self:_setFade(v)
	end)
	local tween = TweenService:Create(value, TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false, delay or 0), { Value = alpha })
	self.FadeTween = tween
	tween.Completed:Connect(function()
		value:Destroy()
	end)
	tween:Play()
end

function Monster:_feet()
	return self.CFrame.Position - Vector3.new(0, ROOT_HEIGHT, 0)
end

function Monster:_groundY(feet)
	local ignore = { self.Model }
	for _, t in ipairs(self.GetTargets()) do
		local character = t.Root.Parent
		if character then
			table.insert(ignore, character)
		end
	end
	self.RayParams.FilterDescendantsInstances = ignore
	local result = workspace:Raycast(feet + Vector3.new(0, 4, 0), Vector3.new(0, -30, 0), self.RayParams)
	return result and result.Position.Y
end

-- Turns a ground-level CFrame into a root CFrame standing on whatever is below it.
function Monster:_rootAt(groundCf)
	local pos = groundCf.Position
	local g = self:_groundY(pos) or pos.Y
	return CFrame.new(pos.X, g + ROOT_HEIGHT, pos.Z) * groundCf.Rotation
end

function Monster:_step(dt)
	if self.State == "Hidden" or self.State == "Dead" then
		return
	end
	local now = os.clock()
	if now >= self.NextTwitch then
		self.NextTwitch = now + math.random(12, 40) / 10
		self.HeadTwitch = CFrame.Angles(math.rad(math.random(-20, 20)), math.rad(math.random(-35, 35)), math.rad(math.random(-40, 40)))
		self.TwitchEnds = now + 0.18
	elseif self.TwitchEnds and now > self.TwitchEnds then
		self.HeadTwitch = CFrame.identity
		self.TwitchEnds = nil
	end

	local s = self.Scripted
	if s then
		local a = math.clamp((now - s.Start) / s.Duration, 0, 1)
		self.CFrame = s.From:Lerp(s.To, a)
		if a >= 1 then
			self.Scripted = nil
			if s.Done then
				task.spawn(s.Done)
			end
		end
	elseif self.State == "Hunting" then
		self:_hunt(dt, now)
	end

	local cf = self.CFrame
	if now < self.StunnedUntil then
		cf = cf * CFrame.new(math.random(-10, 10) / 50, 0, math.random(-10, 10) / 50) * CFrame.Angles(0, 0, math.rad(math.random(-8, 8)))
	end
	self:_apply(cf)
end

function Monster:_hunt(dt, now)
	if self.HuntEndsAt and now >= self.HuntEndsAt then
		self:EndHunt()
		return
	end
	if now < self.StunnedUntil or now < self.PauseUntil then
		return
	end
	local feet = self:_feet()
	local best, bestDist
	for _, t in ipairs(self.GetTargets()) do
		local pos = t.Root.Position
		local flat = Vector3.new(pos.X - feet.X, 0, pos.Z - feet.Z).Magnitude
		if flat <= M.CatchRange and math.abs(pos.Y - feet.Y) < 9 then
			self.PauseUntil = now + 1.6 -- stands still while it crosses the name off
			if self.OnCatch then
				task.spawn(self.OnCatch, t.Player)
			end
			return
		end
		local d = (pos - feet).Magnitude
		if not bestDist or d < bestDist then
			best, bestDist = t, d
		end
	end
	self.Target = best
	if not best then
		return
	end

	local goal = best.Root.Position
	local wps = self.Waypoints
	if wps then
		local wp = wps[self.WaypointIndex]
		while wp and Vector3.new(wp.X - feet.X, 0, wp.Z - feet.Z).Magnitude < 2.5 do
			self.WaypointIndex += 1
			wp = wps[self.WaypointIndex]
		end
		if wp then
			goal = wp
		end
	end
	local delta = Vector3.new(goal.X - feet.X, 0, goal.Z - feet.Z)
	local dist = delta.Magnitude
	if dist < 0.05 then
		return
	end
	local dir = delta / dist
	local nextFeet = feet + dir * math.min(dist, self.Speed * dt)
	local ground = self:_groundY(nextFeet)
	if ground then
		nextFeet = Vector3.new(nextFeet.X, feet.Y + (ground - feet.Y) * math.min(1, dt * 12), nextFeet.Z)
	end
	local rootPos = nextFeet + Vector3.new(0, ROOT_HEIGHT, 0)
	self.CFrame = CFrame.lookAt(rootPos, rootPos + dir)
end

function Monster:_pathLoop()
	while self.Alive do
		local target = self.Target
		if self.State == "Hunting" and target and not self.Scripted then
			local ok = pcall(function()
				self.Path:ComputeAsync(self:_feet(), target.Root.Position)
			end)
			if ok and self.Path.Status == Enum.PathStatus.Success then
				local wps = {}
				for _, w in ipairs(self.Path:GetWaypoints()) do
					table.insert(wps, w.Position)
				end
				self.Waypoints = wps
				self.WaypointIndex = 2
			else
				self.Waypoints = nil -- no path: glide straight at them
			end
			task.wait(0.5)
		else
			self.Waypoints = nil
			task.wait(0.25)
		end
	end
end

------------------------------------------------------------------ public

function Monster:IsVisible()
	return self.State ~= "Hidden" and self.State ~= "Dead"
end

function Monster:IsShootable()
	return self.State == "Hunting" or self.State == "Visible"
end

function Monster:IsStunned()
	return os.clock() < self.StunnedUntil
end

function Monster:GetPosition()
	return self.CFrame.Position
end

-- Distance along a ray at which it passes within `radius` of the body, or nil.
function Monster:RayHit(origin, unitDir, maxDist, radius)
	if not self:IsShootable() then
		return nil
	end
	local rootPos = self.CFrame.Position
	local best
	for _, h in ipairs({ -2.5, 1.5, 5.5 }) do
		local c = rootPos + Vector3.new(0, h, 0)
		local along = (c - origin):Dot(unitDir)
		if along > 0 and along <= maxDist and (c - (origin + unitDir * along)).Magnitude <= radius then
			if not best or along < best then
				best = along
			end
		end
	end
	return best
end

function Monster:Appear(groundCf)
	if self.FadeTween then
		self.FadeTween:Cancel()
	end
	self.Scripted = nil
	self.Waypoints = nil
	self.Target = nil
	self.HuntEndsAt = nil
	self.StunnedUntil = 0
	self.Fire.Enabled = false
	self.EyeLight.Enabled = true
	self:_setFade(0)
	self.CFrame = self:_rootAt(groundCf)
	self.State = "Visible"
	self:_apply(self.CFrame)
end

function Monster:Hide()
	if self.State == "Dead" then
		return
	end
	if self.FadeTween then
		self.FadeTween:Cancel()
	end
	self.Scripted = nil
	self.State = "Hidden"
	self.HuntEndsAt = nil
	self.Waypoints = nil
	self.Target = nil
	self.StunnedUntil = 0
	self.Fire.Enabled = false
	self.CFrame = HIDDEN
	self:_apply(HIDDEN)
	self:_setFade(0)
end

-- Rises out of the ground or water at groundCf over `duration` seconds.
function Monster:Rise(groundCf, duration, done)
	self:Appear(groundCf)
	local to = self.CFrame
	local from = to * CFrame.new(0, -14, 0)
	self.CFrame = from
	self.Scripted = { From = from, To = to, Start = os.clock(), Duration = duration, Done = done }
end

function Monster:StartHunt(duration)
	if self.State ~= "Visible" and self.State ~= "Hunting" then
		return
	end
	self.Scripted = nil
	self.State = "Hunting"
	self.HuntEndsAt = duration and (os.clock() + duration) or nil
end

-- Loses interest: glides away (to `destination`, or away from everyone) while fading out.
function Monster:EndHunt(destination)
	if self.State ~= "Hunting" and self.State ~= "Visible" then
		return
	end
	self.State = "Leaving"
	self.HuntEndsAt = nil
	self.Waypoints = nil
	local feet = self:_feet()
	if not destination then
		local away = Vector3.zero
		for _, t in ipairs(self.GetTargets()) do
			away += (feet - t.Root.Position) * Vector3.new(1, 0, 1)
		end
		away = away.Magnitude > 0.1 and away.Unit or Vector3.new(math.random() - 0.5, 0, math.random() - 0.5).Unit
		destination = feet + away * 40
	end
	local duration = math.clamp((destination - feet).Magnitude / 10, 2, 6)
	local flat = Vector3.new(destination.X, feet.Y, destination.Z)
	local toRoot = destination + Vector3.new(0, ROOT_HEIGHT, 0)
	local look = (flat - feet).Magnitude > 0.1 and CFrame.lookAt(toRoot, toRoot + (flat - feet).Unit) or CFrame.new(toRoot)
	self:_fadeTo(1, math.min(duration, 3), math.max(0, duration - 3))
	self.Scripted = {
		From = self.CFrame,
		To = look,
		Start = os.clock(),
		Duration = duration,
		Done = function()
			if self.State == "Leaving" then
				self:Hide()
				if self.OnHuntEnded then
					self.OnHuntEnded()
				end
			end
		end,
	}
end

-- A flare hit. Returns "ignored", "stunned" or "downed".
function Monster:FlareHit()
	if not self:IsShootable() then
		return "ignored"
	end
	local now = os.clock()
	self.StunnedUntil = now + M.StunTime
	self.Fire.Enabled = true
	task.delay(M.StunTime, function()
		if os.clock() >= self.StunnedUntil and self.State ~= "Downed" and self.State ~= "Dead" then
			self.Fire.Enabled = false
		end
	end)
	task.spawn(function()
		for i = 1, 6 do
			for _, e in ipairs(self.Eyes) do
				e.Transparency = i % 2 == 1 and 1 or math.max(0, self.Fade)
			end
			task.wait(0.08)
		end
	end)
	if self.State ~= "Hunting" then
		return "stunned"
	end
	self.Hits += 1
	if self.Hits >= M.HitsToDown then
		self:Down()
		return "downed"
	end
	return "stunned"
end

-- Knocked down: bursts into flames and fades. The Director decides when it comes back.
function Monster:Down()
	self.State = "Downed"
	self.HuntEndsAt = nil
	self.Scripted = nil
	self.Waypoints = nil
	self.Hits = 0
	self.Fire.Enabled = true
	self.Fire.Size = 12
	self:_fadeTo(1, 2.5)
	task.delay(2.8, function()
		if self.State == "Downed" then
			self.Fire.Size = 7
			self:Hide()
		end
	end)
	if self.OnDowned then
		task.spawn(self.OnDowned)
	end
end

-- Destroyed for good: burns from the inside, eyes flicker out, crumbles to ash.
function Monster:Die(done)
	self.State = "Dead"
	self.Scripted = nil
	self.HuntEndsAt = nil
	self.Fire.Enabled = true
	self.Fire.Size = 15
	self.Fire.Heat = 20
	self:_setFade(0)
	task.spawn(function()
		for i = 1, 10 do
			for _, e in ipairs(self.Eyes) do
				e.Transparency = i % 2 == 0 and 0 or 1
			end
			self.EyeLight.Enabled = i % 2 == 0
			task.wait(0.16)
		end
		for _, e in ipairs(self.Eyes) do
			e.Color = Color3.fromRGB(30, 30, 30)
			e.Material = Enum.Material.SmoothPlastic
		end
		self.EyeLight.Enabled = false
		task.wait(0.6)
		for _, p in ipairs(self.Parts) do
			if p ~= self.Root then
				p.Color = Color3.fromRGB(72, 70, 68)
				p.Material = Enum.Material.Slate
				p.Anchored = false
				p.CanCollide = true
				p.AssemblyLinearVelocity = Vector3.new(math.random(-6, 6), math.random(0, 8), math.random(-6, 6))
			end
		end
		task.wait(1.5)
		self:_fadeTo(1, 2.5)
		task.wait(2.6)
		self.Fire.Enabled = false
		if done then
			done()
		end
	end)
end

function Monster:Destroy()
	self.Alive = false
	if self.Conn then
		self.Conn:Disconnect()
	end
	self.Model:Destroy()
end

return Monster
