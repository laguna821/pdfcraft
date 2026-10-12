<p align="center">
  <img src="assets/app-icon/pdfcraft-small.svg" alt="" width="96">
</p>

<h1 align="center">Achmage PDFCraft</h1>

<p align="center">
  <b>한글이 되는 오픈소스 PDF 편집기</b><br>
  Windows · macOS · Linux (CachyOS/Arch + Niri 포함)
</p>

Achmage PDFCraft는 [PdfCraft](https://github.com/storytold/pdfcraft)(Rust로 만든 오픈소스 PDF
작업 도구)를 기반으로 한 **독립 배포판**입니다. 원본은 기능이 뛰어나지만 한글 표시·입력·편집이
거의 되지 않았습니다. 이 배포판은 그 부분을 고치고, 세 운영체제 모두 명령 한 줄로 설치되게
했습니다.

## 설치 (명령 한 줄)

**Windows 10/11**: PowerShell을 열고

```powershell
irm https://raw.githubusercontent.com/laguna821/pdfcraft/main/install/install.ps1 | iex
```

관리자 권한 확인 창이 한 번 뜹니다. 관리자 권한 없이 설치하려면 먼저
`$env:ACHMAGE_PORTABLE = 1` 을 입력한 뒤 위 명령을 실행하세요.

**macOS 11+ (Apple silicon, Intel)**: 터미널에서

```bash
curl -fsSL https://raw.githubusercontent.com/laguna821/pdfcraft/main/install/install.sh | bash
```

**Linux**: macOS와 같은 명령입니다. 배포판을 알아서 판별합니다.

```bash
curl -fsSL https://raw.githubusercontent.com/laguna821/pdfcraft/main/install/install.sh | bash
```

| 배포판 | 설치 방식 |
|---|---|
| Arch, **CachyOS**, EndeavourOS, Manjaro | 릴리즈의 `PKGBUILD`를 `makepkg -si`로 pacman 패키지로 설치. 삭제는 `sudo pacman -R achmage-pdfcraft-bin` |
| Debian, Ubuntu, Mint, Pop!_OS | `.deb` (apt) |
| Fedora, openSUSE | `.rpm` (dnf / zypper) |
| 그 밖 | `~/.local`에 설치 (root 불필요) |

Wayland 네이티브로 실행되므로 Niri에서 XWayland나 FUSE가 필요 없습니다.
- 파일 열기 창이 안 뜨면 `xdg-desktop-portal-gnome`을 설치하세요.
- 한글 입력에는 `fcitx5-hangul`이 필요합니다.

설치 파일을 직접 받으려면 [Releases](https://github.com/laguna821/pdfcraft/releases)에서 받으면
됩니다. 서명하지 않은 파일이라 브라우저로 받으면 경고가 뜹니다.
- **Windows SmartScreen**: "추가 정보 → 실행"을 누르세요.
- **macOS**: "시스템 설정 → 개인정보 보호 및 보안 → 그래도 열기"를 누르거나
  `xattr -dr com.apple.quarantine "/Applications/Achmage PDFCraft.app"`을 실행하세요.

위의 한 줄 설치 명령을 쓰면 이런 경고가 뜨지 않습니다.

## 원본 PdfCraft와 달라진 점

- **Pretendard 내장**
	- 앱 화면의 기본 글꼴입니다. 프로그램 안에 들어 있어서 PC에 따로 설치할 필요가 없습니다.
	- 시스템의 한글 글꼴(맑은 고딕, Apple SD 산돌고딕 Neo, 나눔고딕 등)이 있으면 한자 같은
	  나머지 글자를 채웁니다.
- **기존 글자 편집 (Edit text)**
	- 한글 입력기(MS 한국어 IME, macOS 한국어, fcitx5)로 조합한 글자가 제대로 들어갑니다.
	- 문서의 폰트에 없는 음절도 저장됩니다. Pretendard 글리프로 채우고, 한자는 시스템 한글
	  글꼴에서 가져옵니다.
	- 복사와 검색도 됩니다.
- **텍스트 추가 (Add Text)**: 한글과 한글 문장 부호를 쓸 수 있습니다. 보통·굵게 둘 다 되고,
  단어 단위로 줄을 바꿉니다.
- **글꼴이 들어 있지 않은 한글 PDF**: HY명조, 바탕, 굴림 등을 Adobe-Korea1 방식으로 참조하는
  공문서 PDF도 Pretendard로 표시됩니다.
- **복사와 검색**
	- HWP나 Word에서 내보낸 PDF에서 띄어쓰기가 사라지던 문제를 고쳤습니다.
	- 자모가 분리되어 저장된 한글도 검색됩니다.
- **원본과 따로 설치**: 앱 ID(`io.github.laguna821.AchmagePdfCraft`), 설정 폴더, 설치 경로가
  원본 PdfCraft와 겹치지 않습니다.

계획과 남은 과제는 [docs/achmage/PLAN.md](docs/achmage/PLAN.md)에 있습니다.

## 소스에서 빌드

```bash
cargo run -p pdfcraft -- 문서.pdf
```

릴리즈는 `v<버전>` 태그를 푸시하면 GitHub Actions가 빌드해서 게시합니다
(`.github/workflows/release.yml`). 원본 프로젝트의 문서(기능 목록, 아키텍처, 개발 안내)는
[docs/UPSTREAM-README.md](docs/UPSTREAM-README.md)와 `docs/`에 그대로 있습니다.

## 라이선스

- **코드**: 원본과 같은 MIT OR Apache-2.0입니다 (`LICENSE-MIT`, `LICENSE-APACHE`, `NOTICE`).
- **Pretendard**: © Kil Hyung-jin, SIL Open Font License 1.1 (`assets/fonts/OFL-Pretendard.txt`).
- 그 밖의 에셋 출처는 `ATTRIBUTION.md`에 있습니다.

ArtCraft 상표(로고)는 원본의 라이선스 조건에 따라 이 배포판에서 제거했습니다. 이 배포판은
원본 PdfCraft·ArtCraft 팀과 관계가 없습니다.
