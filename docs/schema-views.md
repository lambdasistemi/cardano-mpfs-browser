# Schema & View Templates

## The Problem

MPFS stores facts as raw bytestrings. In real applications these
will be structured data (JSON-LD, CBOR, etc.) but the trie is
format-agnostic. The frontend needs to know how to interpret
and render the bytes.

## Schema Discovery

The oracle publishes the token ID and the schema together. The
schema's hash is stored as a fact in the trie, so the trust chain
applies to the schema itself — a bogus schema would fail hash
verification.

```mermaid
sequenceDiagram
    participant O as Oracle
    participant U as User/Frontend
    participant API as MPFS API

    Note over O: Publishes: token ID + schema

    U->>U: Receive token ID and schema from oracle

    U->>API: GET /tokens/:id/facts/__schema__
    API-->>U: schema_hash + MPF proof

    U->>U: Verify MPF proof against cage root
    U->>U: Hash schema, compare with fact
    U->>U: Schema verified ✓

    U->>API: GET /tokens/:id/facts/:key
    API-->>U: raw bytes + MPF proof

    U->>U: Verify MPF proof
    U->>U: Decode bytes using verified schema
    U->>U: Render structured fact to user
```

The schema is as trustworthy as any other fact in the trie. If
the oracle updates the schema, the hash fact is updated too, and
the frontend detects the change on next verification.

## Schema and View Templates

The oracle publishes two kinds of metadata, both hashed into
the trie as facts:

**Schema** — how to decode fact bytes:

- **Encoding** — JSON, CBOR, UTF-8, custom
- **Fields** — named fields with types

**View templates** — how to render decoded facts for humans:

- **Labels** — display names for fields
- **Formatting** — dates, amounts, identifiers
- **Layout** — which fields are primary, grouping, ordering

The schema and the view templates are separate concerns. The
schema is stable (changing it means changing fact encoding). View
templates evolve freely — new views can be added without touching
the schema or existing facts.

```mermaid
graph TB
    subgraph "Trie (hashed facts)"
        S["__schema__<br/>hash of schema"]
        V1["__view/summary__<br/>hash of summary template"]
        V2["__view/detail__<br/>hash of detail template"]
        V3["__view/ops__<br/>hash of operations template"]
        F1["fact-key-1<br/>raw bytes"]
        F2["fact-key-2<br/>raw bytes"]
    end

    subgraph "Rendering Pipeline"
        D["Decode<br/>schema → structured data"]
        R["Render<br/>view template → display"]
    end

    S -.->|"verified"| D
    F1 --> D
    F2 --> D
    V1 -.->|"verified"| R
    V2 -.->|"verified"| R
    V3 -.->|"verified"| R
    D --> R
```

## Multiple Views

A token can have multiple view templates, each hashed as a
separate fact. Different views serve different purposes:

- A **summary view** for quick browsing
- A **detail view** for full fact inspection
- An **operations view** optimized for transaction workflows
- A **domain-specific view** for a particular application

View templates are hashed in the trie, so they are verified like
any other fact. The oracle controls which views are canonical,
but the process is open: anyone can propose a new view template
to the oracle. If accepted, the oracle inserts it as a fact — a
new way of seeing the same data, immediately available and
verified.

This enables a community-driven UX evolution: users discover
better ways to present the data, submit templates, and the oracle
curates them. Complex applications can ship multiple views for
different roles or workflows without changing the underlying
data.

## View Template Lifecycle

```mermaid
sequenceDiagram
    participant C as Community
    participant O as Oracle
    participant T as Trie
    participant B as Browser

    C->>O: Propose new view template
    O->>O: Review template
    O->>T: Insert __view/proposed__ = hash
    T-->>O: MPF proof

    B->>T: GET __view/* (discover views)
    T-->>B: list of view template hashes

    B->>B: Fetch templates, verify hashes
    B->>B: User selects view

    Note over B: Same facts, different<br/>rendering — verified
```

## Schema Format

The exact schema format is TBD. Candidates:

- JSON Schema with rendering extensions
- A minimal custom format (since we only need decoding + display)
- CIP-100 / JSON-LD alignment for Cardano ecosystem compatibility
