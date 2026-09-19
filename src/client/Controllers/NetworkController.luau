--!nonstrict

local NetworkController = {}
NetworkController.__index = NetworkController

export type Callbacks = {
	OnState: (snapshot: { [any]: any }) -> (),
	OnStatus: (status: string, detail: string?) -> (),
	OnBusy: (busy: boolean) -> (),
	OnResult: (action: string, ok: boolean, code: string) -> (),
	OnNotice: (notice: { [any]: any }) -> (),
}

function NetworkController.new(remotes: Instance, callbacks: Callbacks)
	local self = setmetatable({}, NetworkController)
	self._getState = remotes:WaitForChild("GetState") :: RemoteFunction
	self._requestAction = remotes:WaitForChild("RequestAction") :: RemoteFunction
	self._stateChanged = remotes:WaitForChild("StateChanged") :: RemoteEvent
	self._callbacks = callbacks
	self._revision = -1
	self._busy = false
	self._running = false
	self._loadingGeneration = 0
	self._connection = nil
	return self
end

function NetworkController:_accept(snapshot: any): boolean
	if type(snapshot) ~= "table" or type(snapshot.Revision) ~= "number" then
		return false
	end
	if snapshot.Revision < self._revision then
		return false
	end
	self._revision = snapshot.Revision
	self._callbacks.OnState(snapshot)
	return true
end

function NetworkController:_beginInitialLoad()
	self._loadingGeneration += 1
	local generation = self._loadingGeneration
	task.spawn(function()
		local attempt = 0
		while self._running and generation == self._loadingGeneration do
			attempt += 1
			self._callbacks.OnStatus(
				"loading",
				if attempt == 1
					then "Connecting to the lab..."
					else string.format("Lab is still loading (attempt %d)...", attempt)
			)
			local callOk, response = pcall(function()
				return self._getState:InvokeServer()
			end)
			if not self._running or generation ~= self._loadingGeneration then
				return
			end
			if
				callOk
				and type(response) == "table"
				and response.Ok == true
				and self:_accept(response.State)
			then
				self._callbacks.OnStatus("ready")
				return
			end

			local code = if callOk
					and type(response) == "table"
					and type(response.Code) == "string"
				then response.Code
				else "CONNECTION_ERROR"
			self._callbacks.OnStatus("retrying", code)
			local delaySeconds = math.min(0.5 * (2 ^ (attempt - 1)), 6)
			task.wait(delaySeconds)
		end
	end)
end

function NetworkController:Start()
	if self._running then
		return
	end
	self._running = true
	self._connection = self._stateChanged.OnClientEvent:Connect(function(snapshot, notice)
		local accepted = self:_accept(snapshot)
		if accepted then
			self._loadingGeneration += 1
			self._callbacks.OnStatus("ready")
		end
		if accepted and type(notice) == "table" then
			self._callbacks.OnNotice(notice)
		end
	end)
	self:_beginInitialLoad()
end

function NetworkController:RetryInitial()
	if not self._running then
		return
	end
	self:_beginInitialLoad()
end

function NetworkController:Request(action: string, payload: any?): boolean
	if self._busy then
		return false
	end
	self._busy = true
	self._callbacks.OnBusy(true)
	task.spawn(function()
		local callOk, response = pcall(function()
			return self._requestAction:InvokeServer(action, payload)
		end)
		if not self._running then
			self._busy = false
			return
		end
		local ok = false
		local code = "CONNECTION_ERROR"
		if callOk and type(response) == "table" then
			ok = response.Ok == true
			if type(response.Code) == "string" then
				code = response.Code
			end
			if response.State ~= nil then
				self:_accept(response.State)
			end
		end
		self._busy = false
		self._callbacks.OnBusy(false)
		self._callbacks.OnResult(action, ok, code)
	end)
	return true
end

function NetworkController:Stop()
	self._running = false
	self._loadingGeneration += 1
	if self._connection then
		self._connection:Disconnect()
		self._connection = nil
	end
end

return NetworkController
