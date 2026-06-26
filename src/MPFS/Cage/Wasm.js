export const encodeUtf8Hex = (text) =>
  Array.from(new TextEncoder().encode(text))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
