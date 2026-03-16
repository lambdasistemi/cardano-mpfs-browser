import { blake2b } from "@noble/hashes/blake2.js";
import {
  bytesToHex,
  hexToBytes,
} from "@noble/hashes/utils.js";

export const blake2b256Impl = (bytes) => blake2b(bytes, { dkLen: 32 });
export const bytesToHexImpl = bytesToHex;
export const hexToBytesImpl = hexToBytes;
