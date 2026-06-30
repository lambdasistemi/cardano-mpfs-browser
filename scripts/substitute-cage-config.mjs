#!/usr/bin/env node

import {
  existsSync,
  readdirSync,
  readFileSync,
  statSync,
  writeFileSync,
} from "node:fs";
import { join } from "node:path";

const REQUIRED_VALUES = [
  {
    name: "cageScriptBytes",
    placeholder: "__MPFS_CAGE_SCRIPT_BYTES__",
    title: "state.state.mint",
    field: "compiledCode",
  },
  {
    name: "requestScriptBytes",
    placeholder: "__MPFS_REQUEST_SCRIPT_BYTES__",
    title: "request.request.spend",
    field: "compiledCode",
  },
  {
    name: "cfgScriptHash",
    placeholder: "__MPFS_CAGE_SCRIPT_HASH__",
    title: "state.state.mint",
    field: "hash",
  },
];

function fail(message) {
  throw new Error(message);
}

function usage() {
  fail(
    "usage: substitute-cage-config.mjs <substitute|verify> <blueprint-path> <bundle-path>",
  );
}

function readBlueprint(blueprintPath) {
  if (!blueprintPath) {
    usage();
  }
  if (!existsSync(blueprintPath)) {
    fail(`blueprint path does not exist: ${blueprintPath}`);
  }

  const stats = statSync(blueprintPath);
  const jsonPath = stats.isDirectory()
    ? locateBlueprintJson(blueprintPath)
    : blueprintPath;

  try {
    return JSON.parse(readFileSync(jsonPath, "utf8"));
  } catch (error) {
    fail(`failed to parse blueprint JSON at ${jsonPath}: ${error.message}`);
  }
}

function locateBlueprintJson(directory) {
  const preferred = join(directory, "plutus.json");
  if (existsSync(preferred)) {
    return preferred;
  }

  const candidates = readdirSync(directory)
    .filter((entry) => entry.endsWith(".json"))
    .map((entry) => join(directory, entry));

  if (candidates.length === 1) {
    return candidates[0];
  }

  fail(
    `could not locate blueprint JSON in ${directory}; expected plutus.json or one .json file`,
  );
}

function extractCageConfig(blueprint) {
  if (!Array.isArray(blueprint.validators)) {
    fail("blueprint is missing validators array");
  }

  return Object.fromEntries(
    REQUIRED_VALUES.map(({ name, title, field }) => {
      const validator = blueprint.validators.find((item) => item.title === title);
      if (!validator) {
        fail(`blueprint is missing validator title ${title}`);
      }

      const value = validator[field];
      validateHex(name, title, field, value);
      return [name, value];
    }),
  );
}

function validateHex(name, title, field, value) {
  if (typeof value !== "string" || value.length === 0) {
    fail(`${name} from ${title}.${field} is empty or not a string`);
  }
  if (value.length % 2 !== 0) {
    fail(`${name} from ${title}.${field} is not even-length hex`);
  }
  if (!/^[0-9a-fA-F]+$/.test(value)) {
    fail(`${name} from ${title}.${field} is not valid hex`);
  }
}

function verifyBundle(bundlePath, expected) {
  if (!bundlePath) {
    usage();
  }
  if (!existsSync(bundlePath)) {
    fail(`bundle path does not exist: ${bundlePath}`);
  }

  const bundle = readFileSync(bundlePath, "utf8");
  verifyBundleText(bundle, expected);
}

function verifyBundleText(bundle, expected) {
  const remainingPlaceholders = [...new Set(bundle.match(/__MPFS_[A-Z0-9_]+__/g) ?? [])];
  if (remainingPlaceholders.length > 0) {
    fail(
      `bundle still contains MPFS placeholders: ${remainingPlaceholders.join(", ")}`,
    );
  }

  const missingValues = Object.entries(expected)
    .filter(([, value]) => !bundle.includes(value))
    .map(([name]) => name);
  if (missingValues.length > 0) {
    fail(`bundle is missing blueprint-derived values: ${missingValues.join(", ")}`);
  }
}

function substituteBundle(bundlePath, expected) {
  if (!bundlePath) {
    usage();
  }
  if (!existsSync(bundlePath)) {
    fail(`bundle path does not exist: ${bundlePath}`);
  }

  let bundle = readFileSync(bundlePath, "utf8");
  for (const { name, placeholder } of REQUIRED_VALUES) {
    if (!bundle.includes(placeholder)) {
      fail(`bundle is missing expected placeholder ${placeholder}`);
    }
    bundle = bundle.split(placeholder).join(expected[name]);
  }

  verifyBundleText(bundle, expected);
  writeFileSync(bundlePath, bundle);
}

function main() {
  const [command, blueprintPath, bundlePath] = process.argv.slice(2);
  if (command !== "substitute" && command !== "verify") {
    usage();
  }

  const expected = extractCageConfig(readBlueprint(blueprintPath));
  if (command === "substitute") {
    substituteBundle(bundlePath, expected);
    console.log("cage config substituted from blueprint");
  } else {
    verifyBundle(bundlePath, expected);
    console.log("cage config verified from blueprint");
  }
}

try {
  main();
} catch (error) {
  console.error(`cage config verification failed: ${error.message}`);
  process.exit(1);
}
