import { WASI, File, OpenFile, ConsoleStdout }
  from "@bjorn3/browser_wasi_shim";

const dynamicImport = new Function("specifier", "return import(specifier)");

let nodeCompiledModulePromise = null;

export const runCageReactorImpl = (stdinText) => () => {
  if (typeof globalThis.runCageReactor === "function") {
    return globalThis.runCageReactor(stdinText);
  }

  return runCageReactorNode(stdinText);
};

async function runCageReactorNode(stdinText) {
  try {
    const wasmPath = await nodeWasmPath();
    const mod = await compileNodeWasm(wasmPath);
    const result = await runModule(mod, stdinText);
    return result;
  } catch (err) {
    return {
      stdout: "",
      stderr: String(err?.stack ?? err),
      exitOk: false,
    };
  }
}

async function nodeWasmPath() {
  const processRef = globalThis.process;
  if (processRef?.env?.MPFS_CAGE_REACTOR_WASM) {
    return processRef.env.MPFS_CAGE_REACTOR_WASM;
  }

  const path = await dynamicImport("node:path");
  return path.join(
    processRef?.cwd?.() ?? ".",
    "src",
    "assets",
    "mpfs-cage-reactor.wasm"
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

async function runModule(mod, stdinText) {
  const stdin = new OpenFile(
    new File(new TextEncoder().encode(stdinText))
  );
  const stdoutChunks = [];
  const stderrChunks = [];
  const stdout = new ConsoleStdout((chunk) => stdoutChunks.push(chunk));
  const stderr = new ConsoleStdout((chunk) => stderrChunks.push(chunk));
  const wasi = new WASI([], [], [stdin, stdout, stderr]);
  const inst = await WebAssembly.instantiate(mod, {
    wasi_snapshot_preview1: wasi.wasiImport,
  });

  let exitOk = true;
  try {
    wasi.start(inst);
  } catch (err) {
    exitOk = false;
    stderrChunks.push(new TextEncoder().encode(String(err)));
  }

  return {
    stdout: decodeChunks(stdoutChunks),
    stderr: decodeChunks(stderrChunks),
    exitOk,
  };
}

function decodeChunks(chunks) {
  const normalized = chunks.map((chunk) =>
    typeof chunk === "string" ? new TextEncoder().encode(chunk) : chunk
  );
  const size = normalized.reduce(
    (total, chunk) => total + chunk.byteLength,
    0
  );
  const bytes = new Uint8Array(size);
  let offset = 0;
  for (const chunk of normalized) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return new TextDecoder().decode(bytes);
}
