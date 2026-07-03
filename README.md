# halal-chain-poc

A proof-of-concept blockchain infrastructure for **Halal Food Supply Chain Traceability** — a system that tracks products from producer/slaughterhouse to retailer, with tamper-proof halal certification and multi-authority governance.

## Problem Statement

Conventional halal certification faces several structural issues:
- **Certificate fraud** — physical/PDF documents are easy to forge or manipulate
- **Single point of authority** — many systems rely on one certifying body, even though halal certification in practice often involves more than one party (e.g. a national authority plus an internal auditor)
- **Untracked cross-contamination** — once a product changes hands (distributor, retailer), handling history is often lost
- **Undetected certificate expiry** — a product's "halal" status can remain marked valid even after its certificate has expired

This project isn't a generic blockchain traceability template rebranded — several design decisions below directly address the issues above.

## Architecture & Design Decisions

### Role-based access control
Four separate roles (`PRODUCER_ROLE`, `CERTIFIER_ROLE`, `DISTRIBUTOR_ROLE`, `RETAILER_ROLE`) using OpenZeppelin `AccessControl` instead of `Ownable` — because halal certification naturally involves multiple parties with distinct authority, and roles can be granted/revoked without redeploying the contract.

### Multi-certifier consensus
Certification isn't finalized by a single approval. The contract requires a quorum (`DEFAULT_REQUIRED_APPROVALS`) of certifiers before a product's status becomes `Certified`. This reflects the reality that halal certifying authority is often collective rather than singular.

### Certificate expiry validation
Certificates carry an `expiresAt` timestamp, and their validity is actively checked (not just a static status flag) via `isCertificateValid()`. Custody transfer reverts if the certificate has expired, preventing an "expired halal" product from circulating under a misleading status.

### Contamination whistleblower flag
`flagContamination()` is deliberately callable by anyone, not restricted to a specific role — a whistleblower pattern, since cross-contamination is often first noticed by parties outside the formal chain (e.g. warehouse staff, an independent auditor).

### Full custody chain tracking
Every change of hands is recorded as an array (not just the current holder), so the complete history from producer to retailer can be audited at any point.

### Consumer-facing single-call lookup
`getProductFullHistory()` returns all relevant data (product, certificate, custody chain, validity) in a single call — designed for a future consumer-facing dashboard/QR-scan flow, avoiding multiple expensive RPC calls.

## Tech Stack

- **Solidity 0.8.34** + **Foundry** (Forge for testing, Anvil for local node)
- **OpenZeppelin Contracts** (AccessControl)
- Planned: Docker, Kubernetes, Terraform for the infrastructure layer; IPFS for certificate document storage

## Product Status Flow

```
Registered → Certified → InTransit → Delivered
                ↓
             Revoked / Flagged (can occur at any point)
```

## Usage

### Build
```bash
forge build
```

### Test
```bash
forge test -vvv
```

### Coverage
```bash
forge coverage
```

### Local node
```bash
anvil
```

## Test Coverage

16/16 tests passing — covering critical scenarios: certificate revocation mid-custody-chain, custody transfer with an expired certificate, multi-certifier consensus (auto-finalize, revert on duplicate approval, revert on already-finalized), and contamination flagging by a non-role account.

```bash
forge coverage
```
Lines: 96.23% | Branches: 81.25% | Functions: 88.89%

## Roadmap

- [x] **Phase 1** — Smart contract core: role management, custody tracking, certificate lifecycle, multi-certifier consensus
- [ ] **Phase 2** — Containerization (Docker), REST API layer, IPFS integration for certificate documents, deployment to Kubernetes + Terraform (AWS)
- [ ] **Phase 3** — Observability (Prometheus/Grafana), authenticated API gateway (Nginx)
- [ ] **Phase 4** — Consumer-facing dashboard for product lookup/scan

## Disclaimer

This is a proof-of-concept built for technical portfolio purposes, not an audited or officially certified production system by any halal certifying authority.

## License

MIT
