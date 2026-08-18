# tests/ — 자동 테스트

PHASE 1부터 자동 테스트 러너는 **자체 `SceneTree` 스크립트**를 사용한다 (`DECISIONS D-015`).
GUT 같은 외부 플러그인은 현재 도입하지 않는다.

## 러너 원칙

- 기본 러너: `res://tests/runner.gd` (`extends SceneTree`)
- 기본 실행:

```bash
godot --headless --path . --script res://tests/runner.gd
```

- 러너는 **테스트 발견/실행/결과 집계/종료 코드**만 담당한다.
- 테스트 본문은 가능한 한 **순수 함수 + 작은 assertion helper**로 작성한다.
- 테스트가 하나라도 실패하면 프로세스는 **non-zero exit code**로 종료한다.
- 게임 코드는 테스트 러너를 import하거나 의존하지 않는다.
- fixture/mock/비동기 테스트/CI 리포팅 때문에 자체 runner/helper 유지비가 실제로 커지면
  GUT 등 외부 프레임워크를 재검토한다. 테스트 본문을 프레임워크 중립으로 유지해 전환 비용을 낮춘다.

Godot의 `SceneTree`는 기본 `MainLoop`이고 `--script`로 MainLoop 스크립트를 직접 실행할 수 있으므로,
PHASE 1~3의 데이터/로직 단언은 별도 플러그인 없이 headless로 검증한다.

## 먼저 들어올 테스트 (개발 가이드 §13)

- 프레임 독립성 — 다른 delta sequence에서도 동일 시간의 이동 거리가 같음
- 8방향 대각 정규화 — 대각 이동이 직선보다 빠르지 않음
- 1층 고정성 — 시드를 바꿔도 지형 동일
- 동적 배치 결정성 — 재로드 시 전리품/유배자/상태 불변
- 경로 보장 — 시드 100~1000개에서 시작점→계단 접근 불가 0건
- **함정 단서 강제** — 치명 함정의 `clues[]`가 비면 실패
- 정보 비대칭 — 미발견 함정·계단·비밀 누출 없음
- **NPC LOD 결정성** — 같은 seed/논리 시간에서 플레이어 경로로 LOD 전환 시점이 달라도
  NPC Canon 상태와 외부 사건 로그가 동일 (`D-014`, `NPC-005`; PHASE 7)
