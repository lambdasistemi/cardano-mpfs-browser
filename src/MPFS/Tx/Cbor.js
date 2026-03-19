// Cardano Conway-era transaction CBOR decoder.
// Extracts: inputs, outputs, fee, mint, redeemers, datums.
//
// CBOR structure:
//   Tx = [body, witnesses, isValid, auxiliaryData]
//   body = map { 0: inputs, 1: outputs, 2: fee, 9: mint, ... }
//
// We only decode the fields needed for the MPFS transaction
// review screen.

class CborReader {
  constructor(bytes) {
    this.bytes = bytes;
    this.offset = 0;
  }

  peekByte() {
    return this.bytes[this.offset];
  }

  readByte() {
    return this.bytes[this.offset++];
  }

  readArgument(additionalInfo) {
    if (additionalInfo < 24) return additionalInfo;
    if (additionalInfo === 24) return this.readByte();
    if (additionalInfo === 25) {
      return (this.readByte() << 8) | this.readByte();
    }
    if (additionalInfo === 26) {
      let val = 0;
      for (let i = 0; i < 4; i++) val = (val << 8) | this.readByte();
      return val;
    }
    if (additionalInfo === 27) {
      // 8-byte integer — use BigInt for safety then convert
      let val = 0n;
      for (let i = 0; i < 8; i++)
        val = (val << 8n) | BigInt(this.readByte());
      return Number(val);
    }
    if (additionalInfo === 31) return -1; // indefinite length
    throw new Error("CBOR: unsupported argument size " + additionalInfo);
  }

  // Read the major type and argument of the next item.
  readHeader() {
    const b = this.readByte();
    const major = b >> 5;
    const info = b & 0x1f;
    return { major, arg: this.readArgument(info), raw: info };
  }

  readUint() {
    const { major, arg } = this.readHeader();
    if (major !== 0) throw new Error("CBOR: expected uint, got major " + major);
    return arg;
  }

  // Read a signed or unsigned integer (major 0 or 1).
  readInt() {
    const { major, arg } = this.readHeader();
    if (major === 0) return arg;
    if (major === 1) return -1 - arg;
    throw new Error("CBOR: expected int, got major " + major);
  }

  readBytes() {
    const { major, arg } = this.readHeader();
    if (major !== 2) throw new Error("CBOR: expected bytes, got major " + major);
    const result = this.bytes.slice(this.offset, this.offset + arg);
    this.offset += arg;
    return result;
  }

  readMapLen() {
    const { major, arg } = this.readHeader();
    if (major !== 5) throw new Error("CBOR: expected map, got major " + major);
    return arg;
  }

  readArrayLen() {
    const { major, arg } = this.readHeader();
    if (major !== 4) throw new Error("CBOR: expected array, got major " + major);
    return arg;
  }

  // Read a tag (major 6).
  readTag() {
    const { major, arg } = this.readHeader();
    if (major !== 6) throw new Error("CBOR: expected tag, got major " + major);
    return arg;
  }

  // Skip any CBOR value (for fields we don't care about).
  skip() {
    const b = this.readByte();
    const major = b >> 5;
    const info = b & 0x1f;
    const arg = this.readArgument(info);

    switch (major) {
      case 0: // uint
      case 1: // neg int
        break;
      case 2: // bytes
      case 3: // text
        this.offset += arg;
        break;
      case 4: // array
        if (arg === -1) {
          while (this.peekByte() !== 0xff) this.skip();
          this.readByte(); // consume break
        } else {
          for (let i = 0; i < arg; i++) this.skip();
        }
        break;
      case 5: // map
        if (arg === -1) {
          while (this.peekByte() !== 0xff) {
            this.skip();
            this.skip();
          }
          this.readByte(); // consume break
        } else {
          for (let i = 0; i < arg; i++) {
            this.skip();
            this.skip();
          }
        }
        break;
      case 6: // tag
        this.skip();
        break;
      case 7: // simple/float
        break;
      default:
        throw new Error("CBOR: unknown major " + major);
    }
  }
}

// --- Hex helpers ---

function bytesToHex(bytes) {
  let hex = "";
  for (let i = 0; i < bytes.length; i++) {
    hex += bytes[i].toString(16).padStart(2, "0");
  }
  return hex;
}

// --- Input decoding ---

// TxIn = [txId(bytes32), txIx(uint)]
function readTxIn(r) {
  r.readArrayLen(); // 2
  const txId = bytesToHex(r.readBytes());
  const txIx = r.readUint();
  return { txId, txIx };
}

// Inputs are wrapped in tag 258 (set semantics).
function readInputs(r) {
  const b = r.peekByte();
  const major = b >> 5;
  // May or may not have tag 258
  if (major === 6) {
    r.readTag(); // 258
  }
  const len = r.readArrayLen();
  const inputs = [];
  for (let i = 0; i < len; i++) {
    inputs.push(readTxIn(r));
  }
  return inputs;
}

// --- Output decoding ---

// TxOut can be:
//  - legacy: [address, value]
//  - alonzo: [address, value, datumHash]
//  - babbage: map { 0: address, 1: value, 2: datum }
function readOutput(r) {
  const b = r.peekByte();
  const major = b >> 5;

  if (major === 5) {
    // Babbage map format
    const len = r.readMapLen();
    let address = null;
    let value = null;
    let datum = null;
    for (let i = 0; i < len; i++) {
      const key = r.readUint();
      if (key === 0) {
        address = bytesToHex(r.readBytes());
      } else if (key === 1) {
        value = readValue(r);
      } else if (key === 2) {
        datum = readDatum(r);
      } else {
        r.skip();
      }
    }
    return { address, value, datum };
  } else {
    // Legacy array format
    const len = r.readArrayLen();
    const address = bytesToHex(r.readBytes());
    const value = readValue(r);
    const datum = len >= 3 ? readDatum(r) : null;
    return { address, value, datum };
  }
}

// Value = uint (lovelace only) | [lovelace, multiasset]
function readValue(r) {
  const b = r.peekByte();
  const major = b >> 5;
  if (major === 0) {
    return { lovelace: r.readUint(), assets: {} };
  }
  // [lovelace, multiasset]
  r.readArrayLen(); // 2
  const lovelace = r.readUint();
  const assets = readMultiAsset(r);
  return { lovelace, assets };
}

// MultiAsset = map(policyId -> map(assetName -> amount))
function readMultiAsset(r) {
  const numPolicies = r.readMapLen();
  const assets = {};
  for (let i = 0; i < numPolicies; i++) {
    const policyId = bytesToHex(r.readBytes());
    const numAssets = r.readMapLen();
    const policyAssets = {};
    for (let j = 0; j < numAssets; j++) {
      const name = bytesToHex(r.readBytes());
      const amount = r.readInt();
      policyAssets[name] = amount;
    }
    assets[policyId] = policyAssets;
  }
  return assets;
}

// Datum options:
//  - [0, datumHash]     datum hash
//  - [1, plutusData]    inline datum (tag 24 wrapping CBOR bytes)
function readDatum(r) {
  const b = r.peekByte();
  const major = b >> 5;
  if (major === 4) {
    const len = r.readArrayLen();
    const tag = r.readUint();
    if (tag === 0) {
      return { type: "hash", hash: bytesToHex(r.readBytes()) };
    }
    if (tag === 1) {
      // Inline datum: tag(24, bytes)
      const datumTag = r.readTag(); // 24
      const datumBytes = r.readBytes();
      return { type: "inline", cbor: bytesToHex(datumBytes) };
    }
    // Skip remaining fields
    for (let i = 2; i < len; i++) r.skip();
    return { type: "unknown" };
  }
  // Simple value (null etc.)
  r.skip();
  return null;
}

// --- Mint decoding ---

// Mint = multiasset map (same as in value)
function readMint(r) {
  return readMultiAsset(r);
}

// --- Redeemer decoding ---

// Conway redeemers: map([tag, index] -> [data, exUnits])
function readRedeemers(r) {
  const numRedeemers = r.readMapLen();
  const redeemers = [];
  for (let i = 0; i < numRedeemers; i++) {
    // Key: [tag, index]
    r.readArrayLen(); // 2
    const tag = r.readUint();
    const index = r.readUint();
    // Value: [data, exUnits]
    r.readArrayLen(); // 2
    // Skip plutus data (complex) — store raw CBOR offset
    const dataStart = r.offset;
    r.skip();
    const dataEnd = r.offset;
    const dataCbor = bytesToHex(r.bytes.slice(dataStart, dataEnd));
    // ExUnits: [mem, steps]
    r.readArrayLen(); // 2
    const mem = r.readUint();
    const steps = r.readUint();

    const purpose =
      tag === 0
        ? "spend"
        : tag === 1
          ? "mint"
          : tag === 2
            ? "cert"
            : tag === 3
              ? "reward"
              : "unknown(" + tag + ")";
    redeemers.push({ purpose, index, dataCbor, exUnits: { mem, steps } });
  }
  return redeemers;
}

// --- Top-level transaction decoder ---

export const decodeTxImpl = (bytes) => {
  const r = new CborReader(new Uint8Array(bytes));

  // Tx = [body, witnesses, isValid, auxiliaryData]
  r.readArrayLen(); // 4

  // Body = map { 0: inputs, 1: outputs, 2: fee, ... }
  const bodyLen = r.readMapLen();
  let inputs = [];
  let collateralInputs = [];
  let outputs = [];
  let fee = 0;
  let mint = {};

  for (let i = 0; i < bodyLen; i++) {
    const key = r.readUint();
    switch (key) {
      case 0:
        inputs = readInputs(r);
        break;
      case 1:
        {
          const outLen = r.readArrayLen();
          for (let j = 0; j < outLen; j++) {
            outputs.push(readOutput(r));
          }
        }
        break;
      case 2:
        fee = r.readUint();
        break;
      case 9:
        mint = readMint(r);
        break;
      case 13:
        collateralInputs = readInputs(r);
        break;
      default:
        r.skip();
        break;
    }
  }

  // Witnesses = map { 5: redeemers, ... }
  const witLen = r.readMapLen();
  let redeemers = [];
  for (let i = 0; i < witLen; i++) {
    const key = r.readUint();
    if (key === 5) {
      redeemers = readRedeemers(r);
    } else {
      r.skip();
    }
  }

  // isValid (bool)
  const isValid = r.peekByte() !== 0xf4; // f4 = false, f5 = true
  r.skip();

  // auxiliaryData — skip
  r.skip();

  return {
    inputs,
    collateralInputs,
    outputs,
    fee,
    mint,
    redeemers,
    isValid,
  };
};
