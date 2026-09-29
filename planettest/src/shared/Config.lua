-- 숫자는 이곳에서만 바꿉니다. Studio: Stop → 수정 → Play.
return {
    Radius = 160,                 -- 속도 16이면 한 바퀴 약 63초; 곡률을 더 뚜렷하게
    CenterX = 0, CenterY = 0, CenterZ = 0,
    Gravity = 90,
    WalkSpeed = 16,
    JumpSpeed = 38,
    MoveResponse = 12,
    MaxMoveAcceleration = 160,
    AirControl = 0.35,
    GroundProbe = 0.45,
    GroundNormalMin = 0.45,       -- 벽 옆면을 점프 가능한 땅으로 취급하지 않음
    JumpCooldown = 0.25,
    ColliderRadius = 1,
    OrientationResponse = 45,
    TurnResponse = 14,
    SpawnClearance = 3,
    AppearanceWaitSeconds = 5,    -- 외형 로딩이 실패해도 캐릭터를 영구 고정하지 않음
    OppositeSpawns = true,       -- 2번째 플레이어는 행성 반대편에서 시작
    RespawnDistance = 160,       -- 표면에서 너무 멀어지면 재시작
    Embed = 0.4,
    TreeCount = 48,
    RockCount = 12,
    Seed = 2718,
    FlagDistances = {30,60,90,120},
    RouteFlagCount = 12,         -- 적도 대신 기지를 지나는 대원에 한 바퀴 표지
    MonsterSpeed = 7,
    MonsterNear = 14,
    MonsterFarFraction = 0.75,   -- pi*반지름에 대한 비율
    CameraDistance = 12,
    CameraMinDistance = 5,
    CameraMaxDistance = 32,
    CameraPitch = 12,
    CameraMinPitch = -15,
    CameraMaxPitch = 75,
    CameraFocusHeight = 1.5,
    CameraSensitivity = 0.004,
    CameraZoomStep = 2,
    CameraCollisionRadius = 0.45,
    CameraPadding = 0.5,
    CameraReturnResponse = 12,
    GamepadCameraSpeed = 2,
}
