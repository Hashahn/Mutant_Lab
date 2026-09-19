--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local root = ReplicatedStorage:WaitForChild("MutantLab")
local shared = root:WaitForChild("Shared")
local remotes = root:WaitForChild("Remotes")

local GameConfig = require(shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local NetworkController = require(script.Parent.Controllers.NetworkController)
local UIController = require(script.Parent.Controllers.UIController)
local WorldController = require(script.Parent.Controllers.WorldController)

local network
local world = WorldController.new()
world:Start()

local ui
ui = UIController.new({
	OnAction = function(action, payload)
		if network and not network:Request(action, payload) then
			ui:ShowToast("An experiment is already being processed.", Color3.fromRGB(255, 164, 73))
		end
	end,
	OnRetry = function()
		if network then
			network:RetryInitial()
		end
	end,
	OnSelectionChanged = function(selectedIds)
		world:SetSelected(selectedIds)
	end,
}, GameConfig)

network = NetworkController.new(remotes, {
	OnState = function(snapshot)
		ui:SetState(snapshot)
		world:SetState(snapshot)
	end,
	OnStatus = function(status, detail)
		ui:SetStatus(status, detail)
	end,
	OnBusy = function(busy)
		ui:SetBusy(busy)
	end,
	OnResult = function(action, ok, code)
		ui:ShowResult(action, ok, code)
		world:HandleActionResult(action, ok, code)
	end,
	OnNotice = function(notice)
		ui:ShowNotice(notice)
	end,
})

network:Start()

script.Destroying:Connect(function()
	network:Stop()
	ui:Destroy()
	world:Stop()
end)
