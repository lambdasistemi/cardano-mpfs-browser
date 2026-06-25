export const unsafeIndex = (arr) => (i) => arr[i];
export const slice = (arr) => (start) => (end) => arr.slice(start, end);
export const byteLength = (arr) => arr.length;
export const bytesToHex = (bytes) =>
  Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join("");
export const hexToBytes = (hex) => {
  const bytes = new Uint8Array(hex.length / 2);
  for (let i = 0; i < bytes.length; i += 1) {
    bytes[i] = Number.parseInt(hex.slice(i * 2, i * 2 + 2), 16);
  }
  return bytes;
};
