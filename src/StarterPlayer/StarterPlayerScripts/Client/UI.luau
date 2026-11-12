-- Builds the HEADCOUNT HUD in code and returns functions that drive it.

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Story = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Story"))

local UI = {}

local INK = Color3.fromRGB(235, 228, 214)
local RED = Color3.fromRGB(220, 35, 35)
local PANEL = Color3.fromRGB(10, 10, 12)
local PARCHMENT = Color3.fromRGB(226, 214, 182)
local DARK_INK = Color3.fromRGB(40, 32, 26)

local function new(className, props, children)
	local inst = Instance.new(className)
	for k, v in pairs(props) do
		if k ~= "Parent" then
			inst[k] = v
		end
	end
	for _, c in ipairs(children or {}) do
		c.Parent = inst
	end
	inst.Parent = props.Parent
	return inst
end

local function corner(r)
	return new("UICorner", { CornerRadius = UDim.new(0, r or 8) })
end

local function pad(px)
	return new("UIPadding", {
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
	})
end

local function list(padding, align)
	return new("UIListLayout", {
		Padding = UDim.new(0, padding or 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
	})
end

local function label(props, children)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.TextColor3 = props.TextColor3 or INK
	props.Font = props.Font or Enum.Font.SpecialElite
	return new("TextLabel", props, children)
end

local function escape(text)
	return (text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

local typing = {}
local function typewrite(textLabel, text, perChar)
	local token = {}
	typing[textLabel] = token
	textLabel.Text = text
	textLabel.MaxVisibleGraphemes = 0
	task.spawn(function()
		for i = 1, utf8.len(text) or #text do
			if typing[textLabel] ~= token then
				return
			end
			textLabel.MaxVisibleGraphemes = i
			task.wait(perChar)
		end
		textLabel.MaxVisibleGraphemes = -1
	end)
end

local EDGE_FADE = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
local EDGES = {
	{ UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.28), 90 },
	{ UDim2.fromScale(0, 0.72), UDim2.fromScale(1, 0.28), -90 },
	{ UDim2.fromScale(0, 0), UDim2.fromScale(0.22, 1), 0 },
	{ UDim2.fromScale(0.78, 0), UDim2.fromScale(0.22, 1), 180 },
}

function UI.build(playerGui, isTouch)
	local api = {}
	local gui = new("ScreenGui", {
		Name = "HeadcountUI",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	})

	------------------------------------------------------------ vignette
	local function edgeSet(color, z)
		local frames = {}
		for _, e in ipairs(EDGES) do
			local f = new("Frame", { BackgroundColor3 = color, BackgroundTransparency = 1, BorderSizePixel = 0, Position = e[1], Size = e[2], ZIndex = z, Parent = gui })
			new("UIGradient", { Rotation = e[3], Transparency = EDGE_FADE, Parent = f })
			table.insert(frames, f)
		end
		return function(alpha)
			for _, f in ipairs(frames) do
				f.BackgroundTransparency = 1 - alpha
			end
		end
	end
	local setBlack = edgeSet(Color3.new(0, 0, 0), 1)
	local setRed = edgeSet(Color3.fromRGB(150, 0, 0), 2)
	setBlack(0.6)
	function api.SetDanger(level)
		local pulse = 0.75 + 0.25 * math.sin(os.clock() * (6 + level * 6))
		setRed(math.clamp(level * 0.75 * pulse, 0, 0.85))
	end

	------------------------------------------------------------ objective panel
	local panel = new("Frame", {
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.35,
		Position = UDim2.new(0, 16, 0, 64),
		Size = UDim2.new(0, 310, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 5,
		Parent = gui,
	}, { corner(6), pad(10), list(4) })
	label({ Text = "OBJECTIVE", Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Color3.fromRGB(150, 150, 150), Size = UDim2.new(1, 0, 0, 14), TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1, Parent = panel })
	local objective = label({ Text = "", TextSize = 17, TextWrapped = true, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 2, Parent = panel })
	local pages = label({ Text = "PAGES 0/8", Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Color3.fromRGB(230, 200, 140), Size = UDim2.new(1, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 3, Parent = panel })
	local flares = label({ Text = "", Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = Color3.fromRGB(255, 130, 70), Size = UDim2.new(1, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 4, Parent = panel })

	function api.SetObjective(text)
		objective.Text = text
	end
	function api.SetPages(n, total)
		pages.Text = string.format("PAGES %d/%d", n, total)
	end
	function api.SetFlares(n, hasGun)
		flares.Text = hasGun and string.format("FLARES  %d", n) or ""
		flares.TextColor3 = n > 0 and Color3.fromRGB(255, 130, 70) or RED
	end

	------------------------------------------------------------ stamina
	local stamBack = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -88), Size = UDim2.new(0, 220, 0, 5), BackgroundColor3 = Color3.fromRGB(20, 20, 20), BackgroundTransparency = 0.3, Visible = false, Parent = gui }, { corner(3) })
	local stamFill = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = INK, Parent = stamBack }, { corner(3) })
	function api.SetStamina(f)
		stamFill.Size = UDim2.fromScale(f, 1)
		stamFill.BackgroundColor3 = f < 0.25 and RED or INK
		stamBack.Visible = f < 0.995
	end

	------------------------------------------------------------ subtitles
	local sub = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -110),
		Size = UDim2.new(0.72, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.4,
		Visible = false,
		ZIndex = 6,
		Parent = gui,
	}, { corner(6), pad(10), list(2), new("UISizeConstraint", { MaxSize = Vector2.new(780, math.huge) }) })
	local subSpeaker = label({ Text = "", Font = Enum.Font.GothamBold, TextSize = 13, Size = UDim2.new(1, 0, 0, 15), TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1, Parent = sub })
	local subText = label({ Text = "", TextSize = 20, RichText = true, TextWrapped = true, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 2, Parent = sub })
	local subToken = 0
	function api.ShowSubtitle(speakerKey, text, seconds)
		local spk = Story.Speakers[speakerKey] or Story.Speakers.SOUND
		subToken += 1
		local token = subToken
		subSpeaker.Text = spk.Label
		subSpeaker.Visible = spk.Label ~= ""
		subSpeaker.TextColor3 = spk.Color
		subText.TextColor3 = (speakerKey == "MARCY" or speakerKey == "THOUGHT") and INK or spk.Color
		local body = escape(text)
		subText.Font = speakerKey == "TWELFTH" and Enum.Font.Creepster or Enum.Font.SpecialElite
		subText.TextSize = speakerKey == "TWELFTH" and 34 or 20
		sub.Visible = true
		typewrite(subText, spk.Italic and ("<i>" .. body .. "</i>") or body, 0.018)
		task.delay((seconds or 3) + 0.4, function()
			if subToken == token then
				sub.Visible = false
			end
		end)
	end

	------------------------------------------------------------ toasts
	local toasts = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 66), Size = UDim2.new(0, 460, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, ZIndex = 8, Parent = gui }, { list(6, Enum.HorizontalAlignment.Center) })
	local toastCount = 0
	function api.Toast(text, color)
		toastCount += 1
		local t = label({
			Text = text,
			Font = Enum.Font.GothamBold,
			TextSize = 17,
			TextColor3 = color or INK,
			BackgroundColor3 = PANEL,
			BackgroundTransparency = 0.3,
			AutomaticSize = Enum.AutomaticSize.XY,
			Size = UDim2.new(0, 0, 0, 0),
			LayoutOrder = toastCount,
			Parent = toasts,
		})
		corner(6).Parent = t
		pad(8).Parent = t
		task.delay(3.6, function()
			local tw = TweenService:Create(t, TweenInfo.new(0.5), { TextTransparency = 1, BackgroundTransparency = 1 })
			tw:Play()
			tw.Completed:Wait()
			t:Destroy()
		end)
	end

	------------------------------------------------------------ fade / flash
	local fade = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0, ZIndex = 15, Parent = gui })
	function api.Fade(target, seconds)
		TweenService:Create(fade, TweenInfo.new(seconds or 1), { BackgroundTransparency = target }):Play()
	end
	function api.Blink()
		fade.BackgroundTransparency = 0
		api.Fade(1, 0.8)
	end
	local flash = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 14, Parent = gui })
	function api.Flash(color, seconds)
		flash.BackgroundColor3 = color or Color3.new(1, 1, 1)
		flash.BackgroundTransparency = 0.35
		TweenService:Create(flash, TweenInfo.new(seconds or 0.4), { BackgroundTransparency = 1 }):Play()
	end

	------------------------------------------------------------ screen text & chapter cards
	local screenSize = new("UITextSizeConstraint", { MaxTextSize = 44 })
	local screenText = label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.new(0.9, 0, 0, 150), TextScaled = true, TextWrapped = true, TextTransparency = 1, Text = "", ZIndex = 20, Parent = gui }, { screenSize })
	local screenToken = 0
	function api.ShowScreenText(text, seconds, style)
		screenToken += 1
		local token = screenToken
		local title = style == "title"
		screenText.Font = title and Enum.Font.Creepster or Enum.Font.SpecialElite
		screenText.TextColor3 = title and RED or INK
		screenSize.MaxTextSize = title and 80 or 40
		screenText.Text = text
		TweenService:Create(screenText, TweenInfo.new(0.8), { TextTransparency = 0 }):Play()
		task.delay(seconds or 4, function()
			if screenToken == token then
				TweenService:Create(screenText, TweenInfo.new(1.2), { TextTransparency = 1 }):Play()
			end
		end)
	end

	local chapter = label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.17, 0), Size = UDim2.new(0.9, 0, 0, 40), TextSize = 30, TextTransparency = 1, Text = "", ZIndex = 20, Parent = gui })
	local chapterToken = 0
	function api.ShowChapter(text)
		chapterToken += 1
		local token = chapterToken
		chapter.Text = text
		TweenService:Create(chapter, TweenInfo.new(1), { TextTransparency = 0 }):Play()
		task.delay(4, function()
			if chapterToken == token then
				TweenService:Create(chapter, TweenInfo.new(1.5), { TextTransparency = 1 }):Play()
			end
		end)
	end

	------------------------------------------------------------ journal page popup
	local pageFrame = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.47),
		Size = UDim2.new(0.9, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = PARCHMENT,
		Rotation = -1.2,
		Visible = false,
		ZIndex = 12,
		Parent = gui,
	}, { corner(4), pad(22), list(8), new("UISizeConstraint", { MaxSize = Vector2.new(480, math.huge) }) })
	local pageTitle = label({ Font = Enum.Font.IndieFlower, TextSize = 30, TextColor3 = DARK_INK, Size = UDim2.new(1, 0, 0, 34), TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1, Parent = pageFrame })
	local pageBody = label({ Font = Enum.Font.IndieFlower, TextSize = 22, TextColor3 = DARK_INK, TextWrapped = true, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 2, Parent = pageFrame })
	local pageFooter = label({ Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Color3.fromRGB(120, 100, 80), Size = UDim2.new(1, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Right, LayoutOrder = 3, Parent = pageFrame })
	local pageClose = new("TextButton", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = "", ZIndex = 13, Parent = pageFrame })
	local pageToken = 0
	pageClose.Activated:Connect(function()
		pageFrame.Visible = false
	end)
	function api.ShowPage(index, title, text, count, total)
		pageToken += 1
		local token = pageToken
		pageTitle.Text = title
		pageBody.Text = text
		pageFooter.Text = index == 9 and "SECRET PAGE  ·  tap to close" or string.format("PAGE %d / %d  ·  tap to close", count, total)
		pageFrame.Visible = true
		task.delay(12, function()
			if pageToken == token then
				pageFrame.Visible = false
			end
		end)
	end

	------------------------------------------------------------ jumpscare
	local scare = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), Visible = false, ZIndex = 30, Parent = gui })
	local eyes = {}
	for _ = 1, 2 do
		table.insert(eyes, new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(255, 20, 20),
			BorderSizePixel = 0,
			Parent = scare,
		}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }), new("UIStroke", { Color = Color3.fromRGB(255, 70, 70), Thickness = 8, Transparency = 0.35 }) }))
	end
	function api.Jumpscare()
		scare.Visible = true
		for i, e in ipairs(eyes) do
			local side = i == 1 and -1 or 1
			e.Size = UDim2.fromOffset(18, 7)
			e.Position = UDim2.fromScale(0.5 + side * 0.04, 0.45)
			TweenService:Create(e, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Size = UDim2.fromScale(0.17, 0.06),
				Position = UDim2.fromScale(0.5 + side * 0.15, 0.45),
			}):Play()
		end
		task.delay(1.4, function()
			scare.Visible = false
		end)
	end

	------------------------------------------------------------ counted / spectate
	local counted = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 18, Parent = gui })
	label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.16), Size = UDim2.new(0.9, 0, 0, 70), Text = "YOU WERE COUNTED", Font = Enum.Font.Creepster, TextScaled = true, TextColor3 = RED, Parent = counted }, { new("UITextSizeConstraint", { MaxTextSize = 64 }) })
	local spectating = label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.27), Size = UDim2.new(0.9, 0, 0, 24), Text = "", Font = Enum.Font.GothamBold, TextSize = 18, Parent = counted })
	label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.31), Size = UDim2.new(0.9, 0, 0, 20), Text = "You'll return when your group reaches the next chapter.", Font = Enum.Font.Gotham, TextSize = 15, TextColor3 = Color3.fromRGB(170, 170, 170), Parent = counted })
	local row = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -150), Size = UDim2.new(0, 420, 0, 46), BackgroundTransparency = 1, Parent = counted }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local function button(text, width, color, order)
		local b = new("TextButton", { Size = UDim2.new(0, width, 1, 0), BackgroundColor3 = color, Text = text, Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = INK, AutoButtonColor = true, LayoutOrder = order, Parent = row })
		corner(8).Parent = b
		return b
	end
	local prev = button("<", 46, PANEL, 1)
	local revive = button("SECOND CHANCE", 220, Color3.fromRGB(150, 20, 20), 2)
	local nextB = button(">", 46, PANEL, 3)
	prev.Activated:Connect(function()
		if api.OnSpectate then
			api.OnSpectate(-1)
		end
	end)
	nextB.Activated:Connect(function()
		if api.OnSpectate then
			api.OnSpectate(1)
		end
	end)
	revive.Activated:Connect(function()
		if api.OnSecondChance then
			api.OnSecondChance()
		end
	end)
	function api.SetCounted(on)
		counted.Visible = on
	end
	function api.SetSpectating(name)
		spectating.Text = name and ("Spectating " .. name) or "No one left to watch..."
	end

	------------------------------------------------------------ endings
	local ending = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.5, Visible = false, ZIndex = 25, Parent = gui })
	local endTitle = label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.38), Size = UDim2.new(0.9, 0, 0, 130), Font = Enum.Font.Creepster, TextScaled = true, TextColor3 = RED, Parent = ending }, { new("UITextSizeConstraint", { MaxTextSize = 110 }) })
	local endSub = label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.new(0.9, 0, 0, 44), TextScaled = true, Parent = ending }, { new("UITextSizeConstraint", { MaxTextSize = 34 }) })
	label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.64), Size = UDim2.new(0.9, 0, 0, 24), Text = "Thanks for playing HEADCOUNT. If it got you, leave a like and favorite!", Font = Enum.Font.Gotham, TextSize = 16, TextColor3 = Color3.fromRGB(190, 190, 190), Parent = ending })

	local roster = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 360, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = PARCHMENT, Visible = false, ZIndex = 24, Parent = gui }, { corner(4), pad(18), list(2) })
	local function rosterLine(text, color, order)
		return label({ Text = text, RichText = true, Font = Enum.Font.IndieFlower, TextSize = 20, TextColor3 = color or DARK_INK, Size = UDim2.new(1, 0, 0, 22), TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = order, Parent = roster })
	end

	function api.ShowRoster(names)
		for _, c in ipairs(roster:GetChildren()) do
			if c:IsA("TextLabel") then
				c:Destroy()
			end
		end
		rosterLine("<b>CAMP HOLLOW PINES - ROSTER</b>", DARK_INK, 0)
		for i, n in ipairs(Story.RosterNames) do
			rosterLine(string.format("<s>%d. %s</s>", i, n), Color3.fromRGB(150, 25, 25), i)
		end
		rosterLine("12. MARCY HALE", Color3.fromRGB(150, 25, 25), 12)
		roster.Visible = true
		for i, n in ipairs(names) do
			task.delay(0.6 + i * 0.8, function()
				rosterLine(string.format("%d. %s", 12 + i, escape(n)), Color3.fromRGB(150, 25, 25), 12 + i)
			end)
		end
	end

	function api.ShowEnding(title, subtitle)
		roster.Visible = false
		ending.Visible = true
		endTitle.Text = title
		endSub.Text = subtitle
		endTitle.TextTransparency = 1
		endSub.TextTransparency = 1
		TweenService:Create(endTitle, TweenInfo.new(1.5), { TextTransparency = 0 }):Play()
		task.delay(1.2, function()
			TweenService:Create(endSub, TweenInfo.new(1.5), { TextTransparency = 0 }):Play()
		end)
	end

	function api.HideEnding()
		ending.Visible = false
		roster.Visible = false
	end

	------------------------------------------------------------ shop
	local shopButton = new("TextButton", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 16, 0.5, 0), Size = UDim2.new(0, 84, 0, 36), BackgroundColor3 = Color3.fromRGB(120, 20, 20), Text = "SHOP", Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = INK, ZIndex = 5, Parent = gui }, { corner(8) })
	local shop = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0.9, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = PANEL, BackgroundTransparency = 0.05, Visible = false, ZIndex = 22, Parent = gui }, {
		corner(10),
		pad(16),
		list(10),
		new("UISizeConstraint", { MaxSize = Vector2.new(420, math.huge) }),
	})
	local shopHeader = new("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, LayoutOrder = 0, Parent = shop })
	label({ Text = "CAMP STORE", Font = Enum.Font.Creepster, TextSize = 30, TextColor3 = RED, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Left, Parent = shopHeader })
	local close = new("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0, 30, 0, 30), BackgroundColor3 = Color3.fromRGB(40, 40, 44), Text = "X", Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = INK, Parent = shopHeader }, { corner(6) })
	shopButton.Activated:Connect(function()
		shop.Visible = not shop.Visible
	end)
	close.Activated:Connect(function()
		shop.Visible = false
	end)

	function api.BuildShop(items, onBuy)
		local priceLabels = {}
		for i, item in ipairs(items) do
			local card = new("Frame", { Size = UDim2.new(1, 0, 0, 64), BackgroundColor3 = Color3.fromRGB(28, 26, 26), LayoutOrder = i, Parent = shop }, { corner(8), pad(10) })
			label({ Text = item.Name, Font = Enum.Font.GothamBold, TextSize = 16, Size = UDim2.new(1, -110, 0, 18), TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
			label({ Text = item.Description, Font = Enum.Font.Gotham, TextSize = 13, TextWrapped = true, TextColor3 = Color3.fromRGB(170, 170, 170), Position = UDim2.new(0, 0, 0, 20), Size = UDim2.new(1, -110, 0, 26), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = card })
			local buy = new("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.new(0, 96, 0, 36), BackgroundColor3 = Color3.fromRGB(30, 140, 70), Text = "BUY", Font = Enum.Font.GothamBold, TextSize = 15, TextColor3 = INK, Parent = card }, { corner(8) })
			buy.Activated:Connect(function()
				onBuy(item)
			end)
			priceLabels[i] = buy
		end
		return function(index, text)
			if priceLabels[index] then
				priceLabels[index].Text = text
			end
		end
	end

	------------------------------------------------------------ title card
	function api.Intro(quote, source)
		local intro = new("CanvasGroup", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(5, 5, 6), ZIndex = 40, Parent = gui })
		label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.33), Size = UDim2.new(0.9, 0, 0, 140), Text = "HEADCOUNT", Font = Enum.Font.Creepster, TextScaled = true, TextColor3 = RED, Parent = intro }, { new("UITextSizeConstraint", { MaxTextSize = 130 }) })
		label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.new(0.85, 0, 0, 60), Text = quote, TextSize = 22, TextWrapped = true, Parent = intro })
		label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.6), Size = UDim2.new(0.85, 0, 0, 20), Text = "- " .. source, Font = Enum.Font.Gotham, TextSize = 14, TextColor3 = Color3.fromRGB(150, 150, 150), Parent = intro })
		label({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.86),
			Size = UDim2.new(0.9, 0, 0, 20),
			Text = isTouch and "RUN button to sprint  ·  LIGHT for flashlight  ·  tap to fire a flare" or "Shift to run  ·  F for flashlight  ·  Click to fire a flare",
			Font = Enum.Font.Gotham,
			TextSize = 15,
			TextColor3 = Color3.fromRGB(150, 150, 150),
			Parent = intro,
		})
		local enter = new("TextButton", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.73), Size = UDim2.new(0, 240, 0, 48), BackgroundColor3 = Color3.fromRGB(120, 20, 20), Text = "ENTER THE CAMP", Font = Enum.Font.GothamBold, TextSize = 18, TextColor3 = INK, Parent = intro }, { corner(8) })
		local gone = false
		local function dismiss()
			if gone then
				return
			end
			gone = true
			local tw = TweenService:Create(intro, TweenInfo.new(1.2), { GroupTransparency = 1 })
			tw:Play()
			tw.Completed:Wait()
			intro:Destroy()
		end
		enter.Activated:Connect(dismiss)
		task.delay(15, dismiss)
	end

	return api
end

return UI
