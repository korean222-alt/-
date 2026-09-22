# 사용자 이미지 적용

이미지 픽셀은 수정하지 않았습니다. 사용자가 지정한 세 파일만 최종 배포 자료에 포함합니다.

| 용도 | 파일 | 원본 |
|---|---|---|
| 게임 프로필 / 아이콘 (1:1) | `game_profile.jpeg` | `233A8331-F02C-409F-9E4C-1E4028F8C460.jpeg` |
| 게임 썸네일 (16:9) | `game_thumbnail.jpeg` | `75FB0ED7-6CAA-4642-A1BE-3CC975FFB52A.jpeg` |
| 상점 버튼 (1:1) | `shop_button.jpeg` | `BB6E571A-9101-4317-AD73-08E6F0A89C20.jpeg` |

## Roblox에서 필요한 마지막 연결

1. 프로필 이미지와 썸네일은 이 경험의 Creator Dashboard 이미지 설정에서 각각 업로드합니다.
2. `shop_button.jpeg`는 Studio의 Asset Manager에서 이미지로 업로드합니다.
3. 발급된 **이미지 에셋 ID**를 `ReplicatedStorage > CursedBarrel > Shared > ReleaseConfig`의 `Branding.ShopImage`에 넣습니다.
4. Play를 눌러 왼쪽 아래의 정사각형 상점 버튼에 세 번째 이미지가 표시되는지 확인합니다.

예: `ShopImage = 발급된_숫자_ID` (따옴표 없이 숫자).

실제 계정에서 업로드/검토하지 않았으므로 ID는 임의로 만들지 않고 `0`으로 두었습니다. ID가 0인 동안에는 기능이 작동하는 SHOP 텍스트 버튼이 대신 보입니다. 로컬 JPEG 경로나 ChatGPT 파일 ID는 Roblox 이미지 ID로 사용할 수 없습니다.
