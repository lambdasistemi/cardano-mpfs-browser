// Minimal CBOR decoder for CSMT inclusion proofs.
// Supports: unsigned integers, bytestrings, arrays.

class CborReader {
  constructor(bytes) {
    this.bytes = bytes;
    this.offset = 0;
  }

  readByte() {
    return this.bytes[this.offset++];
  }

  readArgument(additionalInfo) {
    if (additionalInfo < 24) return additionalInfo;
    if (additionalInfo === 24) return this.readByte();
    if (additionalInfo === 25) {
      const hi = this.readByte();
      const lo = this.readByte();
      return (hi << 8) | lo;
    }
    if (additionalInfo === 26) {
      let val = 0;
      for (let i = 0; i < 4; i++)
        val = (val << 8) | this.readByte();
      return val;
    }
    throw new Error("CBOR: unsupported argument size");
  }

  readUint() {
    const b = this.readByte();
    const major = b >> 5;
    if (major !== 0) throw new Error("CBOR: expected uint");
    return this.readArgument(b & 0x1f);
  }

  readBytes() {
    const b = this.readByte();
    const major = b >> 5;
    if (major !== 2) throw new Error("CBOR: expected bytes");
    const len = this.readArgument(b & 0x1f);
    const result = this.bytes.slice(this.offset, this.offset + len);
    this.offset += len;
    return result;
  }

  readArrayLen() {
    const b = this.readByte();
    const major = b >> 5;
    if (major !== 4) throw new Error("CBOR: expected array");
    return this.readArgument(b & 0x1f);
  }
}

// Direction: 0 = L, 1 = R
// Key: array of directions (CBOR: list-len + word per direction)
function readKey(r) {
  const len = r.readArrayLen();
  const dirs = [];
  for (let i = 0; i < len; i++) {
    dirs.push(r.readUint());
  }
  return dirs;
}

// Indirect: [key, bytes]
function readIndirect(r) {
  r.readArrayLen(); // 2
  const jump = readKey(r);
  const value = r.readBytes();
  return { jump, value };
}

// ProofStep: [consumed, indirect]
function readProofStep(r) {
  r.readArrayLen(); // 2
  const stepConsumed = r.readUint();
  const stepSibling = readIndirect(r);
  return { stepConsumed, stepSibling };
}

// InclusionProof: [key, value, rootHash, [steps], rootJump]
export const decodeProofImpl = (bytes) => {
  const r = new CborReader(bytes);
  r.readArrayLen(); // 5
  const proofKey = readKey(r);
  const proofValue = r.readBytes();
  const proofRootHash = r.readBytes();
  const stepsLen = r.readArrayLen();
  const proofSteps = [];
  for (let i = 0; i < stepsLen; i++) {
    proofSteps.push(readProofStep(r));
  }
  const proofRootJump = readKey(r);
  return {
    proofKey,
    proofValue,
    proofRootHash,
    proofSteps,
    proofRootJump,
  };
};
