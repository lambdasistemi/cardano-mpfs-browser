import { blake2b } from "@noble/hashes/blake2.js";

const combine = (a, b) => {
  const buf = new Uint8Array(a.length + b.length);
  buf.set(a, 0);
  buf.set(b, a.length);
  return blake2b(buf, { dkLen: 32 });
};

export const nullHash = new Uint8Array(32);
export const nullHash2 = combine(nullHash, nullHash);
export const nullHash4 = combine(nullHash2, nullHash2);
export const nullHash8 = combine(nullHash4, nullHash4);
