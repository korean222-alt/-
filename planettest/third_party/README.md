# EgoMoose 출처 / 수정 범위

- 원본: https://github.com/EgoMoose/Rbx-Gravity-Controller
- 고정 커밋: `95e2a79596052bc36b2bf3290d92390b10db7210`
- 라이선스: MIT, Copyright (c) 2020 EgoMoose. 상업적 이용·수정·배포를 허용하며 저작권 및 허가 고지를 유지해야 합니다. 원문 전체는 `EgoMoose-LICENSE.txt`이며 생성된 place의 `ReplicatedStorage.ThirdPartyNotices`에도 포함합니다.

`src/client/Modules/GravityController.lua`는 원본 GravityController의 중력 보정력, 접선/수직 속도 분해, 이동 힘과 Collider의 구형 충돌체 방식을 행성용으로 크게 줄여 수정한 파생 구현입니다. `src/shared/PlanetMath.lua`의 rotationBetween은 원본 getRotationBetween을 바탕으로 축·각 표현과 대척점 안전 처리를 사용합니다.

변경: 발밑 표면 법선 대신 행성 중심, AssemblyLinearVelocity/AssemblyMass, AlignOrientation, 서버 생성 충돌체·클라이언트 물리 소유권, 시간 기반 회전/이동 응답, 휴대폰 기본 입력과 점프 연결, 리스폰 정리. 카메라는 별도 작성한 평행 이동(방향 운반) 방식으로 교체했습니다.

원본의 CameraInjector, PlayerScriptsLoader, Quenty Signal, 커스텀 Animate/사운드 묶음은 포함하지 않았습니다. Roblox 내부 카메라 모듈을 바꾸거나 외부 자산 ID에서 코드를 다운로드하지 않습니다. 캐릭터 모양과 리그는 기본 아바타를 유지합니다.

확인한 Roblox 공식 문서:
- https://create.roblox.com/docs/reference/engine/classes/Humanoid#EvaluateStateMachine
- https://create.roblox.com/docs/reference/engine/classes/AlignOrientation
- https://create.roblox.com/docs/reference/engine/classes/BasePart#SetNetworkOwner
- https://create.roblox.com/docs/reference/engine/classes/UserInputService
