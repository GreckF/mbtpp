///|
struct Parser {
  toks : Array[Token]
  mut i : Int
}

///|
fn Parser::peek(self : Parser) -> Token {
  self.toks[self.i]
}

///|
fn Parser::peek_at(self : Parser, k : Int) -> Token {
  let j = self.i + k
  if j < self.toks.length() {
    self.toks[j]
  } else {
    self.toks[self.toks.length() - 1]
  }
}

///|
fn Parser::pos(self : Parser) -> Pos {
  self.peek().pos
}

///|
fn Parser::advance(self : Parser) -> Token {
  let t = self.toks[self.i]
  if self.i < self.toks.length() - 1 {
    self.i = self.i + 1
  }
  t
}

///|
fn Parser::at(self : Parser, s : String) -> Bool {
  self.peek().tok == TSym(s)
}

///|
fn Parser::at_k(self : Parser, k : Int, s : String) -> Bool {
  self.peek_at(k).tok == TSym(s)
}

///|
/// The current token is `s` and on the same line as the previous one.
fn Parser::is_same_line(self : Parser, s : String) -> Bool {
  self.at(s) && !self.peek().nl
}

///|
fn Parser::accept(self : Parser, s : String) -> Bool {
  if self.at(s) {
    ignore(self.advance())
    true
  } else {
    false
  }
}

///|
fn tok_desc(t : Tok) -> String {
  match t {
    TIdent(s) => "identifier '" + s + "'"
    TInt(n) => "number " + n.to_string()
    TDouble(d) => "number " + d.to_string()
    TStr(_) => "string literal"
    TChar(_) => "character literal"
    TSym(s) => "'" + s + "'"
    TEOF => "end of file"
  }
}

///|
fn[T] Parser::fail(self : Parser, msg : String) -> T raise ParseError {
  raise ParseError(self.pos(), msg + ", found " + tok_desc(self.peek().tok))
}

///|
fn Parser::expect(self : Parser, s : String) -> Unit raise ParseError {
  if !self.accept(s) {
    self.fail("expected '" + s + "'")
  }
}

///|
fn Parser::ident(self : Parser) -> String raise ParseError {
  match self.peek().tok {
    TIdent(s) => {
      ignore(self.advance())
      s
    }
    _ => self.fail("expected an identifier")
  }
}

///|
fn Parser::is_ident(self : Parser) -> Bool {
  self.peek().tok is TIdent(_)
}

///|
/// A statement or item ends here: `;`, `}`, end of file or a newline.
fn Parser::at_stmt_end(self : Parser) -> Bool {
  self.at(";") || self.at("}") || self.peek().tok == TEOF || self.peek().nl
}

///|
fn Parser::end_stmt(self : Parser) -> Unit raise ParseError {
  if self.accept(";") {
    return
  }
  if self.at_stmt_end() {
    return
  }
  self.fail("expected a newline or ';'")
}

///|
/// Skip `pub`, `priv`, `pub(all)` etc.
fn Parser::skip_visibility(self : Parser) -> Unit {
  if self.at("pub") || self.at("priv") {
    ignore(self.advance())
    if self.is_same_line("(") {
      ignore(self.advance())
      while !self.at(")") && self.peek().tok != TEOF {
        ignore(self.advance())
      }
      ignore(self.advance())
    }
  }
}

///|
fn Parser::skip_derive(self : Parser) -> Unit raise ParseError {
  if self.is_same_line("derive") {
    ignore(self.advance())
    self.expect("(")
    while !self.at(")") && self.peek().tok != TEOF {
      ignore(self.advance())
    }
    self.expect(")")
  }
}

// ---------------------------------------------------------------------------
// Binders

///|
/// `[x, y : A, M : Monad]`
fn Parser::impl_binders(self : Parser) -> Array[Binder] raise ParseError {
  let bs : Array[Binder] = []
  if !self.accept("[") {
    return bs
  }
  while !self.at("]") {
    let pos = self.pos()
    let name = if self.accept("_") { "_" } else { self.ident() }
    let ty = if self.accept(":") { Some(self.expr()) } else { None }
    bs.push({ pos, name, ty, kind: Positional })
    if !self.accept(",") {
      break
    }
  }
  self.expect("]")
  bs
}

///|
/// Parameters `(x : A, y, B)`: an item is `name : type`, a bare name (whose
/// type is inferred) when `names_only`, and otherwise an anonymous type.
fn Parser::params(
  self : Parser,
  names_only : Bool,
) -> Array[Binder] raise ParseError {
  self.expect("(")
  let bs : Array[Binder] = []
  while !self.at(")") {
    let pos = self.pos()
    if self.is_ident() && (self.at_k(1, "~") || self.at_k(1, "?")) {
      // tagged parameters: `x~ : T`, `x~ : T = default`, `x? : T`
      let name = self.ident()
      let labelled = self.accept("~")
      if !labelled {
        self.expect("?")
      }
      self.expect(":")
      let ty = self.expr()
      let kind : ParamKind = if !labelled {
        Optional
      } else if self.accept("=") {
        Labelled(Some(self.expr()))
      } else {
        Labelled(None)
      }
      bs.push({ pos, name, ty: Some(ty), kind })
    } else if (self.is_ident() || self.at("_")) && self.at_k(1, ":") {
      let name = if self.accept("_") { "_" } else { self.ident() }
      ignore(self.advance())
      bs.push({ pos, name, ty: Some(self.expr()), kind: Positional })
    } else if names_only {
      let name = if self.accept("_") { "_" } else { self.ident() }
      bs.push({ pos, name, ty: None, kind: Positional })
    } else {
      bs.push({ pos, name: "_", ty: Some(self.expr()), kind: Positional })
    }
    if !self.accept(",") {
      break
    }
  }
  self.expect(")")
  bs
}

///|
/// Turn the elements of a parenthesised list into Pi binders.
fn exprs_to_binders(es : Array[Expr]) -> Array[Binder] {
  es.map(e => match e {
    EAnn(p, EVar(_, x), t) => { pos: p, name: x, ty: Some(t), kind: Positional }
    EAnn(p, EHole(_), t) => { pos: p, name: "_", ty: Some(t), kind: Positional }
    _ => { pos: e.pos(), name: "_", ty: Some(e), kind: Positional }
  })
}

///|
/// Turn the elements of a parenthesised list into lambda parameters.
fn exprs_to_params(es : Array[Expr]) -> Array[Binder] raise ParseError {
  es.map(e => match e {
    EVar(p, x) => { pos: p, name: x, ty: None, kind: Positional }
    EHole(p) => { pos: p, name: "_", ty: None, kind: Positional }
    EAnn(p, EVar(_, x), t) => { pos: p, name: x, ty: Some(t), kind: Positional }
    EAnn(p, EHole(_), t) => { pos: p, name: "_", ty: Some(t), kind: Positional }
    _ => raise ParseError(e.pos(), "invalid lambda parameter")
  })
}

///|
/// Turn the elements of a `[...]` list into implicit binders.
fn exprs_to_impl_binders(es : Array[Expr]) -> Array[Binder] raise ParseError {
  es.map(e => match e {
    EVar(p, x) => { pos: p, name: x, ty: None, kind: Positional }
    EHole(p) => { pos: p, name: "_", ty: None, kind: Positional }
    EAnn(p, EVar(_, x), t) => { pos: p, name: x, ty: Some(t), kind: Positional }
    EAnn(p, EHole(_), t) => { pos: p, name: "_", ty: Some(t), kind: Positional }
    _ => raise ParseError(e.pos(), "invalid implicit binder")
  })
}

// ---------------------------------------------------------------------------
// Expressions

///|
pub fn Parser::expr(self : Parser) -> Expr raise ParseError {
  self.arrow()
}

///|
fn Parser::raises_opt(self : Parser) -> Expr? raise ParseError {
  if self.is_same_line("raise") {
    ignore(self.advance())
    // `raise?` (error polymorphism) is treated as not raising
    if self.accept("?") {
      return None
    }
    if self.at("{") ||
      self.at("=") ||
      self.at_stmt_end() ||
      self.at(",") ||
      self.at(")") {
      Some(EVar(self.pos(), "Error"))
    } else {
      Some(self.pipe())
    }
  } else {
    None
  }
}

///|
fn Parser::arrow(self : Parser) -> Expr raise ParseError {
  let pos = self.pos()
  let parenthesised = self.at("(")
  let lhs = self.pipe()
  if !self.at("->") {
    return lhs
  }
  ignore(self.advance())
  let cod = self.arrow()
  let raises = self.raises_opt()
  let binders = match lhs {
    ETuple(_, es) if parenthesised => exprs_to_binders(es)
    ELit(_, LUnit) if parenthesised => []
    _ => exprs_to_binders([lhs])
  }
  EPi(pos, [], Some(binders), cod, raises)
}

///|
fn Parser::pipe(self : Parser) -> Expr raise ParseError {
  let mut lhs = self.binary(0)
  while self.at("|>") {
    let pos = self.pos()
    ignore(self.advance())
    let rhs = self.binary(0)
    lhs = match rhs {
      EApp(p, f, impl_args, Some(args)) =>
        EApp(p, f, impl_args, Some([lhs, ..args]))
      EMethod(p, e, m, impl_args, args) =>
        EMethod(p, e, m, impl_args, [lhs, ..args])
      _ => EApp(pos, rhs, None, Some([lhs]))
    }
  }
  lhs
}

///|
fn bin_prec(op : String) -> Int {
  match op {
    "||" => 1
    "&&" => 2
    "==" | "!=" | "===" | "<" | ">" | "<=" | ">=" => 3
    "..<" | "..=" => 4
    "|" => 5
    "^" => 6
    "&" => 7
    "+" | "-" => 8
    "*" | "/" | "%" => 9
    _ => -1
  }
}

///|
fn Parser::binary(self : Parser, min_prec : Int) -> Expr raise ParseError {
  let mut lhs = self.unary()
  while true {
    let t = self.peek()
    let op = match t.tok {
      TSym(s) => s
      _ => break
    }
    let prec = bin_prec(op)
    if prec < 0 || prec < min_prec {
      break
    }
    // A line starting with `-` begins a new statement.
    if t.nl && op == "-" {
      break
    }
    ignore(self.advance())
    let rhs = self.binary(prec + 1)
    lhs = if op == "..<" || op == "..=" {
      ERange(t.pos, lhs, rhs, op == "..=")
    } else {
      EBin(t.pos, op, lhs, rhs)
    }
  }
  lhs
}

///|
fn Parser::unary(self : Parser) -> Expr raise ParseError {
  let pos = self.pos()
  if self.accept("-") {
    match self.peek().tok {
      TInt(n) => {
        ignore(self.advance())
        return self.postfix(ELit(pos, LInt(-n)))
      }
      TDouble(d) => {
        ignore(self.advance())
        return self.postfix(ELit(pos, LDouble(-d)))
      }
      _ => ()
    }
    return EUn(pos, "-", self.unary())
  }
  if self.accept("!") {
    return EUn(pos, "!", self.unary())
  }
  if self.accept("<-") {
    return EBind(pos, self.unary())
  }
  self.postfix(self.primary())
}

///|
fn Parser::args(self : Parser, close : String) -> Array[Expr] raise ParseError {
  let es : Array[Expr] = []
  while !self.at(close) {
    es.push(self.arg())
    if !self.accept(",") {
      break
    }
  }
  self.expect(close)
  es
}

///|
/// A call argument: an expression or a tagged argument `label=e`, `label~`,
/// `label?=e`, `label?`.
fn Parser::arg(self : Parser) -> Expr raise ParseError {
  let pos = self.pos()
  match self.peek().tok {
    TIdent(x) if self.at_k(1, "=") => {
      ignore(self.advance())
      ignore(self.advance())
      ETagged(pos, x, self.expr(), false)
    }
    TIdent(x) if self.at_k(1, "~") => {
      ignore(self.advance())
      ignore(self.advance())
      ETagged(pos, x, EVar(pos, x), false)
    }
    TIdent(x) if self.at_k(1, "?") && self.at_k(2, "=") => {
      ignore(self.advance())
      ignore(self.advance())
      ignore(self.advance())
      ETagged(pos, x, self.expr(), true)
    }
    TIdent(x) if self.at_k(1, "?") && (self.at_k(2, ",") || self.at_k(2, ")")) => {
      ignore(self.advance())
      ignore(self.advance())
      ETagged(pos, x, EVar(pos, x), true)
    }
    _ => self.expr()
  }
}

///|
fn Parser::postfix(self : Parser, e0 : Expr) -> Expr raise ParseError {
  let mut e = e0
  while true {
    let pos = self.pos()
    if self.is_same_line("(") {
      ignore(self.advance())
      let args = self.args(")")
      e = match e {
        EApp(p, f, Some(impl_args), None) =>
          EApp(p, f, Some(impl_args), Some(args))
        _ => EApp(pos, e, None, Some(args))
      }
    } else if self.is_same_line("[") {
      ignore(self.advance())
      let args = self.args("]")
      e = EApp(pos, e, Some(args), None)
    } else if self.is_same_line("?") {
      // `T?` is `Option[T]` (tagged arguments `x?=e` are parsed by `arg`)
      ignore(self.advance())
      e = EApp(pos, EVar(pos, "Option"), Some([e]), None)
    } else if self.at(".") && !self.at_k(1, ".") {
      ignore(self.advance())
      match self.peek().tok {
        TInt(n) => {
          ignore(self.advance())
          e = EField(pos, e, n.to_string())
        }
        _ => {
          let name = self.ident()
          if self.is_same_line("[") || self.is_same_line("(") {
            let impl_args = if self.is_same_line("[") {
              ignore(self.advance())
              Some(self.args("]"))
            } else {
              None
            }
            if impl_args is Some(idx) && !self.is_same_line("(") {
              // `e.f[i]`: index into a field
              e = EApp(pos, EField(pos, e, name), Some(idx), None)
            } else {
              self.expect("(")
              let args = self.args(")")
              e = EMethod(pos, e, name, impl_args, args)
            }
          } else {
            e = EField(pos, e, name)
          }
        }
      }
    } else {
      break
    }
  }
  e
}

///|
/// An element of a parenthesised or bracketed list: `e` or `e : T`.
fn Parser::ann_elem(self : Parser) -> Expr raise ParseError {
  let e = self.expr()
  if self.at(":") {
    let pos = self.pos()
    ignore(self.advance())
    EAnn(pos, e, self.expr())
  } else {
    e
  }
}

///|
fn Parser::block(self : Parser) -> Expr raise ParseError {
  let pos = self.pos()
  self.expect("{")
  let stmts : Array[Stmt] = []
  while !self.at("}") {
    if self.accept(";") {
      continue
    }
    stmts.push(self.stmt())
    if !self.at("}") {
      self.end_stmt()
    }
  }
  self.expect("}")
  EBlock(pos, stmts)
}

///|
fn Parser::is_struct_literal(self : Parser) -> Bool {
  // `{ x: ...`, `{ x, ...` or `{ x }` with a following field list
  if !self.at("{") {
    return false
  }
  match self.peek_at(1).tok {
    TIdent(_) => self.at_k(2, ":") || self.at_k(2, ",")
    _ => false
  }
}

///|
fn Parser::struct_literal(self : Parser) -> Expr raise ParseError {
  let pos = self.pos()
  self.expect("{")
  let fields : Array[(String, Expr)] = []
  while !self.at("}") {
    let fpos = self.pos()
    let name = self.ident()
    let e = if self.accept(":") { self.expr() } else { EVar(fpos, name) }
    fields.push((name, e))
    if !self.accept(",") {
      break
    }
  }
  self.expect("}")
  EStruct(pos, fields)
}

///|
fn Parser::lambda_body(self : Parser) -> Expr raise ParseError {
  if self.at("{") && !self.is_struct_literal() {
    self.block()
  } else {
    self.expr()
  }
}

///|
fn Parser::primary(self : Parser) -> Expr raise ParseError {
  let t = self.peek()
  let pos = t.pos
  match t.tok {
    TInt(n) => {
      ignore(self.advance())
      ELit(pos, LInt(n))
    }
    TChar(c) => {
      ignore(self.advance())
      ELit(pos, LChar(c))
    }
    TDouble(d) => {
      ignore(self.advance())
      ELit(pos, LDouble(d))
    }
    TSym("@") => {
      // `@pkg.name`: a name from an imported package
      ignore(self.advance())
      let pkg = self.ident()
      self.expect(".")
      let mut name = "@" + pkg + "." + self.ident()
      while self.at("::") {
        ignore(self.advance())
        name = name + "::" + self.ident()
      }
      EVar(pos, name)
    }
    TStr(parts) => {
      ignore(self.advance())
      match parts {
        [SPStr(s)] => ELit(pos, LStr(s))
        _ => {
          let out : Array[InterpPart] = []
          for p in parts {
            match p {
              SPStr(s) => out.push(IStr(s))
              SPExpr(src, line, col) => {
                let sub = { toks: tokenize(src, line0=line, col0=col), i: 0 }
                let e = sub.expr()
                if sub.peek().tok != TEOF {
                  sub.fail("unexpected token in interpolation")
                }
                out.push(IExpr(e))
              }
            }
          }
          EInterp(pos, out)
        }
      }
    }
    TIdent(x) => {
      ignore(self.advance())
      if self.at("=>") {
        ignore(self.advance())
        return ELam(
          pos,
          [],
          [{ pos, name: x, ty: None, kind: Positional }],
          None,
          self.lambda_body(),
        )
      }
      let mut name = x
      while self.at("::") {
        ignore(self.advance())
        name = name + "::" + self.ident()
      }
      EVar(pos, name)
    }
    TSym("_") => {
      ignore(self.advance())
      if self.accept("=>") {
        return ELam(
          pos,
          [],
          [{ pos, name: "_", ty: None, kind: Positional }],
          None,
          self.lambda_body(),
        )
      }
      EHole(pos)
    }
    TSym("true") => {
      ignore(self.advance())
      ELit(pos, LBool(true))
    }
    TSym("false") => {
      ignore(self.advance())
      ELit(pos, LBool(false))
    }
    TSym("Type") => {
      ignore(self.advance())
      EType(pos)
    }
    TSym("Prop") => {
      ignore(self.advance())
      EProp(pos)
    }
    TSym("(") => {
      ignore(self.advance())
      let es : Array[Expr] = []
      let mut trailing = false
      while !self.at(")") {
        es.push(self.ann_elem())
        trailing = false
        if !self.accept(",") {
          break
        }
        trailing = true
      }
      self.expect(")")
      if self.at("=>") {
        ignore(self.advance())
        return ELam(pos, [], exprs_to_params(es), None, self.lambda_body())
      }
      if es.length() == 0 {
        ELit(pos, LUnit)
      } else if es.length() == 1 && !trailing {
        es[0]
      } else {
        ETuple(pos, es)
      }
    }
    TSym("[") => {
      ignore(self.advance())
      let es : Array[Expr] = []
      while !self.at("]") {
        es.push(self.ann_elem())
        if !self.accept(",") {
          break
        }
      }
      self.expect("]")
      if self.is_same_line("(") || self.at("->") {
        let impl_bs = exprs_to_impl_binders(es)
        let expl = if self.at("(") {
          let ps = self.pipe()
          match ps {
            ETuple(_, xs) => Some(exprs_to_binders(xs))
            ELit(_, LUnit) => Some([])
            _ => Some(exprs_to_binders([ps]))
          }
        } else {
          None
        }
        self.expect("->")
        let cod = self.arrow()
        let raises = self.raises_opt()
        return EPi(pos, impl_bs, expl, cod, raises)
      }
      for e in es {
        if e is EAnn(p, _, _) {
          raise ParseError(p, "unexpected ':' in array literal")
        }
      }
      EArray(pos, es)
    }
    TSym("{") =>
      if self.is_struct_literal() {
        self.struct_literal()
      } else {
        self.block()
      }
    TSym("fn") => {
      ignore(self.advance())
      let impl_bs = self.impl_binders()
      let ps = self.params(true)
      let ret = if self.accept("->") { Some(self.expr()) } else { None }
      ignore(self.raises_opt())
      ELam(pos, impl_bs, ps, ret, self.block())
    }
    TSym("if") => self.if_expr()
    TSym("match") => self.match_expr()
    TSym("try") => {
      ignore(self.advance())
      if self.accept("?") {
        return ETryQ(pos, self.expr())
      }
      let body = if self.at("{") { self.block() } else { self.expr() }
      self.expect("catch")
      ETry(pos, body, self.arms())
    }
    TSym("raise") => {
      ignore(self.advance())
      ERaise(pos, self.expr())
    }
    TSym("return") => {
      ignore(self.advance())
      if self.at_stmt_end() {
        EReturn(pos, None)
      } else {
        EReturn(pos, Some(self.expr()))
      }
    }
    TSym("break") => {
      ignore(self.advance())
      EBreak(pos)
    }
    TSym("continue") => {
      ignore(self.advance())
      EContinue(pos)
    }
    TSym("monad") => {
      ignore(self.advance())
      EMonad(pos, self.block())
    }
    TSym("proof") => {
      ignore(self.advance())
      EProof(pos, self.tactics())
    }
    TSym("forall") => {
      ignore(self.advance())
      let names : Array[(Pos, String)] = []
      while !self.at(":") && !self.at(",") {
        let p = self.pos()
        let name = if self.accept("_") { "_" } else { self.ident() }
        names.push((p, name))
      }
      let ty = if self.accept(":") { Some(self.expr()) } else { None }
      self.expect(",")
      let body = self.expr()
      let bs = names.map(pn => { pos: pn.0, name: pn.1, ty, kind: Positional })
      EPi(pos, [], Some(bs), body, None)
    }
    _ => self.fail("expected an expression")
  }
}

///|
fn Parser::if_expr(self : Parser) -> Expr raise ParseError {
  let pos = self.pos()
  self.expect("if")
  let c = self.expr()
  let t = self.block()
  if self.accept("else") {
    let e = if self.at("if") { self.if_expr() } else { self.block() }
    EIf(pos, c, t, Some(e))
  } else {
    EIf(pos, c, t, None)
  }
}

///|
fn Parser::match_expr(self : Parser) -> Expr raise ParseError {
  let pos = self.pos()
  self.expect("match")
  let scrut = self.expr()
  let as_name = if self.accept("as") { Some(self.ident()) } else { None }
  let in_ty = if self.accept("in") { Some(self.expr()) } else { None }
  let ret = if self.accept("return") { Some(self.expr()) } else { None }
  let mr = if as_name is None && in_ty is None && ret is None {
    None
  } else {
    Some({ as_name, in_ty, ret })
  }
  EMatch(pos, scrut, mr, self.arms())
}

///|
fn Parser::arms(self : Parser) -> Array[Arm] raise ParseError {
  self.expect("{")
  let arms : Array[Arm] = []
  while !self.at("}") {
    if self.accept(";") {
      continue
    }
    let pos = self.pos()
    let pat = self.pattern()
    let rhs = if self.accept("=>") {
      Some(
        if self.at("{") && !self.is_struct_literal() {
          self.block()
        } else {
          self.expr()
        },
      )
    } else {
      None
    }
    arms.push({ pos, pat, rhs })
    if !self.at("}") {
      self.end_stmt()
    }
  }
  self.expect("}")
  arms
}

// ---------------------------------------------------------------------------
// Patterns

///|
fn is_upper(s : String) -> Bool {
  match s.get_char(0) {
    Some(c) => c >= 'A' && c <= 'Z'
    None => false
  }
}

///|
/// The arguments of a constructor pattern `C[impl](expl)`.
fn Parser::con_pattern_args(
  self : Parser,
  pos : Pos,
  name : String,
) -> Pat raise ParseError {
  let impl_ps = if self.is_same_line("[") {
    ignore(self.advance())
    let ps : Array[Pat] = []
    while !self.at("]") {
      ps.push(self.pattern())
      if !self.accept(",") {
        break
      }
    }
    self.expect("]")
    Some(ps)
  } else {
    None
  }
  let ps : Array[Pat] = []
  if self.is_same_line("(") {
    ignore(self.advance())
    while !self.at(")") {
      ps.push(self.pattern())
      if !self.accept(",") {
        break
      }
    }
    self.expect(")")
  }
  PCon(pos, name, impl_ps, ps)
}

///|
fn Parser::pattern(self : Parser) -> Pat raise ParseError {
  let t = self.peek()
  let pos = t.pos
  match t.tok {
    TSym("_") => {
      ignore(self.advance())
      PWild(pos)
    }
    TInt(n) => {
      ignore(self.advance())
      PLit(pos, LInt(n))
    }
    TSym("-") => {
      ignore(self.advance())
      match self.peek().tok {
        TInt(n) => {
          ignore(self.advance())
          PLit(pos, LInt(-n))
        }
        _ => self.fail("expected a number")
      }
    }
    TStr([SPStr(s)]) => {
      ignore(self.advance())
      PLit(pos, LStr(s))
    }
    TChar(c) => {
      ignore(self.advance())
      PLit(pos, LChar(c))
    }
    TSym("true") => {
      ignore(self.advance())
      PLit(pos, LBool(true))
    }
    TSym("false") => {
      ignore(self.advance())
      PLit(pos, LBool(false))
    }
    TSym("@") => {
      // `@pkg.Type::Ctor(..)`: a constructor of an imported type
      ignore(self.advance())
      let pkg = self.ident()
      self.expect(".")
      let mut name = "@" + pkg + "." + self.ident()
      while self.at("::") {
        ignore(self.advance())
        name = name + "::" + self.ident()
      }
      self.con_pattern_args(pos, name)
    }
    TSym("(") => {
      ignore(self.advance())
      let ps : Array[Pat] = []
      let mut trailing = false
      while !self.at(")") {
        ps.push(self.pattern())
        trailing = false
        if !self.accept(",") {
          break
        }
        trailing = true
      }
      self.expect(")")
      if ps.length() == 0 {
        PLit(pos, LUnit)
      } else if ps.length() == 1 && !trailing {
        ps[0]
      } else {
        PTuple(pos, ps)
      }
    }
    TIdent(x) => {
      ignore(self.advance())
      let mut name = x
      while self.at("::") {
        ignore(self.advance())
        name = name + "::" + self.ident()
      }
      if !is_upper(x) && !name.contains("::") {
        return PVar(pos, name)
      }
      self.con_pattern_args(pos, name)
    }
    _ => self.fail("expected a pattern")
  }
}

// ---------------------------------------------------------------------------
// Statements

///|
fn Parser::stmt(self : Parser) -> Stmt raise ParseError {
  let pos = self.pos()
  if self.accept("let") {
    if self.accept("mut") {
      let name = self.ident()
      let ty = if self.accept(":") { Some(self.expr()) } else { None }
      self.expect("=")
      return SLetMut(pos, name, ty, self.expr())
    }
    let pat = self.pattern()
    if self.accept("<-") {
      return SLetBind(pos, pat, self.expr())
    }
    let ty = if self.accept(":") { Some(self.expr()) } else { None }
    self.expect("=")
    return SLet(pos, pat, ty, self.expr())
  }
  if self.at("fn") && (self.peek_at(1).tok is TIdent(_) || self.at_k(1, "[")) {
    ignore(self.advance())
    return SFn(pos, self.fn_rest(pos, false))
  }
  if self.accept("while") {
    let c = self.expr()
    return SWhile(pos, c, self.block())
  }
  if self.accept("for") {
    if self.is_ident() && self.at_k(1, "in") {
      let x = self.ident()
      self.expect("in")
      let e = self.expr()
      return SForIn(pos, x, e, self.block())
    }
    let inits : Array[(String, Expr)] = []
    while !self.at(";") {
      let x = self.ident()
      self.expect("=")
      inits.push((x, self.expr()))
      if !self.accept(",") {
        break
      }
    }
    self.expect(";")
    let cond = if self.at(";") { None } else { Some(self.expr()) }
    self.expect(";")
    let updates : Array[(String, Expr)] = []
    while !self.at("{") {
      let x = self.ident()
      self.expect("=")
      updates.push((x, self.expr()))
      if !self.accept(",") {
        break
      }
    }
    return SFor(pos, inits, cond, updates, self.block())
  }
  let e = self.expr()
  for op in ["=", "+=", "-=", "*=", "/="] {
    if self.at(op) {
      ignore(self.advance())
      return SAssign(pos, e, op, self.expr())
    }
  }
  SExpr(pos, e)
}

// ---------------------------------------------------------------------------
// Tactics

///|
fn Parser::tactics(self : Parser) -> Array[Tactic] raise ParseError {
  self.expect("{")
  let ts : Array[Tactic] = []
  while !self.at("}") {
    if self.accept(";") {
      continue
    }
    let pos = self.pos()
    let name = self.ident()
    let t = match name {
      "intros" | "intro" => {
        let xs : Array[String] = []
        while !self.at_stmt_end() {
          xs.push(if self.accept("_") { "_" } else { self.ident() })
        }
        TIntros(pos, xs)
      }
      "exact" => TExact(pos, self.expr())
      "rfl" => TRfl(pos)
      "destruct" | "cases" => TDestruct(pos, self.ident())
      "rewrite" | "rw" => {
        let rev = self.accept("<-")
        TRewrite(pos, self.expr(), rev)
      }
      "apply" => TApply(pos, self.expr())
      "assume" | "have" => {
        let x = self.ident()
        self.expect(":")
        TAssume(pos, x, self.expr())
      }
      _ => raise ParseError(pos, "unknown tactic '" + name + "'")
    }
    ts.push(t)
    if !self.at("}") {
      self.end_stmt()
    }
  }
  self.expect("}")
  ts
}

// ---------------------------------------------------------------------------
// Declarations

///|
/// After `fn`: `[impl] name(params) -> ret raise E { body }`.
fn Parser::fn_rest(
  self : Parser,
  pos : Pos,
  is_lemma : Bool,
) -> FnDecl raise ParseError {
  let mut impl_bs = self.impl_binders()
  let mut name = self.ident()
  while self.accept("::") {
    name = name + "::" + self.ident()
  }
  if is_lemma && self.at("[") {
    impl_bs = impl_bs + self.impl_binders()
  }
  let params = if self.at("(") { Some(self.params(false)) } else { None }
  let ret = if self.accept("->") { Some(self.expr()) } else { None }
  let raises = self.raises_opt()
  let body = if self.accept("=") {
    match self.peek().tok {
      TStr([SPStr(s)]) => {
        ignore(self.advance())
        BodyExtern(s)
      }
      _ => BodyExpr(self.expr())
    }
  } else {
    BodyExpr(self.block())
  }
  { pos, name, impl_params: impl_bs, params, ret, raises, body, is_lemma }
}

///|
fn Parser::con_decls(self : Parser) -> Array[ConDecl] raise ParseError {
  self.expect("{")
  let cs : Array[ConDecl] = []
  while !self.at("}") {
    if self.accept(";") {
      continue
    }
    let pos = self.pos()
    let name = self.ident()
    let impl_bs = self.impl_binders()
    let params = if self.is_same_line("(") { self.params(false) } else { [] }
    let ret = if self.accept(":") { Some(self.expr()) } else { None }
    cs.push({ pos, name, impl_params: impl_bs, params, ret })
    if !self.at("}") {
      self.end_stmt()
    }
  }
  self.expect("}")
  cs
}

///|
fn Parser::decl(self : Parser) -> Decl raise ParseError {
  self.skip_visibility()
  let pos = self.pos()
  if self.accept("fn") {
    return DFn(self.fn_rest(pos, false))
  }
  if self.accept("lemma") {
    // `lemma name[T](x : A) -> P { ... }` or `lemma name[T] : P = e`
    let impl_bs = self.impl_binders()
    let name = self.ident()
    let impl_bs = impl_bs + self.impl_binders()
    if self.accept(":") {
      let ty = self.expr()
      self.expect("=")
      return DDef(pos, name, impl_bs, Some(ty), self.expr())
    }
    let params = if self.at("(") { Some(self.params(false)) } else { None }
    let ret = if self.accept("->") { Some(self.expr()) } else { None }
    let body = if self.accept("=") { self.expr() } else { self.block() }
    return DFn({
      pos,
      name,
      impl_params: impl_bs,
      params,
      ret,
      raises: None,
      body: BodyExpr(body),
      is_lemma: true,
    })
  }
  if self.accept("let") {
    let name = self.ident()
    let ty = if self.accept(":") { Some(self.expr()) } else { None }
    self.expect("=")
    return DDef(pos, name, [], ty, self.expr())
  }
  if self.accept("enum") {
    let name = self.ident()
    let impl_bs = self.impl_binders()
    let params = if self.at("(") { Some(self.params(false)) } else { None }
    let sig = if self.accept(":") { Some(self.expr()) } else { None }
    let cons = self.con_decls()
    self.skip_derive()
    return DEnum({
      pos,
      name,
      impl_params: impl_bs,
      params,
      sig,
      cons,
      is_error: false,
    })
  }
  if self.accept("suberror") {
    let name = self.ident()
    let cons = if self.at("{") {
      self.con_decls()
    } else if self.at_stmt_end() || self.is_same_line("derive") {
      [{ pos, name, impl_params: [], params: [], ret: None }]
    } else {
      let ty = self.expr()
      [
        {
          pos,
          name,
          impl_params: [],
          params: [{ pos, name: "_", ty: Some(ty), kind: Positional }],
          ret: None,
        },
      ]
    }
    self.skip_derive()
    return DEnum({
      pos,
      name,
      impl_params: [],
      params: None,
      sig: None,
      cons,
      is_error: true,
    })
  }
  if self.accept("struct") {
    let name = self.ident()
    let impl_bs = self.impl_binders()
    let params = if self.at("(") { Some(self.params(false)) } else { None }
    self.expect("{")
    let fields : Array[(Pos, String, Expr)] = []
    while !self.at("}") {
      if self.accept(";") {
        continue
      }
      ignore(self.accept("mut"))
      let fpos = self.pos()
      let f = self.ident()
      self.expect(":")
      fields.push((fpos, f, self.expr()))
      if !self.at("}") {
        self.end_stmt()
      }
    }
    self.expect("}")
    self.skip_derive()
    return DStruct({ pos, name, impl_params: impl_bs, params, fields })
  }
  if self.accept("trait") {
    let name = self.ident()
    let self_kind = if self.accept("(") {
      let s = self.ident()
      if s != "Self" {
        self.fail("expected 'Self'")
      }
      self.expect(":")
      let k = self.expr()
      self.expect(")")
      Some(k)
    } else {
      None
    }
    let supers : Array[String] = []
    if self.accept(":") {
      supers.push(self.ident())
      while self.accept("+") {
        supers.push(self.ident())
      }
    }
    self.expect("{")
    let methods : Array[TraitMethod] = []
    while !self.at("}") {
      if self.accept(";") {
        continue
      }
      let mpos = self.pos()
      ignore(self.accept("fn"))
      let impl_bs = self.impl_binders()
      let m = self.ident()
      let ps = self.params(false)
      self.expect("->")
      let ret = self.pipe()
      let raises = self.raises_opt()
      if self.accept("=") {
        self.expect("_")
      }
      methods.push({
        pos: mpos,
        name: m,
        impl_params: impl_bs,
        params: ps,
        ret,
        raises,
      })
      if !self.at("}") {
        self.end_stmt()
      }
    }
    self.expect("}")
    return DTrait({ pos, name, self_kind, supers, methods })
  }
  if self.accept("impl") {
    let impl_bs = self.impl_binders()
    let tr = self.ident()
    self.expect("for")
    let ty = self.expr()
    self.expect("with")
    let m = self.ident()
    let ps = self.params(true)
    if self.accept("->") {
      ignore(self.pipe())
    }
    ignore(self.raises_opt())
    let body = self.block()
    return DImpl({
      pos,
      impl_params: impl_bs,
      trait_name: tr,
      for_ty: ty,
      meth: m,
      params: ps,
      body,
    })
  }
  self.fail("expected a declaration")
}

///|
pub fn parse_program(
  src : String,
  line0? : Int = 1,
) -> Array[Decl] raise ParseError {
  let p = { toks: tokenize(src, line0~), i: 0 }
  let ds : Array[Decl] = []
  while p.peek().tok != TEOF {
    if p.accept(";") {
      continue
    }
    ds.push(p.decl())
  }
  ds
}

///|
pub fn parse_expr(src : String) -> Expr raise ParseError {
  let p = { toks: tokenize(src), i: 0 }
  let e = p.expr()
  if p.peek().tok != TEOF {
    p.fail("unexpected token")
  }
  e
}
