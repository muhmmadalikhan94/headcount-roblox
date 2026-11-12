-- Builds all of Camp Hollow Pines from code: terrain, forest, lake, buildings, props.
-- Nothing has to be placed by hand in Studio. Swap any piece for a Toolbox model later.
-- Returns a table of references the Director uses to run the story.
--
-- Layout (top view, +Z is north):
--   car (0,-40) -> road -> gate (z=150) -> cabins around campfire (0,268)
--   lake + dock + boathouse to the east (x 130..300)
--   mess hall to the west (-150,330), director's office on the hill (-150,490)
--   flagpole at the centre-north (0,450)

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Story = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Story"))

local MapBuilder = {}

local WOOD = Color3.fromRGB(86, 64, 46)
local DARK_WOOD = Color3.fromRGB(54, 40, 30)
local TRUNK = Color3.fromRGB(58, 44, 34)
local ROOF = Color3.fromRGB(44, 40, 38)
local STONE = Color3.fromRGB(92, 92, 95)
local METAL = Color3.fromRGB(58, 60, 64)
local PAPER = Color3.fromRGB(232, 224, 200)
local GLASS = Color3.fromRGB(22, 28, 34)
local LAMP_ON = Color3.fromRGB(255, 196, 120)
local RED_BOX = Color3.fromRGB(185, 28, 24)
local INK_RED = "#a01515"

local UP = CFrame.Angles(0, 0, math.rad(90)) -- stands a cylinder's X axis upright
local FLAT = CFrame.Angles(math.rad(-90), 0, 0) -- lays a sheet of paper flat
local DEG = math.rad

local root -- the "Camp" folder
local current -- folder new parts go into
local map

------------------------------------------------------------------ helpers

local function group(name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = root
	current = f
	return f
end

local function P(size, cf, color, material, props)
	local p = Instance.new("Part")
	if props and props.Shape then
		p.Shape = props.Shape
	end
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color or WOOD
	p.Material = material or Enum.Material.Wood
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props then
		for k, v in pairs(props) do
			if k ~= "Shape" then
				p[k] = v
			end
		end
	end
	p.Parent = current
	return p
end

local function cyl(length, diameter, cf, color, material, props)
	props = props or {}
	props.Shape = Enum.PartType.Cylinder
	return P(Vector3.new(length, diameter, diameter), cf, color, material, props)
end

local function beam(a, b, thick, color, material)
	return P(Vector3.new(thick, thick, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), color, material)
end

local function surfaceText(part, face, text, opts)
	opts = opts or {}
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = opts.PPS or 50
	gui.LightInfluence = opts.LightInfluence or 0.35
	gui.MaxDistance = 150
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = opts.Font or Enum.Font.SpecialElite
	label.TextColor3 = opts.Color or Color3.fromRGB(235, 225, 205)
	label.RichText = true
	label.TextScaled = true
	label.TextWrapped = true
	label.TextXAlignment = opts.XAlign or Enum.TextXAlignment.Center
	label.TextYAlignment = opts.YAlign or Enum.TextYAlignment.Center
	label.Text = text
	label.Parent = gui
	local pad = Instance.new("UIPadding")
	local px = UDim.new(0, opts.Padding or 4)
	pad.PaddingLeft, pad.PaddingRight, pad.PaddingTop, pad.PaddingBottom = px, px, px, px
	pad.Parent = label
	return gui, label
end

local function prompt(part, action, object, hold, dist)
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText = action
	pp.ObjectText = object or ""
	pp.HoldDuration = hold or 0
	pp.MaxActivationDistance = dist or 9
	pp.RequiresLineOfSight = false
	pp.Parent = part
	return pp
end

local function light(class, parent, color, range, brightness, shadows)
	local l = Instance.new(class)
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = shadows == true
	l.Parent = parent
	return l
end

local function addLamp(bulb, pointLight, groupName, dead)
	local rec = {
		Bulb = bulb,
		Light = pointLight,
		Group = groupName,
		OnColor = bulb.Color,
		OnMaterial = bulb.Material,
		On = true,
		Dead = dead == true,
	}
	table.insert(map.Lamps, rec)
	return rec
end

local function lampPost(x, y, z, groupName)
	P(Vector3.new(0.5, 10, 0.5), CFrame.new(x, y + 5, z), METAL, Enum.Material.Metal)
	P(Vector3.new(0.3, 0.3, 1.8), CFrame.new(x, y + 9.8, z - 0.8), METAL, Enum.Material.Metal)
	local bulb = P(Vector3.new(0.9, 0.9, 0.9), CFrame.new(x, y + 9.3, z - 1.6), LAMP_ON, Enum.Material.Neon, { CanCollide = false })
	return addLamp(bulb, light("PointLight", bulb, LAMP_ON, 26, 1.5, true), groupName)
end

local function ceilingLamp(cf, groupName, range)
	P(Vector3.new(0.15, 1.2, 0.15), cf * CFrame.new(0, 0.9, 0), METAL, Enum.Material.Metal, { CanCollide = false })
	local bulb = P(Vector3.new(0.7, 0.7, 0.7), cf, LAMP_ON, Enum.Material.Neon, { CanCollide = false, Shape = Enum.PartType.Ball })
	return addLamp(bulb, light("PointLight", bulb, LAMP_ON, range or 20, 1.3, true), groupName)
end

local function page(index, cf, color)
	local p = P(Vector3.new(1.1, 1.4, 0.05), cf, color or PAPER, Enum.Material.SmoothPlastic, { CanCollide = false })
	p.Name = "Page" .. index
	light("PointLight", p, Color3.fromRGB(255, 236, 190), 6, 0.7)
	local pp = prompt(p, "Read", index == 9 and "Typed letter" or "Journal page", 0.3, 8)
	pp.Enabled = false
	map.Pages[index] = { Part = p, Prompt = pp }
	return p
end

local function flareBox(cf)
	cf = cf * CFrame.new(0, 0.8, 0)
	local body = P(Vector3.new(2.6, 1.6, 1.6), cf, RED_BOX, Enum.Material.Metal)
	body.Name = "FlareBox"
	local lid = P(Vector3.new(2.7, 0.3, 1.7), cf * CFrame.new(0, 0.95, 0), Color3.fromRGB(140, 18, 16), Enum.Material.Metal)
	surfaceText(body, Enum.NormalId.Front, "FLARES", { Color = Color3.fromRGB(255, 235, 220), Font = Enum.Font.GothamBold, LightInfluence = 0 })
	local glow = light("PointLight", body, Color3.fromRGB(255, 60, 40), 8, 1)
	local pp = prompt(body, "Grab flares", "Flare box", 0.4, 9)
	table.insert(map.FlareBoxes, { Body = body, Lid = lid, Prompt = pp, Light = glow })
end

local function zone(name, cf, size)
	map.Zones[name] = { CFrame = cf, Size = size }
end

-- A wall along its local X axis, base centred on cf, with an optional door gap.
local function wall(cf, length, height, color, material, door)
	if not door then
		return P(Vector3.new(length, height, 0.8), cf * CFrame.new(0, height / 2, 0), color, material)
	end
	local off = door.Offset or 0
	local gapL, gapR = off - door.Width / 2, off + door.Width / 2
	local lw = gapL + length / 2
	if lw > 0.05 then
		P(Vector3.new(lw, height, 0.8), cf * CFrame.new(-length / 2 + lw / 2, height / 2, 0), color, material)
	end
	local rw = length / 2 - gapR
	if rw > 0.05 then
		P(Vector3.new(rw, height, 0.8), cf * CFrame.new(gapR + rw / 2, height / 2, 0), color, material)
	end
	local top = height - door.Height
	if top > 0.05 then
		P(Vector3.new(door.Width, top, 0.8), cf * CFrame.new(off, door.Height + top / 2, 0), color, material)
	end
end

-- A wooden building. cf = centre of the footprint at ground level, LookVector = front.
-- Width runs along local X, depth along local Z. Floor top is 0.6 above cf.
local function building(cf, w, d, h, opts)
	opts = opts or {}
	local color = opts.Color or WOOD
	local mat = opts.Material or Enum.Material.WoodPlanks
	P(Vector3.new(w, 0.6, d), cf * CFrame.new(0, 0.3, 0), DARK_WOOD, Enum.Material.WoodPlanks)
	wall(cf * CFrame.new(0, 0, -d / 2 + 0.4), w, h, color, mat, opts.FrontDoor)
	wall(cf * CFrame.new(0, 0, d / 2 - 0.4), w, h, color, mat, opts.BackDoor)
	wall(cf * CFrame.new(-w / 2 + 0.4, 0, 0) * CFrame.Angles(0, DEG(90), 0), d, h, color, mat, opts.LeftDoor)
	wall(cf * CFrame.new(w / 2 - 0.4, 0, 0) * CFrame.Angles(0, DEG(90), 0), d, h, color, mat, opts.RightDoor)
	P(Vector3.new(w, 0.4, d), cf * CFrame.new(0, h + 0.2, 0), DARK_WOOD, Enum.Material.WoodPlanks)
	local pitch = DEG(opts.Pitch or 24)
	local half = d / 2 + 1
	local slope = half / math.cos(pitch)
	local rise = half * math.tan(pitch)
	local roofColor = opts.RoofColor or ROOF
	P(Vector3.new(w + 2, 0.6, slope), cf * CFrame.new(0, h + rise / 2, -half / 2) * CFrame.Angles(-pitch, 0, 0), roofColor, Enum.Material.Slate)
	P(Vector3.new(w + 2, 0.6, slope), cf * CFrame.new(0, h + rise / 2, half / 2) * CFrame.Angles(pitch, 0, 0), roofColor, Enum.Material.Slate)
	if opts.Windows then
		for _, sx in ipairs({ -1, 1 }) do
			for _, z in ipairs(opts.Windows) do
				P(Vector3.new(0.2, 2.4, 3), cf * CFrame.new(sx * (w / 2 + 0.05), h * 0.55, z), GLASS, Enum.Material.Glass, { Transparency = 0.15 })
			end
		end
	end
end

local function bunk(cf)
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			P(Vector3.new(0.4, 6, 0.4), cf * CFrame.new(sx * 3.4, 3, sz * 1.6), DARK_WOOD)
		end
	end
	for _, y in ipairs({ 1.3, 4.3 }) do
		P(Vector3.new(7.2, 0.3, 3.6), cf * CFrame.new(0, y, 0), DARK_WOOD)
		P(Vector3.new(6.8, 0.5, 3.2), cf * CFrame.new(0, y + 0.4, 0), Color3.fromRGB(105, 115, 96), Enum.Material.Fabric)
		P(Vector3.new(1.4, 0.4, 2.4), cf * CFrame.new(2.6, y + 0.85, 0), Color3.fromRGB(215, 210, 200), Enum.Material.Fabric)
	end
end

local function distToSegment(px, pz, ax, az, bx, bz)
	local abx, abz = bx - ax, bz - az
	local t = math.clamp(((px - ax) * abx + (pz - az) * abz) / (abx * abx + abz * abz), 0, 1)
	local cx, cz = ax + abx * t, az + abz * t
	return math.sqrt((px - cx) ^ 2 + (pz - cz) ^ 2)
end

------------------------------------------------------------------ layout data

local PATHS = { -- ax, az, bx, bz, clear radius, mud width
	{ 0, -135, 0, 165, 13, 9 }, -- road
	{ 0, 150, 0, 268, 12, 6 }, -- gate -> campfire
	{ 0, 268, 0, 450, 10, 6 }, -- campfire -> flagpole
	{ 0, 268, 122, 300, 11, 6 }, -- campfire -> dock
	{ 0, 268, -118, 330, 11, 6 }, -- campfire -> mess hall
	{ -150, 350, -150, 480, 10, 6 }, -- mess hall -> office hill
}
local CLEAR_CIRCLES = { { 0, -40, 22 }, { -26, 95, 14 }, { 0, 268, 86 }, { 0, 450, 44 }, { -150, 490, 30 } }
local CLEAR_RECTS = { { 116, 312, 178, 422 }, { -208, -96, 286, 388 } } -- xmin, xmax, zmin, zmax

local function treeAllowed(x, z)
	for _, c in ipairs(CLEAR_CIRCLES) do
		if (x - c[1]) ^ 2 + (z - c[2]) ^ 2 < c[3] ^ 2 then
			return false
		end
	end
	for _, r in ipairs(CLEAR_RECTS) do
		if x > r[1] and x < r[2] and z > r[3] and z < r[4] then
			return false
		end
	end
	for _, s in ipairs(PATHS) do
		if distToSegment(x, z, s[1], s[2], s[3], s[4]) < s[5] then
			return false
		end
	end
	return true
end

------------------------------------------------------------------ sections

local function buildTerrain()
	local T = workspace.Terrain
	T:Clear()
	T:FillBlock(CFrame.new(0, -20, 260), Vector3.new(820, 40, 820), Enum.Material.Grass)
	for _, s in ipairs(PATHS) do
		local a, b = Vector3.new(s[1], -2, s[2]), Vector3.new(s[3], -2, s[4])
		T:FillBlock(CFrame.lookAt((a + b) / 2, b), Vector3.new(s[6], 4, (b - a).Magnitude), Enum.Material.Mud)
	end
	T:FillCylinder(CFrame.new(0, -2, 268), 4, 20, Enum.Material.Mud)
	T:FillCylinder(CFrame.new(0, -2, 450), 4, 26, Enum.Material.Mud)
	T:FillBlock(CFrame.new(214, -8, 300), Vector3.new(168, 16, 216), Enum.Material.Water)
	T:FillBall(Vector3.new(-150, -60, 490), 75, Enum.Material.Grass)
	T:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(42, 56, 36))
	T:SetMaterialColor(Enum.Material.Mud, Color3.fromRGB(60, 48, 38))
	T.WaterColor = Color3.fromRGB(14, 24, 28)
	T.WaterTransparency = 0.15
	T.WaterReflectance = 0.5
	T.WaterWaveSize = 0.08
	T.WaterWaveSpeed = 4
end

local function buildForest()
	group("Forest")
	local rng = Random.new(1987)
	local placed, tries = 0, 0
	while placed < 750 and tries < 5000 do
		tries += 1
		local x, z = rng:NextNumber(-385, 385), rng:NextNumber(-128, 645)
		if treeAllowed(x, z) then
			placed += 1
			local s = rng:NextNumber(0.9, 1.7)
			local trunkH = 9 * s
			cyl(trunkH, 1.3 * s, CFrame.new(x, trunkH / 2, z) * UP, TRUNK, Enum.Material.Wood)
			local shade = rng:NextNumber(0.8, 1.15)
			local col = Color3.fromRGB(26 * shade, 44 * shade, 32 * shade)
			for i = 1, 3 do
				cyl(3.2 * s, (13 - i * 3) * s, CFrame.new(x, (4 + i * 4) * s, z) * UP, col, Enum.Material.Grass, { CanCollide = false, CastShadow = false })
			end
		end
	end
	for _ = 1, 70 do
		local x, z = rng:NextNumber(-385, 385), rng:NextNumber(-128, 645)
		if treeAllowed(x, z) then
			local sx, sy, sz = rng:NextNumber(2, 6), rng:NextNumber(1.5, 4), rng:NextNumber(2, 6)
			P(Vector3.new(sx, sy, sz), CFrame.new(x, sy / 2 - 0.6, z) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6), rng:NextNumber(-0.3, 0.3)), STONE, Enum.Material.Slate)
		end
	end
end

local function buildBounds()
	group("Bounds")
	local function invisible(size, cf)
		P(size, cf, WOOD, Enum.Material.SmoothPlastic, { Transparency = 1, CanQuery = false, CastShadow = false })
	end
	invisible(Vector3.new(4, 120, 820), CFrame.new(-395, 60, 260))
	invisible(Vector3.new(4, 120, 820), CFrame.new(395, 60, 260))
	invisible(Vector3.new(800, 120, 4), CFrame.new(0, 60, -135))
	invisible(Vector3.new(800, 120, 4), CFrame.new(0, 60, 655))
	-- the camp fence: the only way in is through the gate
	invisible(Vector3.new(381, 120, 2), CFrame.new(-204.6, 60, 150))
	invisible(Vector3.new(381, 120, 2), CFrame.new(204.6, 60, 150))
	zone("RoadLoop", CFrame.new(0, 30, -124), Vector3.new(800, 80, 10))
end

local function buildRoad()
	group("Road")
	-- the broken-down car, facing the camp (+Z)
	local base = CFrame.new(0, 0, -40)
	local paint = Color3.fromRGB(66, 82, 94)
	P(Vector3.new(7, 2.4, 14), base * CFrame.new(0, 2.1, 0), paint, Enum.Material.SmoothPlastic)
	P(Vector3.new(6.4, 2.2, 7), base * CFrame.new(0, 4.4, -0.8), paint, Enum.Material.SmoothPlastic)
	P(Vector3.new(6.5, 1.5, 0.2), base * CFrame.new(0, 4.5, 2.75), GLASS, Enum.Material.Glass)
	P(Vector3.new(6.5, 1.5, 0.2), base * CFrame.new(0, 4.5, -4.35), GLASS, Enum.Material.Glass)
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			cyl(1.2, 2.4, base * CFrame.new(sx * 3.4, 1.2, sz * 4.6), Color3.fromRGB(18, 18, 18), Enum.Material.SmoothPlastic)
		end
		local head = P(Vector3.new(1.2, 0.6, 0.2), base * CFrame.new(sx * 2.4, 2.6, 7.05), Color3.fromRGB(255, 240, 200), Enum.Material.Neon)
		local beamLight = light("SpotLight", head, Color3.fromRGB(255, 235, 200), 45, 1.6, true)
		beamLight.Face = Enum.NormalId.Back
		beamLight.Angle = 50
	end
	local hood = P(Vector3.new(4, 0.2, 3), base * CFrame.new(0, 3.35, 5), paint, Enum.Material.SmoothPlastic)
	local smoke = Instance.new("Smoke")
	smoke.Color = Color3.fromRGB(150, 150, 150)
	smoke.Opacity = 0.12
	smoke.RiseVelocity = 3
	smoke.Size = 2
	smoke.Parent = hood
	P(Vector3.new(6.6, 0.3, 3.4), base * CFrame.new(0, 5.2, -8.2) * CFrame.Angles(DEG(55), 0, 0), paint, Enum.Material.SmoothPlastic)
	local kit = P(Vector3.new(2, 1.1, 1.4), base * CFrame.new(0, 3.85, -5.6), Color3.fromRGB(200, 40, 30), Enum.Material.SmoothPlastic)
	surfaceText(kit, Enum.NormalId.Front, "EMERGENCY", { Font = Enum.Font.GothamBold, LightInfluence = 0 })
	light("PointLight", kit, Color3.fromRGB(255, 120, 90), 6, 0.8)
	map.Prompts.Kit = prompt(kit, "Open", "Emergency kit", 0.6, 10)
	map.Parts.Kit = kit
	map.Checkpoints.Car = CFrame.lookAt(Vector3.new(5, 0, -54), Vector3.new(5, 0, 0))

	-- the leaning road sign
	P(Vector3.new(0.5, 7, 0.5), CFrame.new(11, 3.5, -15), DARK_WOOD)
	local signBoard = P(Vector3.new(9, 3.2, 0.3), CFrame.new(11, 6.4, -15.3) * CFrame.Angles(0, 0, DEG(7)), WOOD, Enum.Material.WoodPlanks)
	surfaceText(signBoard, Enum.NormalId.Front, "CAMP HOLLOW PINES - 1 MILE\n<font color=\"" .. INK_RED .. "\">ROAD CLOSED</font>", { Color = Color3.fromRGB(240, 230, 210) })

	-- the ranger shack whose light flickers on in the prologue
	local shackCf = CFrame.lookAt(Vector3.new(-26, 0, 95), Vector3.new(0, 0, 95))
	building(shackCf, 10, 9, 8, { FrontDoor = { Width = 3, Height = 6 }, Color = DARK_WOOD })
	local window = P(Vector3.new(2.4, 2, 0.3), shackCf * CFrame.new(2.8, 4, -4.65), LAMP_ON, Enum.Material.Neon)
	map.ShackLamp = addLamp(window, light("PointLight", window, LAMP_ON, 30, 2, false), "Shack", true)
	map.Points.Shack = window.Position
end

local function buildGate()
	group("Gate")
	for _, sx in ipairs({ -1, 1 }) do
		P(Vector3.new(2.2, 17, 2.2), CFrame.new(sx * 13, 8.5, 150), WOOD)
		local lantern = P(Vector3.new(0.8, 1, 0.8), CFrame.new(sx * 13, 12.5, 148.6), LAMP_ON, Enum.Material.Neon, { CanCollide = false })
		addLamp(lantern, light("PointLight", lantern, LAMP_ON, 18, 1.2, true), "Gate")
	end
	P(Vector3.new(30, 1.6, 1.6), CFrame.new(0, 16.2, 150), DARK_WOOD)
	local board = P(Vector3.new(22, 3.2, 0.4), CFrame.new(0, 13.6, 149.6), WOOD, Enum.Material.WoodPlanks)
	surfaceText(board, Enum.NormalId.Front, 'WELCOME, CAMPERS!\nSTAY WITH YOUR <s>GROUP</s> <font color="' .. INK_RED .. '">COUNSELOR</font>!', { PPS = 40 })
	-- chained gate bars, two bent apart from the inside
	for x = -11, 11, 2 do
		if math.abs(x) > 4 then
			P(Vector3.new(0.35, 11, 0.35), CFrame.new(x, 5.5, 150), METAL, Enum.Material.CorrodedMetal)
		end
	end
	for _, sx in ipairs({ -1, 1 }) do
		local bottom, mid, top = Vector3.new(sx * 3, 0, 150), Vector3.new(sx * 4.8, 5.5, 150), Vector3.new(sx * 3, 11, 150)
		beam(bottom, mid, 0.35, METAL, Enum.Material.CorrodedMetal)
		beam(mid, top, 0.35, METAL, Enum.Material.CorrodedMetal)
		for _, y in ipairs({ 1, 10 }) do
			P(Vector3.new(9, 0.35, 0.35), CFrame.new(sx * 7.5, y, 150), METAL, Enum.Material.CorrodedMetal)
		end
	end
	for i = -1, 1 do
		P(Vector3.new(0.5, 0.3, 0.3), CFrame.new(i * 1.6, 6 - math.abs(i) * 0.4, 149.7) * CFrame.Angles(0, 0, DEG(i * 30)), METAL, Enum.Material.CorrodedMetal, { CanCollide = false })
	end
	-- wooden fence either side
	for _, sx in ipairs({ -1, 1 }) do
		for x = 20, 80, 6 do
			P(Vector3.new(0.6, 6, 0.6), CFrame.new(sx * x, 3, 150), DARK_WOOD)
		end
		for _, y in ipairs({ 2.5, 5 }) do
			P(Vector3.new(66, 0.4, 0.3), CFrame.new(sx * 47, y, 150), DARK_WOOD)
		end
	end
	local radio = P(Vector3.new(0.7, 1.3, 0.4), CFrame.new(-13, 5, 148.7), Color3.fromRGB(25, 25, 25), Enum.Material.SmoothPlastic)
	P(Vector3.new(0.1, 1.2, 0.1), CFrame.new(-12.8, 6.2, 148.7), Color3.fromRGB(25, 25, 25), Enum.Material.SmoothPlastic, { CanCollide = false })
	light("PointLight", radio, Color3.fromRGB(120, 255, 140), 4, 0.6)
	map.Parts.Radio = radio
	map.Prompts.Radio = prompt(radio, "Pick up", "Walkie-talkie", 0.3, 9)
	page(1, CFrame.new(13, 5.5, 148.85))
	zone("Gate", CFrame.new(0, 8, 136), Vector3.new(40, 20, 24))
	map.Checkpoints.Gate = CFrame.lookAt(Vector3.new(0, 0, 140), Vector3.new(0, 0, 200))
end

local function drawing(part, face)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.LightInfluence = 0.4
	gui.Parent = part
	local caption = Instance.new("TextLabel")
	caption.BackgroundTransparency = 1
	caption.Size = UDim2.fromScale(1, 0.25)
	caption.Font = Enum.Font.IndieFlower
	caption.TextScaled = true
	caption.TextColor3 = Color3.fromRGB(40, 40, 120)
	caption.Text = "our new friend"
	caption.Parent = gui
	local kids = Instance.new("TextLabel")
	kids.BackgroundTransparency = 1
	kids.Position = UDim2.fromScale(0.02, 0.55)
	kids.Size = UDim2.fromScale(0.78, 0.4)
	kids.TextScaled = true
	kids.TextColor3 = Color3.fromRGB(30, 30, 30)
	kids.Text = string.rep("웃", 11)
	kids.Parent = gui
	local figure = Instance.new("Frame")
	figure.BackgroundColor3 = Color3.new(0, 0, 0)
	figure.BorderSizePixel = 0
	figure.Position = UDim2.fromScale(0.83, 0.22)
	figure.Size = UDim2.fromScale(0.12, 0.74)
	figure.Parent = gui
	for _, x in ipairs({ 0.2, 0.6 }) do
		local eye = Instance.new("Frame")
		eye.BackgroundColor3 = Color3.fromRGB(230, 0, 0)
		eye.BorderSizePixel = 0
		eye.Position = UDim2.fromScale(x, 0.08)
		eye.Size = UDim2.fromScale(0.22, 0.05)
		eye.Parent = figure
	end
end

local function buildCabins()
	group("Cabins")
	local fire = Vector3.new(0, 0, 268)
	-- campfire: stones, logs, embers, a marshmallow stick
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		P(Vector3.new(1.4, 1, 1.2), CFrame.new(math.cos(a) * 3.4, 0.4, 268 + math.sin(a) * 3.4) * CFrame.Angles(0, a, 0), STONE, Enum.Material.Slate)
	end
	for i = 0, 2 do
		cyl(5, 0.8, CFrame.new(0, 0.5, 268) * CFrame.Angles(0, i * DEG(60), DEG(10)), Color3.fromRGB(30, 22, 18), Enum.Material.Wood)
	end
	local embers = P(Vector3.new(2, 0.4, 2), CFrame.new(0, 0.3, 268), Color3.fromRGB(255, 90, 30), Enum.Material.Neon, { CanCollide = false })
	light("PointLight", embers, Color3.fromRGB(255, 110, 50), 12, 0.7)
	local smoke = Instance.new("Smoke")
	smoke.Opacity = 0.05
	smoke.Size = 1
	smoke.RiseVelocity = 2
	smoke.Parent = embers
	P(Vector3.new(0.15, 0.15, 4), CFrame.new(1.5, 0.6, 270) * CFrame.Angles(DEG(10), DEG(40), 0), Color3.fromRGB(120, 90, 60), Enum.Material.Wood, { CanCollide = false })
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + DEG(45)
		local pos = Vector3.new(math.cos(a) * 10, 0.6, 268 + math.sin(a) * 10)
		cyl(6, 1.2, CFrame.lookAt(pos, fire + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, DEG(90), 0), TRUNK, Enum.Material.Wood)
	end
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2
		lampPost(math.cos(a) * 28, 0, 268 + math.sin(a) * 28, "Camp")
	end

	local cabins = { A = Vector3.new(-48, 0, 238), B = Vector3.new(48, 0, 238), C = Vector3.new(-48, 0, 298), D = Vector3.new(48, 0, 298) }
	for letter, pos in pairs(cabins) do
		local cf = CFrame.lookAt(pos, fire)
		building(cf, 18, 14, 10, { FrontDoor = { Width = 4, Height = 7 }, Windows = { -3, 3 } })
		local plate = P(Vector3.new(5, 1.4, 0.2), cf * CFrame.new(0, 8.4, -7.1), DARK_WOOD, Enum.Material.WoodPlanks)
		surfaceText(plate, Enum.NormalId.Front, "CABIN " .. letter)
		local left, right = cf * CFrame.new(-4.5, 0.6, 4.2), cf * CFrame.new(4.5, 0.6, 4.2)
		bunk(left)
		bunk(right)
		ceilingLamp(cf * CFrame.new(0, 8.8, 0), letter == "C" and "CabinC" or "Cabin", 18)
		if letter == "A" then
			page(2, left * CFrame.new(-0.5, 2.0, 0) * FLAT)
			P(Vector3.new(0.9, 0.04, 1.1), right * CFrame.new(2.6, 2.37, 0), Color3.new(0, 0, 0), Enum.Material.SmoothPlastic, { CanCollide = false })
		elseif letter == "B" then
			local paper = P(Vector3.new(3.6, 2.6, 0.05), cf * CFrame.new(0, 7.4, 6.15), PAPER, Enum.Material.SmoothPlastic, { CanCollide = false })
			drawing(paper, Enum.NormalId.Front)
		elseif letter == "C" then
			local tape = P(Vector3.new(1.6, 0.8, 1), right * CFrame.new(-1, 2.35, 0), Color3.fromRGB(35, 35, 38), Enum.Material.SmoothPlastic)
			for _, x in ipairs({ -0.4, 0.4 }) do
				cyl(0.1, 0.5, tape.CFrame * CFrame.new(x, 0, -0.5) * CFrame.Angles(0, DEG(90), 0), Color3.fromRGB(180, 180, 180), Enum.Material.Metal, { CanCollide = false })
			end
			light("PointLight", tape, Color3.fromRGB(255, 60, 60), 3, 0.5)
			map.Points.Tape = tape.Position
			zone("CabinC", cf * CFrame.new(0, 4, 0.5), Vector3.new(16, 8, 12))
		elseif letter == "D" then
			page(3, right * CFrame.new(0, 0.05, 0.3) * CFrame.Angles(0, 0.4, 0) * FLAT)
		end
	end
	-- lamps along the paths out of camp
	for i, z in ipairs({ 178, 208, 238 }) do
		lampPost(i % 2 == 0 and 6 or -6, 0, z, "Path")
	end
	for i, z in ipairs({ 320, 350, 380, 410 }) do
		lampPost(i % 2 == 0 and 6 or -6, 0, z, "Path")
	end
	for _, t in ipairs({ 0.4, 0.75 }) do
		lampPost(122 * t, 0, 268 + 32 * t + 6, "Path")
		lampPost(-118 * t, 0, 268 + 62 * t + 6, "Path")
	end
	flareBox(CFrame.new(12, 0, 252) * CFrame.Angles(0, DEG(30), 0))
	zone("Campfire", CFrame.new(0, 8, 262), Vector3.new(60, 16, 44))
	map.Checkpoints.Campfire = CFrame.lookAt(Vector3.new(0, 0, 222), fire)
	map.Points.Sighting = CFrame.lookAt(Vector3.new(0, 0, 372), fire)
end

local function buildLake()
	group("Lake")
	-- ramp + dock
	P(Vector3.new(6.2, 0.5, 8), CFrame.new(119, 0.55, 300) * CFrame.Angles(0, 0, DEG(11)), WOOD, Enum.Material.WoodPlanks)
	P(Vector3.new(86, 0.5, 8), CFrame.new(165, 0.9, 300), WOOD, Enum.Material.WoodPlanks)
	for x = 126, 206, 8 do
		for _, sz in ipairs({ -1, 1 }) do
			P(Vector3.new(0.8, 10, 0.8), CFrame.new(x, -4.3, 300 + sz * 3.6), DARK_WOOD)
		end
	end
	local dockLamps = {}
	for i, x in ipairs({ 135, 150, 165, 180, 195 }) do
		table.insert(dockLamps, lampPost(x, 1.15, i % 2 == 0 and 303.4 or 296.6, "Dock"))
	end
	map.DockLamps = dockLamps
	-- boathouse at the end of the dock
	P(Vector3.new(30, 1, 30), CFrame.new(222, 0.65, 300), DARK_WOOD, Enum.Material.WoodPlanks)
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			P(Vector3.new(1.2, 12, 1.2), CFrame.new(222 + sx * 14, -5.5, 300 + sz * 14), DARK_WOOD)
		end
	end
	local bh = CFrame.lookAt(Vector3.new(221, 1.15, 300), Vector3.new(0, 1.15, 300))
	building(bh, 22, 22, 11, { FrontDoor = { Width = 6, Height = 8 }, Windows = { -5, 5 } })
	local door = P(Vector3.new(6, 8, 0.8), bh * CFrame.new(0, 4.6, -10.6), DARK_WOOD, Enum.Material.WoodPlanks, { Transparency = 1, CanCollide = false, CanQuery = false })
	map.Parts.BoathouseDoor = door
	local bar = P(Vector3.new(7, 0.5, 0.5), bh * CFrame.new(5, 1.2, -8.5), DARK_WOOD)
	map.Prompts.BarDoor = prompt(bar, "Bar the door", "Boathouse door", 0.5, 10)
	map.Prompts.BarDoor.Enabled = false
	for i = -2, 1 do
		P(Vector3.new(1.6, 2.2, 0.5), bh * CFrame.new(i * 3 + 1.5, 5, 9.9), Color3.fromRGB(230, 110, 30), Enum.Material.Fabric)
	end
	page(4, bh * CFrame.new(-10.15, 5.5, 2) * CFrame.Angles(0, DEG(-90), 0))
	page(5, bh * CFrame.new(4.5, 4.6, 9.6))
	ceilingLamp(bh * CFrame.new(0, 9.8, 0), "Boathouse", 22)
	flareBox(bh * CFrame.new(-7, 0.6, 7))
	-- overturned canoes on the shore; the first one knocks
	local canoes = { Vector3.new(110, 0, 320), Vector3.new(104, 0, 328), Vector3.new(112, 0, 278) }
	for i, pos in ipairs(canoes) do
		local hull = P(Vector3.new(2.8, 1.1, 11), CFrame.new(pos + Vector3.new(0, 0.55, 0)) * CFrame.Angles(0, DEG(15 * i), 0), Color3.fromRGB(110, 36, 28), Enum.Material.Wood)
		local keel = P(Vector3.new(2.2, 0.5, 9), hull.CFrame * CFrame.new(0, 0.7, 0), Color3.fromRGB(110, 36, 28), Enum.Material.Wood)
		if i == 1 then
			map.Parts.Canoe = hull
			map.Parts.CanoeKeel = keel
			map.Prompts.CanoeFlip = prompt(hull, "Flip", "Canoe", 0.6, 9)
			map.Points.Canoe = hull.Position
		end
	end
	map.Parts.Footprints = {}
	for i = 0, 5 do
		local fp = P(Vector3.new(0.7, 0.05, 1.2), CFrame.new(113 + i * 3, 0.05, 321 + i * 1.6 + (i % 2) * 0.8) * CFrame.Angles(0, DEG(-70), 0), Color3.fromRGB(20, 30, 40), Enum.Material.SmoothPlastic, { CanCollide = false, Transparency = 1 })
		table.insert(map.Parts.Footprints, fp)
	end
	flareBox(CFrame.new(116, 0, 291))
	zone("Shore", CFrame.new(114, 6, 298), Vector3.new(20, 12, 20))
	zone("Canoes", CFrame.new(110, 6, 318), Vector3.new(26, 12, 26))
	zone("Dock", CFrame.new(170, 5, 300), Vector3.new(30, 12, 12))
	zone("Boathouse", bh * CFrame.new(0, 5, 0), Vector3.new(20, 10, 20))
	map.Checkpoints.Dock = CFrame.lookAt(Vector3.new(104, 0, 300), Vector3.new(200, 0, 300))
	map.Points.LakeRise = CFrame.lookAt(Vector3.new(141, 0, 312), Vector3.new(170, 0, 300))
	map.Points.LakeSink = Vector3.new(185, 0, 350)
end

local function buildMessHall()
	group("MessHall")
	local cf = CFrame.lookAt(Vector3.new(-150, 0, 330), Vector3.new(0, 0, 330)) -- door faces east
	building(cf, 40, 64, 14, {
		FrontDoor = { Width = 8, Height = 10 },
		RightDoor = { Width = 5, Height = 8, Offset = 0 },
		Pitch = 16,
		Windows = { -20, -6, 8 },
	})
	wall(cf * CFrame.new(0, 0, 16), 40, 14, WOOD, Enum.Material.WoodPlanks, { Width = 6, Height = 8 }) -- kitchen wall
	local sign = P(Vector3.new(10, 2, 0.3), cf * CFrame.new(0, 11.5, -32.3), DARK_WOOD, Enum.Material.WoodPlanks)
	surfaceText(sign, Enum.NormalId.Front, "MESS HALL")
	-- three long tables; the middle one is set for twelve
	for _, z in ipairs({ 318, 330, 342 }) do
		P(Vector3.new(36, 0.5, 4), CFrame.new(-142, 3.4, z), WOOD, Enum.Material.WoodPlanks)
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				P(Vector3.new(0.5, 2.6, 0.5), CFrame.new(-142 + sx * 17, 1.9, z + sz * 1.6), DARK_WOOD)
			end
			P(Vector3.new(36, 0.4, 1.4), CFrame.new(-142, 2, z + sx * 3.2), DARK_WOOD, Enum.Material.WoodPlanks)
		end
	end
	for i = 0, 5 do
		for _, sz in ipairs({ -1, 1 }) do
			local clean = i == 3 and sz == 1
			cyl(0.15, 1.4, CFrame.new(-157 + i * 6, 3.72, 330 + sz * 1.2) * UP, clean and Color3.fromRGB(240, 240, 235) or Color3.fromRGB(88, 78, 46), Enum.Material.SmoothPlastic, { CanCollide = false })
		end
	end
	for _, x in ipairs({ -158, -142, -126 }) do
		for _, z in ipairs({ 320, 340 }) do
			ceilingLamp(CFrame.new(x, 12.4, z), "Hall", 26)
		end
	end
	ceilingLamp(CFrame.new(-174, 12.4, 330), "Hall", 22)
	-- kitchen
	P(Vector3.new(12, 3, 3), CFrame.new(-174, 2.1, 312.5), METAL, Enum.Material.Metal)
	P(Vector3.new(12, 3, 3), CFrame.new(-174, 2.1, 347.5), METAL, Enum.Material.Metal)
	P(Vector3.new(3, 3.4, 5), CFrame.new(-179.6, 2.3, 330), Color3.fromRGB(30, 30, 32), Enum.Material.Metal)
	page(6, CFrame.new(-172, 3.65, 347.5) * FLAT)
	local key = P(Vector3.new(0.3, 0.15, 1), CFrame.new(-178, 3.68, 312.5), Color3.fromRGB(190, 150, 60), Enum.Material.Metal, { CanCollide = false })
	light("PointLight", key, Color3.fromRGB(255, 210, 120), 4, 0.5)
	map.Parts.Key = key
	map.Prompts.Key = prompt(key, "Take", "Rusty key", 0.3, 8)
	-- three fuses: hall corner shelf, kitchen counter, outside behind the kitchen
	P(Vector3.new(3, 4, 1.5), CFrame.new(-122, 2.6, 348), DARK_WOOD)
	map.Parts.Fuses, map.Prompts.Fuses = {}, {}
	for i, pos in ipairs({ Vector3.new(-122, 5.05, 348), Vector3.new(-170, 4.05, 312.5), Vector3.new(-189, 0.45, 344) }) do
		local fuse = P(Vector3.new(0.5, 0.9, 0.5), CFrame.new(pos), Color3.fromRGB(235, 200, 60), Enum.Material.Neon, { CanCollide = false })
		light("PointLight", fuse, Color3.fromRGB(255, 220, 100), 5, 0.6)
		map.Parts.Fuses[i] = fuse
		map.Prompts.Fuses[i] = prompt(fuse, "Take", "Fuse", 0.3, 8)
	end
	for i, pos in ipairs({ Vector3.new(-190, 1.5, 338), Vector3.new(-193, 1.5, 341), Vector3.new(-191, 4.5, 339) }) do
		P(Vector3.new(3, 3, 3), CFrame.new(pos) * CFrame.Angles(0, i * 0.4, 0), WOOD, Enum.Material.WoodPlanks)
	end
	-- generator room (north annex)
	local annex = CFrame.lookAt(Vector3.new(-150, 0, 358.4), Vector3.new(-150, 0, 300))
	building(annex, 20, 16, 11, { FrontDoor = { Width = 5, Height = 8 } })
	local gen = P(Vector3.new(6, 4, 4), CFrame.new(-150, 2.6, 360), Color3.fromRGB(70, 80, 60), Enum.Material.Metal)
	surfaceText(gen, Enum.NormalId.Front, "GENERATOR\n<font size=\"14\">NEEDS 3 FUSES</font>", { LightInfluence = 0.2 })
	map.Prompts.Generator = prompt(gen, "Start", "Generator", 1.2, 10)
	map.Points.Generator = gen.Position
	ceilingLamp(CFrame.new(-150, 9.8, 358), "Hall", 18)
	page(7, CFrame.new(-156, 4.5, 365.55))
	flareBox(CFrame.new(-110, 0, 342))
	flareBox(CFrame.new(-160, 0.6, 314))
	flareBox(CFrame.new(-143, 0.6, 363))
	zone("MessHall", CFrame.new(-142, 6, 330), Vector3.new(46, 12, 38))
	map.Checkpoints.MessHall = CFrame.lookAt(Vector3.new(-100, 0, 330), Vector3.new(-150, 0, 330))
	map.Points.Kitchen = CFrame.lookAt(Vector3.new(-174, 0.6, 330), Vector3.new(-100, 0.6, 330))
	lampPost(-144, 0, 385, "Path")
	lampPost(-156, 0, 425, "Path")
end

local function buildOffice()
	group("Office")
	P(Vector3.new(18, 16, 16), CFrame.new(-150, 7.2, 490), STONE, Enum.Material.Slate)
	P(Vector3.new(6, 0.8, 3), CFrame.new(-150, 15, 481.4), STONE, Enum.Material.Slate)
	local cf = CFrame.lookAt(Vector3.new(-150, 15.2, 490), Vector3.new(-150, 15.2, 300))
	building(cf, 16, 14, 10, { FrontDoor = { Width = 4, Height = 7 }, Color = DARK_WOOD, Windows = { 0 } })
	local door = P(Vector3.new(4, 7, 0.5), cf * CFrame.new(0, 4.1, -6.6), Color3.fromRGB(40, 28, 20), Enum.Material.WoodPlanks)
	surfaceText(door, Enum.NormalId.Front, "DIRECTOR\nW. CRANE", { PPS = 30 })
	map.Parts.OfficeDoor = door
	map.Prompts.OfficeDoor = prompt(door, "Unlock", "Director's office", 0.6, 9)
	P(Vector3.new(6, 0.4, 3), cf * CFrame.new(0, 3.6, 3), DARK_WOOD)
	P(Vector3.new(5.6, 3, 2.6), cf * CFrame.new(0, 2.1, 3), DARK_WOOD)
	page(9, cf * CFrame.new(0.5, 3.83, 3) * CFrame.Angles(0, 0.3, 0) * FLAT, Color3.fromRGB(205, 180, 135))
	for _, x in ipairs({ -5.5, 5.5 }) do
		P(Vector3.new(2.2, 5, 2), cf * CFrame.new(x, 3.1, 5.2), METAL, Enum.Material.Metal)
	end
	local photo = P(Vector3.new(0.2, 3, 4), cf * CFrame.new(-7.4, 6, 0), DARK_WOOD)
	local gui, label = surfaceText(photo, Enum.NormalId.Right, "STAFF - SUMMER 1987\n\n웃  웃  웃  웃", { Font = Enum.Font.Antique, Color = Color3.fromRGB(60, 50, 40), YAlign = Enum.TextYAlignment.Top })
	label.BackgroundTransparency = 0
	label.BackgroundColor3 = Color3.fromRGB(200, 185, 150)
	local blur = Instance.new("Frame")
	blur.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
	blur.BackgroundTransparency = 0.25
	blur.BorderSizePixel = 0
	blur.Position = UDim2.fromScale(0.45, 0.3)
	blur.Size = UDim2.fromScale(0.12, 0.65)
	blur.Parent = gui
	for _, x in ipairs({ 0.15, 0.6 }) do
		local eye = Instance.new("Frame")
		eye.BackgroundColor3 = Color3.fromRGB(220, 0, 0)
		eye.BorderSizePixel = 0
		eye.Position = UDim2.fromScale(x, 0.06)
		eye.Size = UDim2.fromScale(0.25, 0.04)
		eye.Parent = blur
	end
	ceilingLamp(cf * CFrame.new(0, 9, 0), "Office", 16)
	flareBox(CFrame.new(-140, 0, 440))
end

local function buildFlagpole()
	group("Flagpole")
	local center = Vector3.new(0, 0, 450)
	P(Vector3.new(4, 1, 4), CFrame.new(0, 0.5, 450), STONE, Enum.Material.Concrete)
	cyl(40, 0.9, CFrame.new(0, 20, 450) * UP, METAL, Enum.Material.Metal)
	P(Vector3.new(7, 4.5, 0.15), CFrame.new(3.9, 36.5, 450) * CFrame.Angles(0, 0, DEG(-6)), Color3.fromRGB(110, 25, 25), Enum.Material.Fabric, { CanCollide = false })
	local roster = P(Vector3.new(2.6, 3.4, 0.08), CFrame.new(0, 5.5, 449.5), PAPER, Enum.Material.SmoothPlastic, { CanCollide = false })
	roster.Name = "Roster"
	local lines = { "<b>CAMP HOLLOW PINES - ROSTER</b>" }
	for i, name in ipairs(Story.RosterNames) do
		table.insert(lines, string.format('<font color="%s"><s>%d. %s</s></font>', INK_RED, i, name))
	end
	table.insert(lines, "12. MARCY HAL")
	surfaceText(roster, Enum.NormalId.Front, table.concat(lines, "\n"), {
		Font = Enum.Font.IndieFlower,
		Color = Color3.fromRGB(30, 30, 40),
		PPS = 60,
		LightInfluence = 0.25,
		XAlign = Enum.TextXAlignment.Left,
	})
	P(Vector3.new(0.12, 0.12, 0.9), CFrame.new(0.45, 4.25, 449.1) * CFrame.Angles(DEG(20), DEG(15), 0), Color3.fromRGB(230, 180, 40), Enum.Material.Wood, { CanCollide = false })
	local fire = Instance.new("Fire")
	fire.Enabled = false
	fire.Size = 2
	fire.Heat = 6
	fire.Parent = roster
	map.Parts.Roster = roster
	map.Parts.RosterFire = fire
	page(8, CFrame.new(0, 5.2, 450.5))
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2 + DEG(22.5)
		local pos = Vector3.new(math.cos(a) * 22, 0, 450 + math.sin(a) * 22)
		local bench = CFrame.lookAt(pos, center)
		P(Vector3.new(8, 0.5, 1.6), bench * CFrame.new(0, 1.7, 0), WOOD, Enum.Material.WoodPlanks)
		for _, sx in ipairs({ -1, 1 }) do
			P(Vector3.new(0.5, 1.5, 1.4), bench * CFrame.new(sx * 3.4, 0.75, 0), DARK_WOOD)
		end
	end
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + DEG(45)
		lampPost(math.cos(a) * 32, 0, 450 + math.sin(a) * 32, "Flagpole")
	end
	for _, off in ipairs({ Vector3.new(16, 0, 0), Vector3.new(-16, 0, 0), Vector3.new(0, 0, -16), Vector3.new(0, 0, 16) }) do
		flareBox(CFrame.lookAt(center + off, center))
	end
	zone("Flagpole", CFrame.new(0, 8, 450), Vector3.new(64, 20, 64))
	map.Checkpoints.Flagpole = CFrame.lookAt(Vector3.new(0, 0, 404), center)
	map.Points.FlagpoleBehind = CFrame.lookAt(Vector3.new(0, 0, 459), Vector3.new(0, 0, 400))
end

------------------------------------------------------------------ public

function MapBuilder.setupLighting()
	Lighting.ClockTime = 0.2
	Lighting.Brightness = 1
	Lighting.Ambient = Color3.fromRGB(14, 14, 20)
	Lighting.OutdoorAmbient = Color3.fromRGB(34, 36, 48)
	Lighting.EnvironmentDiffuseScale = 0.15
	Lighting.EnvironmentSpecularScale = 0.25
	Lighting.GlobalShadows = true
	Lighting.ExposureCompensation = 0
	local atm = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atm.Density = 0.42
	atm.Offset = 0.15
	atm.Color = Color3.fromRGB(46, 52, 62)
	atm.Decay = Color3.fromRGB(24, 26, 34)
	atm.Glare = 0
	atm.Haze = 2.2
	atm.Parent = Lighting
	local cc = Lighting:FindFirstChild("HeadcountCC") or Instance.new("ColorCorrectionEffect")
	cc.Name = "HeadcountCC"
	cc.Saturation = -0.3
	cc.Contrast = 0.12
	cc.Brightness = -0.02
	cc.TintColor = Color3.fromRGB(205, 215, 235)
	cc.Parent = Lighting
	local bloom = Lighting:FindFirstChild("HeadcountBloom") or Instance.new("BloomEffect")
	bloom.Name = "HeadcountBloom"
	bloom.Intensity = 0.8
	bloom.Size = 30
	bloom.Threshold = 1.2
	bloom.Parent = Lighting
end

function MapBuilder.build()
	local old = workspace:FindFirstChild("Camp")
	if old then
		old:Destroy()
	end
	root = Instance.new("Folder")
	root.Name = "Camp"
	map = {
		Folder = root,
		Lamps = {},
		Pages = {},
		FlareBoxes = {},
		Prompts = {},
		Parts = {},
		Zones = {},
		Points = {},
		Checkpoints = {},
		MonsterSpawns = {},
	}
	buildTerrain()
	buildBounds()
	buildRoad()
	buildGate()
	buildCabins()
	buildLake()
	buildMessHall()
	buildOffice()
	buildFlagpole()
	buildForest()

	for _, xz in ipairs({ { -70, 200 }, { 70, 200 }, { -80, 380 }, { 80, 380 }, { 60, 520 }, { -60, 520 }, { -230, 250 }, { -240, 420 }, { 100, 170 }, { -100, 170 }, { 0, 560 }, { -60, 300 } }) do
		table.insert(map.MonsterSpawns, Vector3.new(xz[1], 0, xz[2]))
	end

	group("Spawn")
	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.CanQuery = false
	spawn.Transparency = 1
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.CFrame = map.Checkpoints.Car * CFrame.new(0, 0.5, 0)
	spawn.Parent = current
	map.Spawn = spawn

	root.Parent = workspace
	return map
end

return MapBuilder
