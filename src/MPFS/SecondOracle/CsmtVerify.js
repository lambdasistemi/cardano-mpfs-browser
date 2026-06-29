import { WASI, File, OpenFile, ConsoleStdout }
  from "@bjorn3/browser_wasi_shim";

const dynamicImport = new Function("specifier", "return import(specifier)");

let nodeCompiledModulePromise = null;

export const verifyInclusionImpl = (rootHex) => (proofHex) => () => {
  let stdinBytes;
  try {
    stdinBytes = buildInclusionStdin(rootHex, proofHex);
  } catch (_err) {
    return Promise.resolve(false);
  }

  if (typeof globalThis.runCsmtVerifyWasm === "function") {
    return globalThis.runCsmtVerifyWasm(stdinBytes);
  }

  return runCsmtVerifyNode(stdinBytes);
};

function buildInclusionStdin(rootHex, proofHex) {
  const rootBytes = hexToBytes("root", rootHex);
  if (rootBytes.byteLength !== 32) {
    throw new Error("root must be 32 bytes");
  }

  const proofBytes = hexToBytes("proof", proofHex);
  const stdinBytes = new Uint8Array(1 + rootBytes.byteLength + proofBytes.byteLength);
  stdinBytes[0] = 0;
  stdinBytes.set(rootBytes, 1);
  stdinBytes.set(proofBytes, 1 + rootBytes.byteLength);
  return stdinBytes;
}

function hexToBytes(label, hex) {
  if (typeof hex !== "string" || hex.length % 2 !== 0) {
    throw new Error(`${label} hex must have an even length`);
  }

  const bytes = new Uint8Array(hex.length / 2);
  for (let offset = 0; offset < hex.length; offset += 2) {
    const byte = Number.parseInt(hex.slice(offset, offset + 2), 16);
    if (Number.isNaN(byte)) {
      throw new Error(`${label} hex contains non-hex characters`);
    }
    bytes[offset / 2] = byte;
  }
  return bytes;
}

async function runCsmtVerifyNode(stdinBytes) {
  try {
    const wasmPath = await nodeWasmPath();
    const mod = await compileNodeWasm(wasmPath);
    return await runModule(mod, stdinBytes);
  } catch (_err) {
    return false;
  }
}

async function nodeWasmPath() {
  const processRef = globalThis.process;
  if (processRef?.env?.CSMT_VERIFY_WASM) {
    return processRef.env.CSMT_VERIFY_WASM;
  }
  if (processRef?.env?.CSMT_VERIFY_WASM_PATH) {
    return processRef.env.CSMT_VERIFY_WASM_PATH;
  }

  const path = await dynamicImport("node:path");
  return path.join(
    processRef?.cwd?.() ?? ".",
    "src",
    "assets",
    "csmt-verify-wasm.wasm"
  );
}

async function compileNodeWasm(wasmPath) {
  if (nodeCompiledModulePromise === null) {
    nodeCompiledModulePromise = (async () => {
      const fs = await dynamicImport("node:fs/promises");
      return WebAssembly.compile(await fs.readFile(wasmPath));
    })();
  }

  return nodeCompiledModulePromise;
}

async function runModule(mod, stdinBytes) {
  const stdin = new OpenFile(new File(stdinBytes));
  const stdout = new ConsoleStdout(() => {});
  const stderr = new ConsoleStdout(() => {});
  const wasi = new WASI([], [], [stdin, stdout, stderr]);
  const inst = await WebAssembly.instantiate(mod, {
    wasi_snapshot_preview1: wasi.wasiImport,
  });

  try {
    return wasi.start(inst) === 0;
  } catch (_err) {
    return false;
  }
}
