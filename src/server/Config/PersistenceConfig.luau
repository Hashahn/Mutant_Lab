--!strict

return table.freeze({
	DataStoreName = "MutantLabProfiles",
	LiveNamespace = "development-v1",
	StudioNamespace = "studio-test-v1",
	KeyPrefix = "player:",

	SessionLeaseSeconds = 120,
	RenewIntervalSeconds = 30,
	AutosaveIntervalSeconds = 60,
	RetryAttempts = 4,
	RetryBaseDelaySeconds = 0.5,
	ShutdownTimeoutSeconds = 20,

	StudioPersistence = table.freeze({
		Enabled = false,
		-- Set this only to a dedicated, non-production test universe ID.
		UniverseId = 0,
	}),
})
