document.addEventListener("DOMContentLoaded", function () {
    mermaid.initialize({
        startOnLoad: false,
        theme: "dark"
    });
    mermaid.run({ querySelector: ".mermaid" });
});
