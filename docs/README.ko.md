<p align="center">
  <img src="https://raw.githubusercontent.com/Cerynna/CorpSR/main/art/icons-coin-64.png" width="96" alt="CorpSR">
</p>

<h1 align="center">CorpSR</h1>

<p align="center">
  <b>포인트 기반 길드 소프트 예약(SR), 모든 것을 게임 안에서.</b><br>
  월드 오브 워크래프트 클래식 · “Forever” 클라이언트 (Interface 16001)
</p>

<p align="center">
  <a href="https://github.com/Cerynna/CorpSR/blob/main/README.md">English</a> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.fr.md">Français</a> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.de.md">Deutsch</a> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.es.md">Español</a> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.pt.md">Português</a> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.it.md">Italiano</a> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.ru.md">Русский</a> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.zh-CN.md">简体中文</a> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.zh-TW.md">繁體中文</a> ·
  <b>한국어</b>
</p>

![내 SR](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/MesSR.png)

CorpSR은 길드의 소프트 예약(SR)을 게임 안에서 관리합니다. 각 길드원은 원하는 아이템을 예약하고, 전리품 담당자가 분배하며, 애드온이 `/roll`을 읽어 순위를 매기고 기록을 남깁니다. SR로 아이템을 놓칠 때마다 그 아이템에 포인트가 쌓여 다음 주사위가 더 강해집니다.

웹사이트도, 내보내기도, 스프레드시트도 없습니다. 데이터는 길드 애드온 채널로만 오가며, 모든 길드원이 전체 사본을 가집니다. 관리자가 접속하지 않아도 아무것도 잃지 않습니다.

## 기능

- **주간 SR**: 주당 2개(길드장 설정), 어느 공격대의 어떤 아이템이든 가능. 이중 SR 허용.
- **포인트**: 예약한 아이템을 놓치면 → 그 아이템에 +10 포인트. SR 주사위 = 주사위 + 포인트.
- **명확한 우선순위**: SR > +1 > +1 획득함 > +2 > 형상변환, 주사위 범위로 판단.
- **공격대원 창**: 아이템, 내 포인트, 주사위 종류별 버튼, 시간 막대, “포기”.
- **분배 창**(전리품 담당자용): 실시간 주사위, 동점, 원하는 승자 지정, 남은 아이템(길드 은행, 마력 추출).
- **공격대 알림**: 각 아이템의 시작과 끝에 알림.
- **전달**: 거래 시도, 준비된 귓속말, 아직 전달할 목록, 이번 세션의 마력 추출 담당자.
- **귓속말 `!SR`**: 길드 밖의 플레이어(PUG)와 애드온이 없는 모든 사람용, 설치할 필요 없음.
- **전체 기록**: 모든 것이 기록되며, 수정과 취소에는 사유가 필요하고 되돌릴 수 있습니다.
- **길드장 설정**: 값과 등급별 권한, 전체 초기화.
- **체험 모드**: 길드에 아무것도 보내지 않고 모든 기능을 시험해 볼 수 있습니다.
- **10개 언어**: 영어, 프랑스어, 독일어, 스페인어, 포르투갈어, 이탈리아어, 러시아어, 중국어 간체·번체, 한국어.

## 규칙

| 주사위 종류 | 주사위 | 합계 |
|---|---|---|
| **SR** | `/roll 110` | 주사위 + 그 아이템의 내 포인트 |
| **+1** (주 전문화) | `/roll 100` | 주사위 |
| **+1 획득함** (주 전문화, 이번 주에 +1로 이미 아이템을 얻음) | `/roll 100` | 주사위 |
| **+2** (보조 전문화) | `/roll 50` | 주사위 |
| **형상변환** | `/roll 20` | 주사위 |

- **더 높은 분류가 이깁니다.** 주사위 값과 상관없이 SR은 항상 +1을 이깁니다. 같은 분류 안에서는 합계가 가장 높은 사람이 이깁니다. 동점이면 동점자끼리 다시 굴립니다.
- **포인트**: 이미 가진 포인트로 굴립니다(처음에는 0). 아이템 주사위가 끝나면, 그 아이템을 예약했고 공격대에 있었으며 얻지 못한 모든 사람이 그 아이템에 **SR당 +10**(이중 SR은 +20)을 얻습니다. 승자는 포인트를 얻지 않으며, SR로 이겼다면 그 아이템의 포인트가 0이 됩니다. “포기”를 누른 사람도 포인트를 얻지 않습니다.
- **포인트는 남아 있습니다**: 예약 아이템을 바꾸면 이전 아이템의 포인트는 다시 예약할 때까지 보관됩니다.
- **얻은 아이템은 그 주의 SR을 소모합니다**: 여러 보스가 떨어뜨리는 아이템이라도 다음 주까지는 SR로 다시 굴릴 수 없습니다.
- **+1 획득함**: 그 주(또는 세션, 길드장 설정)에 +1로 처음 이긴 순간부터. SR, +2, 형상변환으로 얻은 것은 포함되지 않습니다.
- **처음 유효한 주사위만 인정됩니다.** N개가 떨어지면 상위 N명이 이깁니다.
- **PUG**(길드 밖의 플레이어)도 길드원과 똑같은 규칙을 따릅니다: SR(`!SR` 귓속말), 포인트, 모든 주사위 종류.
- 모든 값(포인트, SR 개수, 이중 SR, 주사위 범위)은 길드장 설정입니다.

## 공격대 일정

**관리자**

1. **일정** 탭 → **새 세션**.
2. 전리품 담당자가 보스의 전리품을 열면 **분배 창**이 자동으로 열립니다. 가방의 아이템을 Alt + 왼쪽 클릭해도 됩니다.
3. 아이템을 고르고 **시작**: 클릭하면 공격대 대화에 아이템, 주사위 범위, 시간이 알려집니다.
4. 주사위가 실시간으로 들어옵니다. 시간이 끝나면 **확정**(또는 **동점 재굴림**): 클릭하면 승자가 알려집니다.
5. CorpSR이 승자와 거래를 열어 아이템을 올려 둡니다. 안 되면 버튼에 귓속말이 준비됩니다. **전달 대기** 탭이 누구에게 무엇을 줘야 하는지 기억합니다.
6. 아무도 원하지 않나요? 길드 은행 또는 마력 추출.

![분배 창](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/Attribution.png)

**공격대원**

- **내 SR** 탭: 아이템을 클릭하면 예약, 한 번 더 클릭하면 이중 SR, 오른쪽 클릭으로 하나 제거. 그 주 첫 아이템의 주사위가 시작되면(또는 관리자가 잠그면) SR이 잠깁니다.
- 아이템이 떨어지면 **주사위 창**이 굴릴 수 있는 종류를 보여 줍니다. 클릭 한 번으로 알맞은 `/roll`을 대신 굴려 줍니다.

<p align="center">
  <img src="https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/Raideur.png" width="450" alt="공격대원 창">
</p>

- **포인트** 탭: 모두의 포인트를 아이템별로. **기록** 탭: 일어난 모든 일, 누가 언제 했는지.
- PUG이거나 애드온이 없나요? 관리자에게 `!SR [아이템] [아이템]`을 귓속말하세요(아이템 링크, 붙여도 띄워도 되고, 아이템 번호도 가능). `!SR`만 보내면 이번 주 SR을 알려 줍니다.

## 등급별 권한

길드장이 등급마다 누가 무엇을 할 수 있는지 정합니다(설정 탭). 자기 SR을 정하는 데는 권한이 필요 없습니다.

| 권한 | 할 수 있는 일 |
|---|---|
| **일정** | 세션 열기, 잠그기, 닫기, 다시 열기, 이름 바꾸기, 삭제; `!SR`을 귓속말한 플레이어(PUG 또는 길드원)의 SR 등록 |
| **분배** | 아이템 주사위 시작, 주사위 읽기, 승자 확정, 길드 은행 또는 마력 추출로 보내기 |
| **수정** | 아이템별 플레이어 포인트 수정, 사유 필수 |
| **취소** | 기록 한 줄 취소, 사유 필수 |
| **아이템** | 알려진 아이템에서 제거(추가는 누구나 가능) |

## 명령어

| 명령어 | 효과 |
|---|---|
| `/csr` | CorpSR 창 열기/닫기 |
| `/csr attrib` | 분배 창 열기/닫기(미니맵 버튼 오른쪽 클릭도 가능) |
| `/csr demo` | 체험 모드 시작/중지 |
| `/csr minimap` | 미니맵 버튼 표시/숨기기 |
| `/csr sync` | 길드에 최신 데이터 요청 |

CorpSR은 **길드 및 커뮤니티** 창에 탭을 추가하고, [CorpUI](https://github.com/Cerynna/CorpUI)(선택)가 설치되어 있으면 `/corp`에 페이지를 추가합니다.

## 알아 둘 점

- **게임은 애드온이 스스로 대화창에 쓰거나 귓속말하는 것을 금지합니다.** 그래서 알림과 귓속말은 버튼을 거칩니다. 직접 입력한 것처럼 클릭이 메시지를 보냅니다. 이 버튼들은 전투 중에 숨겨집니다.
- **인스턴스 안에서는** 귓속말 내용이 애드온에 숨겨질 수 있으니 들어가기 전에 `!SR`을 보내세요.
- 데이터는 애드온 채널을 통해 **내 길드와만** 공유됩니다. 게임 밖으로 나가는 것은 없습니다.

## 설치

- **Wago**: [addons.wago.io/addons/corpsr](https://addons.wago.io/addons/corpsr), Wago 앱 또는 수동 설치.
- **수동**: `CorpSR` 폴더를 WoW 클래식 폴더의 `Interface\AddOns`에 넣고 게임을 다시 시작하세요.

## 스크린샷

| | |
|---|---|
| ![포인트](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/Points.png) | ![기록](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/Historique.png) |
| ![일정](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/Session.png) | ![전달 대기](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/Remise.png) |
| ![설정](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/Reglages.png) | ![알려진 아이템](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/Raids.png) |

스크린샷의 애드온은 영어로 표시되어 있으며, 게임에서는 한국어로 나옵니다. 모든 창의 영어·프랑스어 이미지: [`docs/images`](https://github.com/Cerynna/CorpSR/tree/main/docs/images). 체험 모드에서 애드온의 실제 배치를 그대로 그린 이미지입니다.

## 개발

코드 구성, 자세한 규칙, 테스트(프랑스어): [`docs/DEVELOPMENT.md`](https://github.com/Cerynna/CorpSR/blob/main/docs/DEVELOPMENT.md).
