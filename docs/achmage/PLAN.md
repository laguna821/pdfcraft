# Achmage PDFCraft 계획 (laguna821/pdfcraft, 독립 배포판)

> 작성: 2026-10-12 · 기준 소스: `Desktop/pdfcraft-main/pdfcraft-main` (upstream v0.6.0, Rust + egui 0.36)
> 근거: 정적 코드 분석만 했고, 앱은 아직 실행하지 않았음. 아래 원인은 Phase 0에서 재현해 확인해야 함.


## 진행 현황 (v0.1.0)

| 항목 | 상태 |
|---|---|
| K1 UI 한글 폰트 (Pretendard 내장 + 시스템 한글 폰트 폴백) | 완료 |
| K2 폰트 재로딩 중 IME 포커스 유지 | 완료 |
| K3 기존 텍스트 편집 저장 (Pretendard Type3, 한자는 시스템 한글 폰트) | 완료 |
| K4 Add Text 한글 (Pretendard 셰이핑, 굵게) / FreeText 주석 한글 (외곽선) | 완료 |
| K5 비임베드 Adobe-Korea1 렌더 폴백 | 완료 |
| K6 명명 CMap 편집 인코딩 (KSC-EUC/UHC) | 미완 — 다음 버전 |
| K7 한글 띄어쓰기 추론 + 검색 자모 정규화 | 완료 |
| K8 ToUnicode 없는 Korea1 추출 (명명 CMap) | 완료 |
| K9 양식 필드 한글 (외곽선) | 완료 |
| K10 한국어 UI 카탈로그 (ko.tsv) + 날짜 | 완료 |
| R1 CI 독립화 · 이름 변경 · 로고 제거 | 완료 |
| R2~R4 설치 스크립트 (Windows/macOS/Linux) + Arch PKGBUILD | 완료 |
| 이름 기반 Identity-H 비임베드 폰트 렌더 | 미완 |
| 한국어 OCR | 범위 밖 |

---

## 1. 현재 상태 진단

### 1-1. 한글 입력이 안 되는 진짜 원인

입력 자체는 문제없을 가능성이 높다.
- Edit 도구는 egui 기본 `TextEdit`을 쓴다. `crates/ui-egui/src/edit_text_ui.rs:996`.
- upstream이 vendored winit에 한국어 IME 패치를 이미 넣어 두었다. MS 한국어 IME, macOS 한국어, Wayland text-input 대응이며 근거는 `vendor/README.md` winit 패치 2~10이다.

원인은 **폰트**다. 증상이 이중으로 겹쳐서 "입력이 안 된다"로 보인다.

| # | 원인 | 위치 | 사용자가 보는 증상 |
|---|---|---|---|
| H1 | UI에 한글 글리프를 가진 폰트가 하나도 없다. 번들은 Inter와 일본어 craft-fonts이고, 시스템 폴백은 segoe/arial이다. | `ui-egui/src/theme.rs:234-330`, `system_fonts.rs:22,125` | 조합 중인 글자와 확정된 글자가 모두 □(tofu)나 빈칸으로 보인다 |
| H2 | 저장할 때 서브셋에 없는 음절을 만나면 Type3 폴백 폰트를 쓰는데, 이 폴백이 **일본어 폰트만** 후보로 본다. | `edit/src/text.rs:992,1060,1112,1137`, `text_regions.rs:338-366` | 적용하면 오류("Japanese fallback font…")가 나거나 되돌려진다 |
| H3 | 문서 폰트를 로딩하는 동안 TextEdit를 그리지 않는다. 이때 포커스와 IME 조합이 끊길 수 있다. | `edit_text_ui.rs:946` | 조합 중이던 글자가 사라지거나 편집이 조기 확정된다 |

### 1-2. 추가로 발견된 한글 관련 결함 (우선순위순)

1. **텍스트 추가, 주석(FreeText), 양식 필드**
	- Add Text는 WinAnsi(서유럽 문자), 아랍어, 태국어만 받는다. 한글은 거부된다 (`edit/src/added.rs:306,935`).
	- 주석은 `/Helv`로 고정되어 있어 appearance에 `?`가 그려진다 (`annot/src/lib.rs:1196`).
	- 정부 양식에 흔한 Identity-H 서브셋 필드도 `?`로 그려진다 (`forms/src/appearance.rs:177`).
2. **폰트가 임베드되지 않은 한글 PDF가 공백으로 렌더된다.** 대상은 HY명조, 바탕, 굴림, 맑은고딕 같은 이름 참조 폰트다. 폴백은 Adobe-Japan1만 처리한다 (`render/src/raster.rs:66-108`).
3. **KSC-EUC-H, KSCms-UHC-H 같은 명명 CMap을 해석하지 못한다.** 이 때문에 편집, 교정(redaction), 양식이 깨진다 (`fonts/src/pdf.rs:571-585,995`).
4. **복사와 검색에서 띄어쓰기가 사라진다.** 한글을 중국어나 일본어처럼 "띄어쓰기 없는 문자"로 처리하기 때문이다. HWP에서 내보낸 PDF에서 특히 심하다 (`render/src/text.rs:669,1258`).
5. **ToUnicode가 없는 임베드 Korea1 CID 폰트에서는 텍스트를 추출하지 못한다** (`vendor/hayro-interpret/src/font/cid.rs:123`).
6. **검색이 NFC 정규화를 하지 않는다.** 자모가 분리된 PDF는 검색에 걸리지 않는다 (`render/src/text.rs:40`).
7. **UI 한국어 번역(`ko.tsv`)이 없고**, 날짜 형식도 없다 (`i18n/mod.rs:139`, `engine/src/dates.rs:59`).
8. **사용자 폰트 로딩이 `.ttc`와 가변 폰트를 거부한다** (`fonts/src/embedding.rs:72-90`).
9. **OCR은 영어만 지원한다** (`ocr/src/lib.rs:24`). 한국어 OCR은 별도 대형 과제로 범위 밖이다.

### 1-3. 릴리즈 인프라 현황

- 릴리즈 파이프라인은 이미 완성되어 있다. 산출물은 MSI와 portable zip(Windows), 유니버설 DMG(macOS), AppImage·deb·rpm·tar.gz·Flatpak(Linux)이다.
- 포크에서 그대로는 동작하지 않는다.
	- `release.yml`이 `storytold/craft-common-actions/...@main`을 호출한다. 고정되지 않은 외부 워크플로다.
	- macOS 잡이 유료 러너 `macos-15-xlarge`를 쓴다.
	- `release` environment가 필요하다.
- 서명 시크릿은 모두 선택 사항이다. 시크릿이 없으면 서명 없이 빌드되고 경고만 남는다.
- 포크에서 바꿔야 하는 storytold 참조:
	- 업데이트 체크: `apps/pdfcraft/src/updates.rs:7`, `crates/ui-egui/src/updates.rs:15`
	- `Cargo.toml:12`
	- metainfo, nfpm, package.sh, README
	- 번들 id `ai.storyteller.pdfcraft` (여러 곳)
- **ArtCraft 로고는 상표다.** 포크에서는 반드시 제거해야 한다 (`ATTRIBUTION.md:225-232`).
- 로컬 툴체인: cargo 1.94.1인데 프로젝트 요구는 `rust-version = 1.95`이므로 `rustup update`가 필요하다.
- 데스크톱의 소스 폴더는 git 저장소가 아니다. 작업은 포크를 clone해서 진행한다.

### 1-4. CachyOS + Niri에서 AppImage가 실패한 이유 (가설)

- AppImage는 정적 type-2 런타임이라 libfuse2는 필요 없다. 다만 FUSE 마운트(`fusermount3`, `/dev/fuse`)는 필요하다.
- 라이브러리를 번들하지 않으므로 wayland, xkbcommon, vulkan을 시스템에서 가져온다.
- Niri는 기본적으로 XWayland가 없다. 앱이 Wayland 네이티브로 뜨지 못하면 실패한다.
- 실제 원인은 터미널 실행 로그로 확인해야 한다. 해결책은 아래 R4에 있다.

---

## 2. 확정된 결정 (2026-10-12, 사용자)

| 결정 | 확정 내용 | 구현 영향 |
|---|---|---|
| **D1. 한글 폰트** | **Pretendard 번들 + 시스템 폰트도 기본 사용** | Pretendard(OFL-1.1)를 저장소에 직접 넣는다. upstream의 "폰트 커밋 금지"와 "Source Han 계열 금지" 규칙(AGENTS.md §1.1·§1.4)은 포크에서 개정하고, `ATTRIBUTION.toml`에 등록하며, `cargo xtask assets` 검사를 통과시킨다. Pretendard의 라틴 글자는 Inter 기반이라 UI 기본 폰트를 Pretendard로 통일할 수 있다. |
| **D2. 포크 성격** | **독립 배포판** | upstream PR 환원은 목표가 아니다. 대신 storytold 인프라 의존(craft-common-actions, craft-fonts 필수 빌드)을 끊고 독자 버전을 쓴다. upstream 수정은 필요할 때만 cherry-pick한다. |
| **D3. 이름** | **Achmage PDFCraft** | 표시 이름 `Achmage PDFCraft`, 앱 ID `io.github.laguna821.AchmagePdfCraft`, 실행 파일 `achmage-pdfcraft`, 설정·로그 경로도 분리해 원본 PdfCraft와 동시에 설치해도 충돌하지 않게 한다. ArtCraft 로고는 제거하고 자체 아이콘을 쓴다. |
| **D4. 배포** | **GitHub Releases에만 올림, 유료 계정 없음** | 서명은 하지 않는다. 대신 "한 줄 설치 스크립트"(§4)로 Windows SmartScreen과 macOS Gatekeeper 경고를 피한다. |

> 참고: Apple 개발자 계정은 "어디에 올리느냐"와 무관하게, 브라우저로 받은 미서명 앱을 macOS가 차단하는 문제(Gatekeeper) 때문에 거론했던 것이다. 아래 curl 설치 스크립트로 계정 없이 해결한다.

---

## 3. 실행 계획

### Phase 0 — 기반 (0.5~1일)
- [ ] 포크를 clone하고 `upstream` remote를 추가한다. `rustup update`로 1.95 이상을 맞춘다.
- [ ] `craft-fonts`를 clone하고 `CRAFT_FONTS_DIR`로 Windows 로컬 빌드와 `cargo test --workspace` 통과를 확인한다.
- [ ] **재현**: `cargo run -p pdfcraft`로 Edit 도구에서 한글을 입력하고 H1/H2/H3을 확인한다. 스크린샷은 `pdfcraft-cli ui --control ... screenshot`으로 찍는다.
- [ ] 한국어 테스트 코퍼스를 만든다. 합성 픽스처만 쓰고 OFL 폰트로 생성한다.
	- Word→PDF (임베드 서브셋)
	- HWP→PDF 형태 (공백 글리프 없음)
	- 비임베드 HYSMyeongJo/Korea1
	- KSC-EUC-H CMap
	- Identity-H 양식 필드
	- 자모 분리 텍스트

### Phase 1 — MVP: "한글이 보이고 써진다" (3~5일) ← **첫 릴리즈 기준**
- [ ] **K1. UI 한글 폰트** (H1)
	- `system_fonts.rs`에 `Need::Hangul`을 추가한다. 검사 글자는 `한` U+D55C다.
	- 폰트 체인: **번들 Pretendard(UI 기본, Regular/Medium/SemiBold)** → 시스템 한글 폰트(Windows `malgun.ttf`, macOS `AppleSDGothicNeo.ttc`, Linux fontconfig 경로의 Nanum/NotoSansKR 등) → 기존 CJK·기타 폴백.
	- 이 체인을 모든 UI 언어에 적용한다 (`theme.rs:234-330`).
	- 실행 파일 크기를 확인한다. Pretendard 정적 TTF는 굵기마다 수 MB라서 필요한 굵기만 넣는다.
	- 편집기의 문서 폰트 목록에 Pretendard와 시스템 한글 폰트를 노출한다 (`edit_text_ui.rs:761-774`).
- [ ] **K2. 포커스 가드** (H3)
	- 폰트를 로딩하는 중에도 폴백 폰트로 TextEdit를 계속 그린다.
	- 테스트: kittest로 `Ime(Enabled→Preedit"ㅎ"→Preedit"한"→Commit"한")`를 주입하고, 초안 텍스트와 글리프가 tofu가 아닌지 확인한다 (`ui-egui/tests/editing.rs`).
- [ ] **K3. 기존 텍스트 편집 저장** (H2)
	- `type3_faces`와 `fallback_face`를 문자 체계(script)별로 일반화하고, 한글 폴백은 **번들 Pretendard**로 한다.
	- 가능하면 Type3 대신 Type0/Identity-H로 **서브셋** 임베드한다 (`embedding::embed` 재사용). 서브셋을 지원하는지 확인한다. 통째로 넣으면 PDF가 수 MB씩 커진다.
	- 원본 문서 폰트의 스타일(명조/고딕)을 판별해 고르는 기능은 2차로 미룬다. 1차는 Pretendard로 통일한다.
	- 오류 메시지를 정정한다 ("Japanese" → 실제로 없는 폰트를 안내).
- [ ] **K4. Add Text / FreeText 한글**
	- `added.rs`에 CJK 경로를 추가한다 (Type0 임베드).
	- 주석 appearance에서 `/Helv` 대신 한글 폰트 리소스를 쓴다.

### Phase 2 — 한국 PDF 호환성 (4~6일)
- [ ] K5. 비임베드 Korea1 폰트와 이름 기반 Identity-H 폰트(Batang/Gulim/Malgun/HY*) 렌더 폴백 (`raster.rs`).
- [ ] K6. 명명 CMap(KSC-EUC/UHC, UniKS-UCS2)의 codespace와 Adobe-Korea1-UCS2 매핑 (`fonts/src/pdf.rs`).
- [ ] K7. 한글 띄어쓰기 추론을 분리한다. 한중일 문자 중 한글만 일반 단어 간격 임계값을 쓴다. 검색은 NFC로 정규화한다.
- [ ] K8. ToUnicode 없는 Korea1 임베드 폰트에서도 UCS2로 추출한다 (vendored hayro 패치).
- [ ] K9. 양식 필드 한글 appearance: Identity-H 서브셋이면 한글 폰트를 추가 임베드한다.

### Phase 3 — 한국어 UI (2~3일, 병행 가능)
- [ ] K10. `ko.tsv` 번역 카탈로그 약 2,100항목. LLM 초벌 번역 후 검수한다. Acrobat 한국어판 용어는 참고만 하고 복사하지 않는다.
- [ ] 날짜 `2026년 10월 12일`, 복수형 규칙 `other`, 시스템 언어 자동 감지.
- [ ] K11. (선택) 사용자 폰트 로딩에서 `.ttc` face index와 가변 폰트 인스턴싱을 지원한다.

### 범위 밖 (추후)
- 한국어 OCR. ocrs에 한국어 모델이 없다. 별도 모델 학습이나 외부 엔진이 필요하다.

---

## 4. 릴리즈 계획 — "무지성 설치"

### 핵심 아이디어: GitHub만으로 경고 없이 설치하기
SmartScreen과 Gatekeeper는 **브라우저로 받은 파일**에 붙는 "인터넷에서 받음" 표시를 보고 경고하거나 차단한다. PowerShell `Invoke-WebRequest`나 `curl`로 받은 파일에는 이 표시가 붙지 않는다. 그래서 저장소에 설치 스크립트를 두고, 스크립트가 GitHub Releases에서 파일을 받아 설치하게 하면 서명 없이도 경고 없이 설치된다. 서버도, 유료 계정도 필요 없다.

```
Windows : irm https://raw.githubusercontent.com/laguna821/pdfcraft/main/install/install.ps1 | iex
macOS   : curl -fsSL https://raw.githubusercontent.com/laguna821/pdfcraft/main/install/install.sh | bash
Linux   : (macOS와 같은 명령, 스크립트가 OS와 배포판을 판별)
```

### R1. CI 독립화 (1~1.5일)
- [ ] `storytold/craft-common-actions` 호출을 없애고, 필요한 잡만 저장소 안의 자체 워크플로로 옮긴다.
	- 대상: Windows x64, macOS 유니버설(무료 `macos-15` 러너), Linux x86_64(+ aarch64 선택).
	- 제거: FreeBSD, riscv64, Windows x86/arm64, web, 서명 단계, `release` environment.
- [ ] craft-fonts 필수 빌드(`CRAFT_FONTS_REQUIRED=1`)를 해제한다. 일본어·중국어 UI 폰트가 필요하면 선택 입력으로 남긴다.
- [ ] 이름 변경(D3): 표시 이름, 앱 ID, 실행 파일, 설정 경로, desktop/metainfo/Info.plist/WiX, 업데이트 체커(`laguna821/pdfcraft` Releases)를 바꾼다.
- [ ] ArtCraft 로고를 제거하고 Achmage 아이콘을 넣는다.
- [ ] 독자 버전: `0.1.0`부터 시작한다. upstream 0.6.0 기반임은 README와 NOTICE에 명시한다(MIT/Apache 고지는 유지).
- [ ] 태그 `v0.1.0` 푸시 → 워크플로가 GitHub Release(draft)에 산출물과 `SHA256SUMS.txt`를 올림 → 검수 → publish.

### R2. Windows
- 산출물: `achmage-pdfcraft-<v>-windows-x64.msi` + portable zip. 정적 CRT라 런타임 설치가 필요 없다.
- **`install.ps1`**: 최신 Release의 MSI를 받아 SHA256을 대조한 뒤 `msiexec /i … /qb`로 설치한다. 관리자 권한(UAC) 확인 창은 한 번 뜬다.
	- 대안: 관리자 권한 없이 portable zip을 `%LOCALAPPDATA%\Programs`에 풀고 시작 메뉴 바로가기를 만든다. 옵션으로 제공한다.
- 브라우저로 MSI를 직접 받는 사람은 SmartScreen에서 "추가 정보 → 실행"을 눌러야 한다. README에 안내한다.

### R3. macOS
- 산출물: 유니버설 DMG + `.app` zip (ad-hoc 서명).
- **`install.sh`**: zip을 curl로 받아 SHA256을 대조하고 `/Applications`(또는 `~/Applications`)에 복사한다. 이렇게 받은 파일에는 차단 표시가 없어 바로 실행된다. 안전을 위해 `xattr -dr com.apple.quarantine`도 함께 실행한다.
- DMG를 브라우저로 받은 사람에게는 README에 "시스템 설정 → 개인정보 보호 및 보안 → 그래도 열기" 또는 xattr 한 줄을 안내한다.
- 선택: 별도 GitHub 저장소 `laguna821/homebrew-tap`에 cask를 두면 `brew install --cask laguna821/tap/achmage-pdfcraft`도 된다(역시 GitHub만 사용).

### R4. Linux — CachyOS + Niri 기준
`install.sh`가 배포판을 판별해 다음 순서로 설치한다.
1. **Arch 계열(CachyOS)**: 저장소의 `packaging/arch/PKGBUILD`(바이너리 패키지)를 받아 `makepkg -si`로 설치한다. pacman이 관리하므로 `pacman -R achmage-pdfcraft-bin`으로 깔끔하게 제거할 수 있다.
	- `depends=(glibc gcc-libs libxkbcommon wayland vulkan-icd-loader)`
	- `optdepends=(mesa libglvnd xdg-desktop-portal-gnome cups zenity fcitx5-hangul)`
	- FUSE, XWayland, 샌드박스가 모두 필요 없다. 릴리즈 워크플로가 PKGBUILD의 버전과 sha256을 자동으로 갱신한다.
	- (AUR에도 올리면 `paru -S`가 가능하지만, GitHub 전용 방침에 따라 선택 사항으로 둔다.)
2. **Debian/Ubuntu·Fedora 계열**: `.deb` / `.rpm`.
3. **그 밖의 배포판**: tar.gz를 `~/.local`에 풀고 desktop 파일과 아이콘을 등록한다(root 불필요).
4. Flatpak과 AppImage는 Releases에 함께 올리되 보조 수단으로 둔다. AppImage가 실패하면 `--appimage-extract-and-run`, 렌더 문제가 있으면 `PDFCRAFT_RENDERER=gl`을 안내한다.

Niri 체크리스트 (실기기 검증):
- [ ] XWayland 없이 Wayland 네이티브로 기동되는지
- [ ] 파일 대화상자: `xdg-desktop-portal-gnome`이 있을 때와 zenity 폴백일 때
- [ ] fcitx5-hangul 입력 (text-input-v3)
- [ ] 장식: 클라이언트 측 장식(CSD) 회색 타이틀바 (미관 문제), `prefer-no-csd` 설정 시 동작
- [ ] 다중 GPU에서 GPU 선택, Vulkan과 GL 폴백

### R5. 검증 매트릭스 (릴리즈 게이트)
| 항목 | Win11 | macOS | CachyOS/Niri |
|---|---|---|---|
| 설치 한 줄 (경고 없음 확인) | install.ps1 | install.sh | install.sh → makepkg |
| 한글 IME 입력 (Edit, Add Text, 주석, 양식, 찾기) | MS IME | macOS 한국어 | fcitx5 |
| 한글 저장 후 Acrobat/Chrome에서 재열기 | ✓ | ✓ | ✓ |
| 코퍼스 렌더·추출·검색 | ✓ | ✓ | ✓ |

---

## 5. 순서 요약

```
Phase 0 (재현) → Phase 1 K1–K4 + R1 CI 독립화·이름 변경 + 설치 스크립트 ─▶ v0.1.0 (MVP 릴리즈)
                → Phase 2 K5–K9 ─▶ v0.2.0
                → Phase 3 한국어 UI (기본 언어 자동 감지) ─▶ v0.3.0
```

총 예상: MVP 약 1.5~2주, 전체 약 3~4주 (에이전트 병렬 작업 기준이며 실기기 검증 시간은 별도).

독립 배포판이므로 upstream 변경은 보안·크래시 수정 위주로 필요할 때만 cherry-pick한다.
