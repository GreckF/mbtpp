// Highlighting of MoonBit++ / MoonBit code blocks (highlight.js has no such
// language) and a button opening runnable examples in the Playground.
(function () {
  "use strict";
  if (typeof hljs === "undefined") return;

  var keywords =
    "fn let mut if else match enum struct trait impl for in with while return " +
    "break continue raise try catch suberror derive pub priv noraise loop as is " +
    "lemma proof monad forall guard test type typealias extern const async";
  hljs.registerLanguage("moonbit", function () {
    return {
      name: "MoonBit",
      keywords: {
        keyword: keywords,
        literal: "true false",
        built_in: "Type Prop Self",
      },
      contains: [
        hljs.C_LINE_COMMENT_MODE,
        { className: "string", begin: '"', end: '"', contains: [{ begin: "\\\\." }] },
        { className: "string", begin: "'(\\\\.|[^'\\\\])'" },
        { className: "meta", begin: "#[a-z_]+" },
        { className: "number", begin: "\\b\\d[\\d_]*(\\.\\d+)?\\b" },
        { className: "title", begin: "@[a-z_][A-Za-z0-9_]*" },
        { className: "type", begin: "\\b[A-Z][A-Za-z0-9_]*" },
      ],
    };
  });

  // base64url of UTF-8, as the Playground's `#code=` links
  function encode(s) {
    var bytes = new TextEncoder().encode(s);
    var bin = "";
    for (var i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
    return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
  }

  var blocks = document.querySelectorAll("code.language-moonbit");
  for (var i = 0; i < blocks.length; i++) {
    var code = blocks[i];
    var src = code.textContent;
    if (hljs.highlightElement) {
      code.removeAttribute("data-highlighted");
      hljs.highlightElement(code);
    } else {
      hljs.highlightBlock(code);
    }
    if (!/\bfn main\b/.test(src)) continue;
    var pre = code.parentElement;
    var buttons = pre.querySelector(".buttons");
    if (!buttons) {
      buttons = document.createElement("div");
      buttons.className = "buttons";
      pre.insertBefore(buttons, pre.firstChild);
    }
    var a = document.createElement("a");
    a.className = "fa fa-play mbtpp-run";
    a.title = "在 Playground 中打开";
    a.setAttribute("aria-label", a.title);
    a.target = "_blank";
    a.rel = "noopener";
    a.href = path_to_root + "../#code=" + encode(src);
    buttons.insertBefore(a, buttons.firstChild);
  }
})();
