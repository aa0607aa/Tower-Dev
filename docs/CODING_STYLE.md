# CODING_STYLE.md — 「탑」 코딩 규칙

GDScript 공식 스타일 가이드를 기본으로 따르고, 이 프로젝트에만 필요한 규칙을 추가한다.
<https://docs.godotengine.org/en/4.7/tutorials/scripting/gdscript/gdscript_styleguide.html>

---

## 1. 서식

- 들여쓰기는 **탭**. (Godot 에디터 기본)
- 파일당 클래스 하나. 파일명은 `snake_case.gd`, `class_name`은 `PascalCase`.
- 씬 파일은 `PascalCase.tscn`.
- 함수·변수는 `snake_case`, 상수는 `UPPER_SNAKE_CASE`, private은 `_` 접두사.
- 시그널은 과거형 동사구: `trap_triggered`, `stair_discovered`.
- 최대 줄 길이 100자 목표(강제 아님).

## 2. 타입

- **정적 타입을 항상 쓴다.** `var hp: int = 0`, `func damage(amount: float) -> void:`
  런타임 타입 오류를 컴파일 시점으로 당기는 것이 이 프로젝트에선 특히 중요하다
  (세이브/로드 결정성이 깨지면 재현이 어렵다).
- 반환값이 없으면 `-> void`를 생략하지 않는다.

## 3. 아키텍처 규칙 (개발 가이드 §4 SSOT)

- **시각 오브젝트와 데이터 객체를 분리한다.** 스프라이트가 화면에서 사라져도 데이터는 살아 있다.
  → 노드가 게임 데이터를 소유하지 않는다. 노드는 데이터를 *표시*한다.
- **한 시스템이 다른 시스템의 내부 데이터를 직접 수정하지 않는다.** 시그널 또는 서비스 계층을 거친다.
- **AI는 GameState를 직접 mutate하지 않는다.** `scripts/ai/`는 구조화된 제안만 반환하고,
  적용은 검증기를 거친다. `scripts/ai/`에서 게임 상태 객체에 쓰기(write)하는 코드는 리뷰에서 거부한다.
- **모든 랜덤은 시드를 저장한다.** `randi()` 전역 RNG를 게임 로직에 쓰지 않는다.
  `RandomNumberGenerator`를 시드와 함께 상태에 보관한다.

## 4. 수치 · canon

- canon 상수는 `data/canon/canon.gd`에서만 온다. 3600, 10 같은 숫자를 로직에 직접 쓰지 않는다.
- 밸런스 튜닝 대상(DESIGN)은 하드코딩하지 않고 `data/curves/` 등 데이터 파일로 뺀다.
- **[TBD] 수치를 "일단 임의로" 채우지 않는다.** 필요하면 `[CANON CONFLICT]`로 오너에게 올린다.
  (COLLABORATION_PROTOCOL.md §2)

## 5. 노드 · 씬

- 구 `TileMap` 노드는 deprecated → **신규 구현은 `TileMapLayer` + TileSet만** 사용한다.
- 도트 텍스처 필터는 **nearest**. 프로젝트 설정에서 전역으로 잡아뒀으므로 노드별로 다시 지정하지 않는다.
- `@onready`로 잡는 자식 노드 경로는 씬 구조 변경에 약하므로, 씬을 바꿀 때 함께 확인한다.

## 6. 주석

- "무엇을 하는가"보다 **"왜 이렇게 했는가"**를 적는다. 특히 canon 근거가 있는 코드에는
  근거를 남긴다: `## D-010: 서든데스는 3600초 (DECISIONS.md)`.
- 한국어 주석을 기본으로 한다. 식별자는 영문.

## 7. 커밋

- 형식: `<type>: <한 줄 요약>` — `feat` / `fix` / `docs` / `refactor` / `test` / `chore`.
- 하나의 커밋은 하나의 작은 기능 묶음. (개발 가이드 §14)
- **실행·테스트하지 않은 코드를 "완료"라고 쓰지 않는다.** 커밋 메시지와 WORK REPORT에
  IMPLEMENTED / VERIFIED / PLAYTESTED 등급을 정확히 적는다.
