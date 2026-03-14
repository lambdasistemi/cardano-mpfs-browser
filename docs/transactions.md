# Transactions

## Transaction Flow

The client interacts with the cage protocol through the MPFS API.
The API builds unsigned transactions; the client decodes them,
displays their MPFS semantics in human-readable form, and
delegates signing to the user's CIP-30 wallet.

Because the API is untrusted, the client always decodes the
unsigned CBOR before requesting a signature — the user sees
exactly what they are signing.

```mermaid
sequenceDiagram
    participant U as User
    participant FE as Frontend
    participant API as MPFS API
    participant W as CIP-30 Wallet

    U->>FE: "Insert fact X=Y into token T"
    FE->>API: POST /tx/request/insert {token, key, value, address}
    API-->>FE: unsigned tx (CBOR hex)

    FE->>FE: Decode CBOR, extract TxIns

    loop For each TxIn
        FE->>API: GET /utxo/:txin
        API-->>FE: TxOut (datum, value, address)
        FE->>API: GET /utxo/:txin/proof
        API-->>FE: CSMT inclusion proof
        FE->>FE: Verify TxIn exists in UTXO set
    end

    FE->>FE: Parse MPFS semantics from tx body
    FE->>FE: Render resolved inputs with proof status

    FE->>U: Display verified transaction
    Note over FE,U: Inputs (verified on-chain):<br/>• Cage UTxO root=abc... ✓<br/>Operation:<br/>• Insert key "X" = value "Y"<br/>• Fee: 1.5 ADA

    U->>FE: "Approve"
    FE->>W: api.signTx(unsignedTx)
    W-->>FE: signed tx

    FE->>API: POST /tx/submit {signed tx}
    API-->>FE: TxId
    FE->>U: "Submitted: tx abc123..."
```

## Input Resolution and Verification

The unsigned transaction contains TxIns — references to UTxOs
being spent. Raw TxIns are opaque hashes. The client **resolves**
each TxIn to its full TxOut content and **verifies** it exists
in the UTXO set via a CSMT proof.

```mermaid
graph LR
    subgraph "Unsigned Tx"
        TI1["TxIn #1<br/>(hash)"]
        TI2["TxIn #2<br/>(hash)"]
    end

    subgraph "Resolved + Verified"
        TO1["TxOut #1<br/>cage UTxO<br/>root: abc...<br/>value: 5 ADA<br/>✓ CSMT proof"]
        TO2["TxOut #2<br/>user UTxO<br/>addr: addr1...<br/>value: 10 ADA<br/>✓ CSMT proof"]
    end

    TI1 -->|"GET /utxo/:txin<br/>+ proof"| TO1
    TI2 -->|"GET /utxo/:txin<br/>+ proof"| TO2
```

This is critical: without resolving and verifying inputs, the
user cannot know what the transaction actually spends. The API
could claim a TxIn points to one UTxO while the transaction
actually consumes another. The CSMT proof makes this impossible
— each input is independently proven to exist in the UTXO set.

## What the Frontend Displays

From the decoded transaction and resolved inputs, the frontend
presents:

| Field | Source | Display |
|-------|--------|---------|
| **Inputs** | TxIns, resolved via API | Full TxOut content with CSMT proof status |
| Cage UTxO | Input datum | Trie root, owner, config — verified on-chain |
| Operation | Redeemer (Contribute/Modify/Mint) | "Insert", "Delete", "Update", "Boot", "Retract", "End" |
| Token | Asset name in tx outputs | Token identifier |
| Key | Request datum field | Decoded via verified schema |
| Value | Request datum field | Decoded via verified schema |
| Fee | Tx fee field | ADA amount |
| Address | Tx output addresses | Bech32, highlighted if user's |

If the schema is verified, the key and value are rendered in
structured form. Otherwise they are shown as hex with a warning
that no verified schema is available.

Every input carries a proof indicator. If any input cannot be
verified, the UI warns prominently — the user should not sign
a transaction with unverified inputs.

## Transaction Signing State Machine

```mermaid
stateDiagram-v2
    [*] --> SelectOperation: user chooses action
    SelectOperation --> BuildingTx: submit parameters
    BuildingTx --> TxReceived: API returns unsigned CBOR

    TxReceived --> Decoding: parse CBOR
    Decoding --> Decoded: extract MPFS semantics
    Decoding --> DecodeFailed: malformed or unexpected

    Decoded --> ReviewPending: display to user
    ReviewPending --> Approved: user approves
    ReviewPending --> Rejected: user rejects

    Approved --> Signing: CIP-30 signTx
    Signing --> Signed: wallet returns signature
    Signing --> SignFailed: wallet refused

    Signed --> Submitting: POST /tx/submit
    Submitting --> Submitted: TxId received
    Submitting --> SubmitFailed: submission error

    Rejected --> [*]
    DecodeFailed --> [*]
    SignFailed --> [*]
    SubmitFailed --> [*]
    Submitted --> [*]
```

## Why the Server Doesn't Matter

The MPFS off-chain service is a convenience layer. The client
independently verifies everything:

- **Facts** — verified via the full proof chain
- **Transactions** — decoded and displayed before signing
- **State** — anchored on-chain via cage UTxOs

The server could lie, omit data, or be compromised. The client
catches it because every claim requires a cryptographic proof.
This is the key value proposition: a trusted client that works
with any untrusted server.
