return {
    StudioMemory = true, -- Studio practice only. Live servers ALWAYS use DataStore.
    StoreName = "WILDHOLD_Pets_v1", StudioStoreName = "WILDHOLD_Pets_TEST_v1",
    Version = 4, LeaseSeconds = 120, LeaseSafety = 15, SaveInterval = 30,
    RetrySeconds = 2, Retries = 3, ShutdownSeconds = 25,
    LockWait = 24, -- 다른 서버(로비)가 저장을 쥐고 있으면 이만큼 기다린다 (텔레포트 직후)
}
