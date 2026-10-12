Achmage PDFCraft 첫 릴리즈입니다. 한글이 되는 PdfCraft 독립 배포판이에요.

## 설치 (명령 한 줄)

- **Windows**: PowerShell에서 `irm https://raw.githubusercontent.com/laguna821/pdfcraft/main/install/install.ps1 | iex`
- **macOS / Linux (CachyOS·Arch·Debian·Fedora)**: `curl -fsSL https://raw.githubusercontent.com/laguna821/pdfcraft/main/install/install.sh | bash`

## 한글 지원

- Pretendard를 앱 화면 기본 글꼴로 내장했습니다. PC에 따로 설치할 필요가 없습니다.
- 시스템 한글 글꼴은 한자 같은 나머지 글자를 채웁니다.
- 기존 글자 편집(Edit text)에서 한글 입력기로 조합한 글자가 입력되고 저장됩니다. 문서
  폰트에 없는 음절도 저장됩니다.
- 텍스트 추가(Add Text)에서 한글을 보통·굵게 쓸 수 있습니다.
- 글꼴이 들어 있지 않은 한글 공문서 PDF(Adobe-Korea1)도 표시됩니다.
- 복사·검색 시 한글 띄어쓰기가 보존되고, 자모가 분리된 한글도 검색됩니다.

## 파일

| 파일 | 대상 |
|---|---|
| `*-windows-x64.msi`, `*-windows-x64-portable.zip` | Windows 10/11 |
| `*-macos-universal.dmg`, `*.app.zip` | macOS 11+ (Apple silicon, Intel) |
| `PKGBUILD` | Arch, CachyOS (`makepkg -si`) |
| `*-linux-*.deb` / `.rpm` / `.tar.gz` / `.AppImage` | 그 밖의 Linux |
| `SHA256SUMS.txt` | 체크섬 |

서명하지 않은 파일입니다. 위의 한 줄 설치 명령을 쓰면 경고 없이 설치됩니다.

---

First release of Achmage PDFCraft, a Korean-ready fork of PdfCraft: bundled Pretendard UI font,
Hangul IME editing that saves, Korean Add Text, rendering of non-embedded Adobe-Korea1 fonts,
Korean word spacing in copy and search, and one-line installers for Windows, macOS and Linux.
