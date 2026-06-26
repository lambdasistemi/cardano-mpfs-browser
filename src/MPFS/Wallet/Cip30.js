export const _availableWallets = () => {
  const cardano =
    (typeof window !== "undefined" && window.cardano) || {};
  const out = [];
  for (const key of Object.keys(cardano)) {
    const wallet = cardano[key];
    if (
      wallet &&
      typeof wallet.enable === "function" &&
      typeof wallet.name === "string"
    ) {
      out.push({ key, name: wallet.name, icon: wallet.icon || "" });
    }
  }
  return out;
};

export const _enable = (key) => () => window.cardano[key].enable();

export const _getNetworkId = (api) => () => api.getNetworkId();
export const _getUsedAddresses = (api) => () => api.getUsedAddresses();
export const _getChangeAddress = (api) => () => api.getChangeAddress();
export const _getBalance = (api) => () => api.getBalance();

export const _subscribeAccountChanges = (api) => (handler) => () => {
  let cancelled = false;
  const safeHandler = () => {
    if (!cancelled) handler();
  };
  const cleanups = [
    subscribeWalletEvent(api, "accountChange", safeHandler),
    subscribeWalletEvent(api, "networkChange", safeHandler),
    subscribeWalletEvent(api, "accountsChanged", safeHandler),
    subscribeWalletEvent(api, "chainChanged", safeHandler),
  ].filter(Boolean);

  return () => {
    cancelled = true;
    for (const cleanup of cleanups) {
      try {
        cleanup();
      } catch (_e) {
        // Ignore wallet cleanup errors while leaving the account.
      }
    }
  };
};

export const _signTx = (api) => (tx) => (partial) => () =>
  api.signTx(tx, partial);

export const _submitTx = (api) => (tx) => () => api.submitTx(tx);

export const _ownerKeyHashOfAddress = (addressHex) => {
  const hex = String(addressHex || "").replace(/\s+/g, "").toLowerCase();
  if (!/^[0-9a-f]+$/.test(hex) || hex.length < 58) return null;

  const header = parseInt(hex.slice(0, 2), 16);
  const addressType = header >> 4;

  if ([0, 2, 4, 6].includes(addressType)) {
    return hex.slice(2, 58);
  }
  return null;
};

export const _coinOfBalance = (hex) => {
  try {
    const bytes = hexToBytes(hex);
    let offset = 0;
    if ((bytes[0] & 0xe0) === 0x80) offset = 1;
    if ((bytes[offset] & 0xe0) !== 0x00) return null;
    const value = readUint(bytes, offset);
    return value === null ? null : value.toString();
  } catch (_e) {
    return null;
  }
};

function subscribeWalletEvent(api, eventName, handler) {
  const targets = [api && api.experimental, api].filter(Boolean);
  for (const target of targets) {
    const cleanup = trySubscribeTarget(target, eventName, handler);
    if (cleanup) return cleanup;
  }
  return null;
}

function trySubscribeTarget(target, eventName, handler) {
  try {
    if (typeof target.on === "function") {
      const result = target.on(eventName, handler);
      if (typeof result === "function") return result;
      if (typeof target.off === "function") {
        return () => target.off(eventName, handler);
      }
      if (typeof target.removeListener === "function") {
        return () => target.removeListener(eventName, handler);
      }
    }

    const method =
      "on" + eventName.charAt(0).toUpperCase() + eventName.slice(1);
    if (typeof target[method] === "function") {
      const result = target[method](handler);
      if (typeof result === "function") return result;
      return () => {};
    }
  } catch (_e) {
    return null;
  }
  return null;
}

function hexToBytes(hex) {
  const bytes = [];
  for (let i = 0; i + 1 < hex.length; i += 2) {
    bytes.push(parseInt(hex.slice(i, i + 2), 16));
  }
  return bytes;
}

function readUint(bytes, offset) {
  const info = bytes[offset] & 0x1f;
  if (info < 24) return BigInt(info);
  if (info === 24) return BigInt(bytes[offset + 1]);
  if (info === 25) {
    return (BigInt(bytes[offset + 1]) << 8n) |
      BigInt(bytes[offset + 2]);
  }
  if (info === 26) {
    let value = 0n;
    for (let i = 1; i <= 4; i++) {
      value = (value << 8n) | BigInt(bytes[offset + i]);
    }
    return value;
  }
  if (info === 27) {
    let value = 0n;
    for (let i = 1; i <= 8; i++) {
      value = (value << 8n) | BigInt(bytes[offset + i]);
    }
    return value;
  }
  return null;
}
