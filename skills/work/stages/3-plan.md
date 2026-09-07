# 3. plan — 구현 계획과 브랜치

## 입력

- `확정된 범위` (2-scope 출력)
- `base`, `branch_prefix`, `owner` (사전 확인)
- 설정 `project`, `project_owner` (있으면)

## 절차

1. 범위를 **순서 있는 단계**로 쪼갠다. 단계마다 네 가지를 적는다.
   ```
   1. <할 일 한 문장>
      파일    src/…/CancelService.java (수정), src/…/StockRestorer.java (신규)
      검증    ./gradlew :order:test --tests "*CancelServiceTest*"
      커밋    feat(order): 주문 취소 시 재고 복원 호출
   ```
   - 검증 명령은 프로젝트의 **실제 명령**을 찾아 적는다 (`build.gradle`·`package.json`·`Makefile`·CI 워크플로우·CLAUDE.md). 못 찾으면 사용자에게 묻는다. "적절한 테스트"라고 쓰지 않는다. 검증 수단이 정말 없는 프로젝트면 "자동 검증 수단 없음 — 수동 확인: …"으로 적는다.
   - 계획 끝에 **전체 검증 명령**(ship 단계에서 한 번 더 돌릴 것)을 따로 적는다.
   - 테스트가 필요한 단계는 테스트 작성을 먼저 두고 구현을 뒤에 둔다.
   - 한 단계는 커밋 하나. 3~7단계가 보통이다. 10을 넘으면 범위가 크다.

2. 계획 코멘트 draft를 만든다. 이전 `plan` 코멘트를 갱신하는 것이면 둘째 줄에 "(이전 계획 대체)"를 적는다.
   ```
   <!-- agentic-devflow:plan -->
   ## 구현 계획
   (위 형식 그대로)
   ```

3. 승인 후 순서대로 실행한다. **재개로 이 단계에 들어왔고 계획 코멘트가 이미 있으면 3-3부터 시작한다.**
   1. 코멘트 게시: `gh issue comment <n> --body-file <임시파일>`. **실패하면 중단**한다. 브랜치를 만들지 않는다. 게시되지 않은 계획으로 진행하면 다음 세션이 계획을 잃는다.
   2. assignee가 없으면: `gh issue edit <n> --add-assignee @me`. 실패는 경고만.
   3. 브랜치 생성:
      ```bash
      git branch -a --format='%(refname:short)' | grep -E "^(origin/)?<prefix><n>-"   # 동명 브랜치 확인 (원격 포함)
      git fetch origin <base>
      git checkout -b <branch_prefix><n>-<slug> origin/<base>
      ```
      slug는 이슈 제목을 영문 kebab-case로 옮긴 것. 소문자, 5단어 내외, 관사·조사 생략. 예: "주문 취소 시 재고 복원" → `restore-stock-on-cancel`.
      같은 이슈 번호의 브랜치가 로컬이나 원격에 이미 있으면 알리고 그것을 쓸지 묻는다. 덮어쓰지 않는다. `git fetch`가 실패하면 중단하고 원인을 보고한다.
   4. 설정 `project`가 있으면 Status를 **In progress**로 바꾼다. owner는 `project_owner`, 없으면 레포 owner.
      ```bash
      gh project view <project> --owner <owner> --format json --jq .id                     # 프로젝트 노드 ID (PVT_…)
      gh project item-list <project> --owner <owner> --format json --limit 500 \
        --jq '.items[] | select(.content.number == <n>) | .id'                              # 이슈의 item ID (PVTI_…)
      gh project field-list <project> --owner <owner> --format json --limit 100 \
        --jq '.fields[] | select(.name == "Status")
              | {id, option: ((.options[] | select(.name | ascii_downcase == "in progress") | .id)
                              // error("Status 옵션 In Progress 없음"))}'
      gh project item-edit --project-id <PVT_…> --id <PVTI_…> --field-id <PVTSSF_…> --single-select-option-id <opt>
      ```
      이슈가 Project에 없으면 먼저 넣는다: `gh project item-add <project> --owner <owner> --url <이슈 URL>`.
      옵션명은 대소문자 무관으로 맞춘다 (GitHub 기본 템플릿은 `In Progress`). 위 jq는 옵션을 못 찾으면 빈 출력이 아니라 오류를 내므로 실패가 드러난다. 실패하면 경고를 남기고 계속한다. 경고에는 처방을 넣는다 — 토큰에 `project` 스코프가 없으면 "`gh auth refresh -s project` 후 수동으로 옮기세요". 이 경고는 이 단계의 출력과 완료 보고의 `보드` 줄에 남아야 한다.

## 게이트

1. **계획 승인** — 계획을 보여주고 묻는다: "이 계획으로 구현할까요?" 순서·검증 명령·커밋 단위에 대한 이견을 반영한다.
2. **코멘트 게시** — draft 승인 후 게시.

브랜치 생성·assignee 지정·Status 변경은 계획 승인에 포함된 것으로 본다 (별도 질문 없음).

## 출력

- `계획` (승인된 최종본, 전체 검증 명령 포함)
- 브랜치명, 분기점 SHA (`git rev-parse --short origin/<base>`)
- 계획 코멘트 URL
- 보드: `In progress로 변경` 또는 `변경 실패 — <원인>. <처방>` 또는 `설정 없음 (건너뜀)`
