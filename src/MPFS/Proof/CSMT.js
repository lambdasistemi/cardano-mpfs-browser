import { blake2b } from "@noble/hashes/blake2.js";

// Serialize a Key (array of directions) to bytes:
// uint16be length + packed bits (MSB first, 8 per byte)
function serializeKey(dirs) {
  const numBytes = Math.ceil(dirs.length / 8);
  const buf = new Uint8Array(2 + numBytes);
  buf[0] = (dirs.length >> 8) & 0xff;
  buf[1] = dirs.length & 0xff;
  for (let i = 0; i < dirs.length; i++) {
    if (dirs[i] === 1) {
      const byteIdx = Math.floor(i / 8);
      const bitIdx = 7 - (i % 8);
      buf[2 + byteIdx] |= 1 << bitIdx;
    }
  }
  return buf;
}

// Serialize a sized ByteString: uint16be length + bytes
function serializeSizedBytes(bytes) {
  const buf = new Uint8Array(2 + bytes.length);
  buf[0] = (bytes.length >> 8) & 0xff;
  buf[1] = bytes.length & 0xff;
  buf.set(bytes, 2);
  return buf;
}

// Serialize an Indirect { jump, value }
function serializeIndirect(indirect) {
  const keyBytes = serializeKey(indirect.jump);
  const valBytes = serializeSizedBytes(indirect.value);
  const buf = new Uint8Array(
    keyBytes.length + valBytes.length,
  );
  buf.set(keyBytes, 0);
  buf.set(valBytes, keyBytes.length);
  return buf;
}

// rootHash = blake2b(serialize(indirect))
export const rootHash = (indirect) =>
  blake2b(serializeIndirect(indirect), { dkLen: 32 });

// addWithDirection: direction -> me -> sibling -> hash
// L (0): blake2b(serialize(me) ++ serialize(sibling))
// R (1): blake2b(serialize(sibling) ++ serialize(me))
export const addWithDirection =
  (direction) => (me) => (sibling) => {
    const meBytes = serializeIndirect(me);
    const sibBytes = serializeIndirect(sibling);
    let buf;
    if (direction === 0) {
      buf = new Uint8Array(
        meBytes.length + sibBytes.length,
      );
      buf.set(meBytes, 0);
      buf.set(sibBytes, meBytes.length);
    } else {
      buf = new Uint8Array(
        sibBytes.length + meBytes.length,
      );
      buf.set(sibBytes, 0);
      buf.set(meBytes, sibBytes.length);
    }
    return blake2b(buf, { dkLen: 32 });
  };

export const bytesEq = (a) => (b) => {
  if (a.length !== b.length) return false;
  for (let i = 0; i < a.length; i++) {
    if (a[i] !== b[i]) return false;
  }
  return true;
};
