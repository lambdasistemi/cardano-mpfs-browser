import { blake2b } from "@noble/hashes/blake2.js";

export const combine = (a) => (b) => {
  const buf = new Uint8Array(a.length + b.length);
  buf.set(a, 0);
  buf.set(b, a.length);
  return blake2b(buf, { dkLen: 32 });
};

export const nibble = (path) => (index) => {
  const byte = path[index >> 1];
  return index % 2 === 0 ? byte >> 4 : byte & 0x0f;
};

export const nibbles = (path) => (start) => (end) => {
  const result = [];
  for (let i = start; i < end; i++) {
    result.push(nibble(path)(i));
  }
  return new Uint8Array(result);
};

export const suffix = (path) => (cursor) => {
  if (cursor % 2 === 0) {
    const tail = path.slice(cursor / 2);
    const result = new Uint8Array(1 + tail.length);
    result[0] = 0xff;
    result.set(tail, 1);
    return result;
  } else {
    const tail = path.slice((cursor + 1) / 2);
    const nib = nibble(path)(cursor);
    const result = new Uint8Array(2 + tail.length);
    result[0] = 0;
    result[1] = nib;
    result.set(tail, 2);
    return result;
  }
};

export const sliceBytes = (offset) => (length) => (arr) =>
  arr.slice(offset, offset + length);

export const concatBytes = (a) => (b) => {
  const buf = new Uint8Array(a.length + b.length);
  buf.set(a, 0);
  buf.set(b, a.length);
  return buf;
};

export const pushByte = (byte) => (arr) => {
  const result = new Uint8Array(1 + arr.length);
  result[0] = byte;
  result.set(arr, 1);
  return result;
};

export const dropBytes = (n) => (arr) => arr.slice(n);

export const emptyBytes = new Uint8Array(0);

export const lengthBytes = (arr) => arr.length;

export const getByte = (arr) => (i) => arr[i];
