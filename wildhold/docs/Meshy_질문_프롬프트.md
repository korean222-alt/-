# Meshy AI 사용법을 다른 AI 에게 물어보기 위한 프롬프트

> 아래 "복사할 프롬프트" 부분을 통째로 ChatGPT·Gemini 같은 AI 에게 붙여 넣으세요.
> 그 AI 가 Meshy 화면을 한 단계씩 안내해 줍니다. 막히면 **Meshy 화면을 스크린샷으로 찍어서** 그 AI 에게 보여주세요.
> 결과 파일은 다음 Claude 채팅에 가져오면 게임에 넣어 줍니다.

---

## 복사할 프롬프트

```
나는 Roblox 게임을 만드는 초보자야. 3D 도 거의 몰라.
Meshy AI(meshy.ai) 로 게임에 넣을 "펫" 3D 모델을 만들고 싶어.
게임에 넣는 작업(Roblox Studio, 코드)은 다른 AI(Claude)가 해 주니까,
너는 Meshy 에서 모델을 만들고 파일을 내려받는 데까지만 아주 쉽게 한 단계씩 알려줘.

[중요]
- Meshy 화면과 메뉴 이름은 자주 바뀌니까, 네가 아는 내용이 예전 것일 수 있다고 먼저 말해 주고,
  확실하지 않으면 내가 스크린샷을 보여 주면 거기에 맞춰 알려줘.
- 한 번에 너무 많이 말하지 말고, 단계마다 내가 "했어" 라고 하면 다음 단계로 넘어가 줘.
- 돈은 최대한 안 쓰고 싶어. 무료 플랜(월 100크레딧)으로 먼저 1마리를 만들어 보고,
  크레딧이 얼마나 드는지 단계마다 알려줘. 유료가 꼭 필요하면 이유를 먼저 말해 줘.
- 무료 플랜 결과물의 라이선스(CC BY 4.0, 출처 표기)가 맞는지 확인하고, 게임 설명에 넣을 출처 문구를 알려줘.

[만들 것] 네 발로 걷는 사나운 판타지 펫 1마리 (아래 "펫 설명" 참고)

[내가 원하는 순서]
1. 콘셉트 그림 만들기
   - Meshy 안의 이미지 생성 기능이 있으면 그걸로, 없으면 무료 이미지 생성 AI 로 만드는 법을 알려줘.
   - 3D 로 바꾸기 좋은 그림 조건을 지켜야 해: 한 마리만, 네 발로 서 있는 옆 45도 전신, 머리부터 꼬리 끝까지 다 보이게,
     단색 밝은 배경, 그림자·글자·다른 물체 없음.
2. 그림 → 3D 모델 (Image to 3D)
   - 텍스처 켜기, 좌우 대칭 켜기
   - 삼각형 수(폴리곤)는 약 1만 개 이하로 (모바일 게임이라 가볍게). 옵션 이름이 다르면 비슷한 걸 알려줘.
   - 결과가 여러 개 나오면 다리 4개가 또렷하고 뒷모습이 이상하지 않은 걸 고르는 법도 알려줘.
3. 자동 리깅 (뼈 넣기)
   - 몸 종류는 네 발 동물(Quadruped)로
   - 관절 위치를 찍으라고 하면 어디에 찍는지 쉽게 알려줘.
4. 동작(애니메이션) 입히기
   - 가능하면: 대기(Idle), 걷기(Walk), 달리기(Run), 공격(Attack), 쓰러짐(Death/Fall), 피격(Hit)
   - 네 발 동물용 동작이 적다고 들었어. 있는 것만 고르고, 없는 건 없다고 알려줘.
5. 내려받기
   - FBX 형식으로: 뼈가 들어 있는 모델 + 각 동작 (동작마다 파일이 따로 나오면 따로 받기)
   - 같은 모델을 GLB 형식으로도 한 번 받기
   - 텍스처 이미지(png)가 따로 있으면 그것도
   - 파일 이름은 이렇게 바꿔서 저장: Cinderfang_model.fbx, Cinderfang_idle.fbx, Cinderfang_walk.fbx ... (종 이름_동작)
6. 마지막에 정리해 줘
   - 내가 받은 파일 목록, 쓴 크레딧, 고른 옵션(모델 버전, 폴리곤 수, 리깅 종류, 동작 이름),
     그리고 출처 표기 문구 → 이걸 Claude 에게 그대로 전달할 거야.

[펫 설명] (첫 번째로 만들 펫)
이름: 신더팽 (Cinderfang) — 불 속성 늑대형 짐승. 게임에서 원거리 불 공격을 한다.
모습: 흑요석처럼 검고 단단한 피부, 갈라진 틈 사이로 주황색 용암빛이 새어 나옴,
목덜미와 꼬리 끝에 불꽃 갈기, 날카로운 귀, 노란 발광 눈, 굵은 앞다리와 발톱.
분위기: 만화풍 3D 게임 캐릭터인데 사납고 멋있게. 사실적인 동물 X, 잔인함 X (어린이도 하는 게임).
기존 유명 게임(포켓몬, ARK 등) 캐릭터와 비슷하게 만들지 말 것.
```

---

## 그림 만들 때 쓸 영어 프롬프트 (이미지 AI 에 그대로 붙여 넣기)

> 이미지 생성 AI 는 영어 프롬프트가 더 잘 됩니다. 1번(신더팽)부터 해 보세요.

**공통 뒷부분** (각 펫 설명 뒤에 붙이기)
```
original fantasy creature for a stylized 3D survival game, standing on all four legs,
full body in a three-quarter side view, entire creature from head to tail inside the frame,
plain light grey background, soft even lighting, no ground shadow, no text, no other objects,
stylized hand-painted game art, chunky readable silhouette, fierce but not gory, kid-friendly
```

| 순서 | 이름 (속성 · 역할) | 앞부분 (영어) |
|---|---|---|
| 1 | 신더팽 Cinderfang (불 · 원거리) | `a wolf-like beast with cracked obsidian-black skin, glowing orange lava light seeping through the cracks, a flaming mane on its neck and a fire-tipped tail, sharp ears, glowing yellow eyes, thick front legs with claws,` |
| 2 | 쏜링스 Thornlynx (풀 · 빠른 근접) | `a lean lynx-like predator covered in dark green moss fur, bark-like armor plates and thorn spikes along its back, leaf tufts on the ear tips, glowing green eyes, long agile legs,` |
| 3 | 타이드백 Tideback (물 · 탱커) | `a heavy armored beast like a snapping turtle crossed with a bull, a huge spiked stone-blue shell with barnacles, glowing teal bioluminescent spots, thick stumpy legs, a hooked beak,` |
| 4 | 브라이어혼 α Briarhorn (풀 · 알파 보스) | `a massive stag-like alpha beast with huge antlers made of thorny briar vines, a wooden skull-like face mask, a shaggy moss mane, dark bark-textured body, faint green light glowing from the antler thorns,` |

지금 있는 귀여운 펫(모슬링·엠버펍·셸버브)은 **새끼 단계**로 쓰고, 위 1~3번은 각각의 **성체**, 4번은 알파입니다.
(모슬링 → 쏜링스, 엠버펍 → 신더팽, 셸버브 → 타이드백)

---

## Claude 에게 가져올 것 (펫 1마리당)

- [ ] 원본 콘셉트 그림 (png/jpg)
- [ ] 뼈가 들어간 모델 FBX (`이름_model.fbx`)
- [ ] 동작 FBX 들 (`이름_idle.fbx`, `이름_walk.fbx` …) — 한 파일에 다 들어 있으면 그 파일 하나
- [ ] 같은 모델 GLB (`이름_model.glb`)
- [ ] 텍스처 png (따로 있으면)
- [ ] 다른 AI 가 마지막에 정리해 준 내용 (옵션, 크레딧, 출처 표기 문구)
