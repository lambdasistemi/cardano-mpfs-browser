export const writeTextImpl = (text) => () =>
  new Promise((resolve, reject) => {
    const nav = globalThis.navigator;

    if (nav && nav.clipboard && typeof nav.clipboard.writeText === "function") {
      Promise.resolve(nav.clipboard.writeText(text)).then(resolve, reject);
      return;
    }

    const doc = globalThis.document;
    if (!doc || typeof doc.execCommand !== "function") {
      reject(new Error("Clipboard API is unavailable."));
      return;
    }

    const textarea = doc.createElement("textarea");
    textarea.value = text;
    textarea.setAttribute("readonly", "");
    textarea.style.position = "fixed";
    textarea.style.left = "-9999px";
    textarea.style.top = "0";

    doc.body.appendChild(textarea);
    textarea.focus();
    textarea.select();

    try {
      if (doc.execCommand("copy")) {
        resolve();
      } else {
        reject(new Error("document.execCommand('copy') returned false."));
      }
    } catch (error) {
      reject(error);
    } finally {
      doc.body.removeChild(textarea);
    }
  });
