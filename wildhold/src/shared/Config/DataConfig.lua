return {
    StudioMemory = true, -- Studio practice only. Live servers ALWAYS use DataStore.
    StoreName = "WILDHOLD_Pets_v1", StudioStoreName = "WILDHOLD_Pets_TEST_v1",
    Version = 2, LeaseSeconds = 120, LeaseSafety = 15, SaveInterval = 30,
    RetrySeconds = 2, Retries = 3, ShutdownSeconds = 25,
}
