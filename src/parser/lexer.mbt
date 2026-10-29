///|
pub(all) enum Tok {
  TIdent(String)
  TInt(Int)
  TDouble(Double)
  TStr(Array[StrPart])
  TChar(Char)
  /// Keywords and symbols.
  TSym(String)
  TEOF
} derive(Show, Eq)

///|
pub(all) enum StrPart {
  SPStr(String)
  /// Source of an interpolated expression and its position.
  SPExpr(String, Int, Int)
} derive(Show, Eq)

///|
pub(all) struct Token {
  tok : Tok
  pos : Pos
  /// Whether a newline separates this token from the previous one.
  nl : Bool
} derive(Show)

///|
pub suberror ParseError {
  ParseError(Pos, String)
}

///|
let keywords : Array[String] = [
  "fn", "let", "mut", "if", "else", "match", "enum", "struct", "trait", "impl", "for",
  "in", "with", "while", "return", "break", "continue", "raise", "try", "catch",
  "true", "false", "Type", "Prop", "forall", "lemma", "proof", "monad", "as", "suberror",
  "derive", "pub", "priv", "noraise", "loop",
]

///|
/// Symbols, longest first.
let symbols : Array[String] = [
  "===", "..<", "..=", "::", "->", "=>", "==", "!=", "<=", ">=", "&&", "||", "|>",
  "<-", "+=", "-=", "*=", "/=", "..", "#", "(", ")", "[", "]", "{", "}", ",", ";",
  ":", ".", "=", "<", ">", "+", "-", "*", "/", "%", "!", "|", "_", "~", "?", "@",
  "&", "^",
]

///|
fn is_ident_start(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_'
}

///|
fn is_ident_char(c : Char) -> Bool {
  is_ident_start(c) || (c >= '0' && c <= '9')
}

///|
pub fn tokenize(
  src : String,
  line0? : Int = 1,
  col0? : Int = 1,
) -> Array[Token] raise ParseError {
  let cs : Array[Char] = src.iter().collect()
  let n = cs.length()
  let toks : Array[Token] = []
  let mut i = 0
  let mut line = line0
  let mut col = col0
  let mut nl = true
  fn peek(k : Int) -> Char {
    if i + k < n {
      cs[i + k]
    } else {
      '\u{0}'
    }
  }

  fn adv() -> Unit {
    if cs[i] == '\n' {
      line = line + 1
      col = 1
    } else {
      col = col + 1
    }
    i = i + 1
  }

  while i < n {
    let c = cs[i]
    if c == '\n' {
      nl = true
      adv()
      continue
    }
    if c == ' ' || c == '\t' || c == '\r' {
      adv()
      continue
    }
    if c == '/' && peek(1) == '/' {
      while i < n && cs[i] != '\n' {
        adv()
      }
      continue
    }
    let pos = { line, col }
    if c >= '0' && c <= '9' {
      let mut v = 0
      while i < n && ((cs[i] >= '0' && cs[i] <= '9') || cs[i] == '_') {
        if cs[i] != '_' {
          v = v * 10 + (cs[i].to_int() - '0'.to_int())
        }
        adv()
      }
      // `1.5` is a Double, but not `0..n` or the field access `t.0.1`
      let after_dot = toks.length() > 0 &&
        toks[toks.length() - 1].tok == TSym(".")
      if !after_dot &&
        i + 1 < n &&
        cs[i] == '.' &&
        cs[i + 1] >= '0' &&
        cs[i + 1] <= '9' {
        adv()
        let mut d = v.to_double()
        let mut scale = 0.1
        while i < n && ((cs[i] >= '0' && cs[i] <= '9') || cs[i] == '_') {
          if cs[i] != '_' {
            d = d + (cs[i].to_int() - '0'.to_int()).to_double() * scale
            scale = scale / 10.0
          }
          adv()
        }
        toks.push({ tok: TDouble(d), pos, nl })
        nl = false
        continue
      }
      toks.push({ tok: TInt(v), pos, nl })
      nl = false
      continue
    }
    if is_ident_start(c) && !(c == '_' && !is_ident_char(peek(1))) {
      let buf = StringBuilder::new()
      while i < n && is_ident_char(cs[i]) {
        buf.write_char(cs[i])
        adv()
      }
      let s = buf.to_string()
      let tok = if keywords.contains(s) { TSym(s) } else { TIdent(s) }
      toks.push({ tok, pos, nl })
      nl = false
      continue
    }
    if c == '\'' {
      adv()
      let ch = if i < n && cs[i] == '\\' {
        adv()
        let e = cs[i]
        adv()
        escape_char(pos, e)
      } else if i < n {
        let ch = cs[i]
        adv()
        ch
      } else {
        raise ParseError(pos, "unterminated character literal")
      }
      if i >= n || cs[i] != '\'' {
        raise ParseError(pos, "unterminated character literal")
      }
      adv()
      toks.push({ tok: TChar(ch), pos, nl })
      nl = false
      continue
    }
    if c == '"' {
      adv()
      let parts : Array[StrPart] = []
      let buf = StringBuilder::new()
      while true {
        if i >= n || cs[i] == '\n' {
          raise ParseError(pos, "unterminated string literal")
        }
        let d = cs[i]
        if d == '"' {
          adv()
          break
        }
        if d == '\\' && peek(1) == '{' {
          adv()
          adv()
          if buf.to_string() != "" {
            parts.push(SPStr(buf.to_string()))
          }
          buf.reset()
          let eline = line
          let ecol = col
          let ebuf = StringBuilder::new()
          let mut depth = 0
          while i < n && !(cs[i] == '}' && depth == 0) {
            if cs[i] == '{' {
              depth = depth + 1
            } else if cs[i] == '}' {
              depth = depth - 1
            }
            ebuf.write_char(cs[i])
            adv()
          }
          if i >= n {
            raise ParseError(pos, "unterminated interpolation")
          }
          adv()
          parts.push(SPExpr(ebuf.to_string(), eline, ecol))
          continue
        }
        if d == '\\' {
          adv()
          let e = cs[i]
          adv()
          buf.write_char(escape_char(pos, e))
          continue
        }
        buf.write_char(d)
        adv()
      }
      if buf.to_string() != "" || parts.length() == 0 {
        parts.push(SPStr(buf.to_string()))
      }
      toks.push({ tok: TStr(parts), pos, nl })
      nl = false
      continue
    }
    let mut matched = false
    for s in symbols {
      let len = s.length()
      if i + len <= n {
        let mut ok = true
        for k = 0; k < len; k = k + 1 {
          if cs[i + k] != s.get_char(k).unwrap() {
            ok = false
            break
          }
        }
        if ok {
          for k = 0; k < len; k = k + 1 {
            adv()
          }
          toks.push({ tok: TSym(s), pos, nl })
          nl = false
          matched = true
          break
        }
      }
    }
    if !matched {
      raise ParseError(pos, "unexpected character '" + c.to_string() + "'")
    }
  }
  toks.push({ tok: TEOF, pos: { line, col }, nl: true })
  toks
}

///|
fn escape_char(pos : Pos, e : Char) -> Char raise ParseError {
  match e {
    'n' => '\n'
    't' => '\t'
    'r' => '\r'
    '\\' => '\\'
    '"' => '"'
    '\'' => '\''
    '0' => '\u{0}'
    _ => raise ParseError(pos, "unknown escape \\" + e.to_string())
  }
}
