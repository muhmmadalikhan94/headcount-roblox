-- HEADCOUNT server entry point: creates the remotes, then hands over to the Director.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

Players.CharacterAutoLoads = false -- the Director spawns players at story checkpoints

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
for _, name in ipairs({ "Dialogue", "Effect", "PageFound", "Notify", "FireFlare", "Flashlight", "LookedAway" }) do
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotes
end
remotes.Parent = ReplicatedStorage

require(script.Parent.Director).start(remotes)
