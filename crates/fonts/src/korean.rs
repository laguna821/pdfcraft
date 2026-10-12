//! Achmage PDFCraft: Korean text drawn from the bundled Pretendard's outlines, for appearance
//! streams that can't carry a font of their own (text box comments, form fields). The glyphs go
//! in as filled paths; the text itself stays in the annotation's `/Contents` or the field's `/V`.

use crate::{CraftFont, japanese_glyph_from, korean_has, pretendard};

/// Whether `text` needs the outlines: it has a character WinAnsi lacks (Hangul, CJK
/// punctuation) and Pretendard has every character.
pub fn needs_korean_outlines(text: &str) -> bool {
    crate::first_undrawable(text).is_some() && korean_outlines_cover(text)
}

/// Whether Pretendard has every character of `text` (line breaks aside).
pub fn korean_outlines_cover(text: &str) -> bool {
    text.chars().all(|c| matches!(c, '\n' | '\r') || korean_has(c))
}

fn face() -> Option<&'static CraftFont> {
    pretendard("Regular")
}

/// The advance of `s` at `size` points in Pretendard (half an em for a character it lacks).
pub fn korean_outline_width(s: &str, size: f64) -> f64 {
    let Some(face) = face() else { return crate::helvetica_width(s, size) };
    s.chars().map(|c| japanese_glyph_from(face, c).map_or(0.5, |g| g.width)).sum::<f64>() * size
}

/// Path operators filling `line` in Pretendard at `size` with its baseline origin at (`x`, `y`),
/// numbers written with `num`. Nothing for an empty line. The caller sets the fill colour.
pub fn korean_outline_path(out: &mut String, line: &str, x: f64, y: f64, size: f64, num: impl Fn(f64) -> String) {
    let Some(face) = face() else { return };
    let mut pen = x;
    let mut any = false;
    for c in line.chars() {
        let Ok(g) = japanese_glyph_from(face, c) else {
            pen += 0.5 * size;
            continue;
        };
        for contour in g.contours.iter().filter(|c| !c.is_empty()) {
            for (i, p) in contour.iter().enumerate() {
                out.push_str(&num(pen + p[0] * size));
                out.push(' ');
                out.push_str(&num(y + p[1] * size));
                out.push_str(if i == 0 { " m\n" } else { " l\n" });
            }
            out.push_str("h\n");
            any = true;
        }
        pen += g.width * size;
    }
    if any {
        out.push_str("f\n");
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn korean_lines_become_filled_paths() {
        assert!(needs_korean_outlines("한글"));
        assert!(!needs_korean_outlines("Zürich"));
        assert!(korean_outlines_cover("Mixed 한글 123"));
        let mut out = String::new();
        korean_outline_path(&mut out, "가A", 10.0, 20.0, 12.0, |v| format!("{v:.2}"));
        assert!(out.matches(" m\n").count() >= 2 && out.ends_with("f\n"), "{out}");
        let mut empty = String::new();
        korean_outline_path(&mut empty, "", 0.0, 0.0, 12.0, |v| v.to_string());
        assert!(empty.is_empty());
        assert!(korean_outline_width("가나", 10.0) > korean_outline_width("가", 10.0));
    }
}
