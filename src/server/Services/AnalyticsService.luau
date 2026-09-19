--!strict
local RobloxAnalytics = game:GetService("AnalyticsService")
local RunService = game:GetService("RunService")
local Analytics = {}
local steps = {
	{ "FirstBlobCreated", 2 },
	{ "FirstMergeCompleted", 3 },
	{ "FirstBattleStarted", 4 },
	{ "FirstBattleCompleted", 5 },
	{ "TutorialCompleted", 6 },
}
local function safely(callback)
	if RunService:IsStudio() then
		return
	end
	task.spawn(function()
		local ok, err = pcall(callback)
		if not ok then
			warn("[MutantLab Analytics] " .. tostring(err))
		end
	end)
end
function Analytics.Joined(player)
	safely(function()
		RobloxAnalytics:LogCustomEvent(player, "PlayerJoined", 1)
	end)
end
function Analytics.OnboardingStarted(player)
	safely(function()
		RobloxAnalytics:LogOnboardingFunnelStepEvent(player, 1, "Started")
	end)
end
function Analytics.Transition(player, before, after)
	for _, step in steps do
		local name, index = step[1], step[2]
		if after[name] and not before[name] then
			safely(function()
				RobloxAnalytics:LogOnboardingFunnelStepEvent(player, index, name)
			end)
		end
	end
	if after.FirstBlobPurchased and not before.FirstBlobPurchased then
		safely(function()
			RobloxAnalytics:LogCustomEvent(player, "FirstBlobPurchased", 1)
		end)
	end
end
function Analytics.Economy(player, delta, balance, reason)
	if delta == 0 then
		return
	end
	safely(function()
		RobloxAnalytics:LogEconomyEvent(
			player,
			if delta > 0 then Enum.AnalyticsEconomyFlowType.Source else Enum.AnalyticsEconomyFlowType.Sink,
			"BioCoins",
			math.abs(delta),
			balance,
			if delta > 0 then "Gameplay" else "Shop",
			reason
		)
	end)
end
return Analytics
