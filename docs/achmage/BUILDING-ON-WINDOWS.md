# 이 저장소를 Windows PC에서 빌드하기 (메모)

릴리즈는 GitHub Actions가 만듭니다. `Cargo.toml`의 버전을 올리고 `v<버전>` 태그를 푸시하면
`.github/workflows/release.yml`이 빌드하고 Release를 게시합니다. PC에서 빌드할 필요는 없습니다.
기능을 고칠 때 로컬에서 테스트하려면 아래 순서로 준비합니다.

## 1. 준비 (처음 한 번)

1. `git clone https://github.com/laguna821/pdfcraft C:\dev\achmage-pdfcraft`
	- 경로에 한글이나 공백이 없는 곳을 씁니다.
2. Rust 툴체인: `rustup update stable` 후 `rustup component add rustfmt clippy`
3. MSVC 링커: Visual Studio Build Tools의 "C++ build tools"가 필요합니다.
	- 이 PC에는 VS 2019 Build Tools가 있었지만 Windows SDK가 없었고, 설치 프로그램으로 SDK를
	  추가하는 것도 실패했습니다.
	- 대신 [xwin](https://github.com/Jake-Shadle/xwin)으로 CRT와 Windows SDK 라이브러리를 사용자
	  폴더에 받아 썼습니다. 관리자 권한이 필요 없습니다.
		- xwin 릴리즈의 `xwin-<v>-x86_64-pc-windows-msvc.tar.gz`를 받아 sha256을 확인합니다.
		- `xwin --accept-license --arch x86_64 splat --output C:\dev\xwin`
4. 환경 스크립트 `C:\dev\cargo-env.ps1`

```powershell
$msvc = "C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\VC\Tools\MSVC\14.29.30133"
$x = "C:\dev\xwin"
$env:PATH = "$msvc\bin\Hostx64\x64;" + $env:PATH
$env:LIB = "$x\crt\lib\x86_64;$x\sdk\lib\um\x86_64;$x\sdk\lib\ucrt\x86_64"
$env:INCLUDE = "$x\crt\include;$x\sdk\include\ucrt;$x\sdk\include\um;$x\sdk\include\shared"
$env:CARGO_TARGET_DIR = "C:\dev\target"
# 빌드 캐시 크기 억제: 디버그 정보와 증분 빌드를 켜 두면 56 GB까지 커져서 디스크가 가득 찼습니다.
$env:CARGO_INCREMENTAL = "0"
$env:CARGO_PROFILE_DEV_DEBUG = "0"
$env:CARGO_PROFILE_TEST_DEBUG = "0"
```

## 2. 빌드와 테스트 (PowerShell에서)

```powershell
. C:\dev\cargo-env.ps1
cd C:\dev\achmage-pdfcraft
cargo run -p pdfcraft -- 문서.pdf          # 앱 실행
cargo test -j 4 --workspace --no-fail-fast  # 메모리가 부족하면 -j 4
cargo clippy -j 4 --workspace --all-targets -- -D warnings
cargo fmt --all
cargo xtask assets                          # 에셋 출처 검사 (새 파일을 넣었으면 ATTRIBUTION.toml에 등록)
```

- **Git Bash에서 cargo를 돌리지 않습니다.** Git Bash의 `/usr/bin/link`가 MSVC `link.exe`를 가려서
  빌드 스크립트 링크가 실패합니다. PowerShell을 씁니다.
- 빌드 캐시(`C:\dev\target`)는 16 GB 안팎입니다. 다 쓰면 지워도 됩니다.
- **이 PC에서만 실패하는 테스트**: 사용자 폴더 경로에 한글이 있어서 다음 테스트가 실패하지만
  GitHub CI에서는 통과합니다.
	- `single_instance` 테스트 3개
	- `automation::root_refusals_do_not_reveal_what_exists_outside`
	- `version_resource` (rc 도구 없음)

## 3. 헤드리스 확인

```powershell
cargo run -p pdfcraft-cli -- run --script steps.json --root DIR
cargo run -p pdfcraft-cli -- render out.pdf --page 1 --out out.png
```

`text_edit`, `page_add_text`, `doc_save`, `text_extract` 도구로 한글 편집 결과를 확인할 수 있습니다.
UI 확인은 `pdfcraft --control ctl.json 문서.pdf`로 띄운 뒤
`pdfcraft-cli ui --control ctl.json screenshot --out x.png`로 합니다.

## 4. 남은 한글 과제

[PLAN.md](PLAN.md)의 진행 현황 표를 보세요. 미완 항목은 다음과 같습니다.
- KSC 계열 명명 CMap의 편집 인코딩
- 이름만 적힌 Identity-H 폰트(Batang, Gulim 등)의 렌더
- 텍스트에서 PDF 만들기(`create::from_text`)의 한글
- 한국어 OCR
