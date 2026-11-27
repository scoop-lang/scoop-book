// mdBook 自带的 highlight.js 不认识 Scoop。Scoop 语法接近 Kotlin，
// 这里把 ```scoop 代码块按 Kotlin 规则重新高亮。
(function () {
    if (typeof hljs === "undefined" || !hljs.getLanguage("kotlin")) {
        return;
    }
    document.querySelectorAll("code.language-scoop").forEach(function (block) {
        var result = hljs.highlight("kotlin", block.textContent, true);
        block.innerHTML = result.value;
        block.classList.add("hljs");
    });
})();
