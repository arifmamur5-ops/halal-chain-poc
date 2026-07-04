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
Every change of hands is recorded with handler, timestamp, location, and verification status — so the complete history from producer to retailer can be audited at any point, not just "who currently holds it."

### Consumer-facing single-call lookup
`getProductFullHistory()` returns all relevant data (product, certificate, custody chain, validity) in a single call — used by the REST API layer to avoid multiple expensive RPC round-trips.

## Architecture Overview

```
┌─────────────┐      ┌──────────────┐      ┌───────────────────┐
│   Consumer  │ ───► │  REST API    │ ───► │  Smart Contract    │
│  / Frontend │      │ (Express +   │      │  (Foundry/Solidity)│
└─────────────┘      │  ethers.js)  │      └───────────────────┘
                      └──────────────┘               ▲
                                                       │
                                              ┌────────┴────────┐
                                              │  Certifiers /   │
                                              │  Producers /    │
                                              │  Distributors   │
                                              └─────────────────┘
```

Both the API and the blockchain node run as containerized services, orchestrated locally via Docker Compose and deployable to Kubernetes for a production-like environment.

## Tech Stack

- **Solidity 0.8.34** + **Foundry** (Forge for testing, Anvil for local node, Cast for on-chain interaction)
- **OpenZeppelin Contracts** (AccessControl)
- **Node.js + Express + ethers.js** — REST API layer bridging consumers and the smart contract
- **Docker** — containerized API service
- **Docker Compose** — local multi-container orchestration (Anvil + API with service networking)
- **Kubernetes** — Deployments, Services, and ConfigMaps for cluster orchestration (tested on Minikube)
- Planned: Terraform for AWS provisioning; IPFS for certificate document storage

## Product Status Flow

```
Registered → Certified → InTransit → Delivered
                ↓
             Revoked / Flagged (can occur at any point)
```

## Usage

### Smart Contract

```bash
forge build
forge test -vvv
forge coverage
anvil   # local node
```

### REST API (local)

```bash
cd api
npm install
node src/server.js
```

### Docker Compose (Anvil + API together)

```bash
export CONTRACT_ADDRESS=<deployed_contract_address>
docker compose up --build
```

### Kubernetes (Minikube)

```bash
minikube start
eval $(minikube docker-env)
docker build -t halal-chain-api:latest ./api

kubectl apply -f k8s/
kubectl port-forward svc/anvil-service 8545:8545   # in a separate terminal

forge script script/Deploy.s.sol:DeployHalalChain --rpc-url http://127.0.0.1:8545 --broadcast
# update CONTRACT_ADDRESS in k8s/api-configmap.yaml, then:
kubectl apply -f k8s/api-configmap.yaml
kubectl rollout restart deployment halal-api

minikube service halal-api-service --url
```

### API Endpoints

| Method | Endpoint | Description |
|---|---|---|
| GET | `/health` | Health check + chain connectivity status |
| GET | `/product/:id` | Full product history (product, certificate, custody chain, validity) |

## Test Coverage

16/16 tests passing — covering critical scenarios: certificate revocation mid-custody-chain, custody transfer with an expired certificate, multi-certifier consensus (auto-finalize, revert on duplicate approval, revert on already-finalized), and contamination flagging by a non-role account.

```bash
forge coverage
```
Lines: 96.23% | Branches: 81.25% | Functions: 88.89%

## CI/CD

GitHub Actions runs `forge fmt --check`, `forge build`, and `forge test` on every push to `main`, with dependency submodules fetched automatically during checkout.

## Roadmap

- [x] **Phase 1** — Smart contract core: role management, custody tracking, certificate lifecycle, multi-certifier consensus
- [x] **Phase 2** — REST API (Express + ethers.js), Dockerized, orchestrated via Docker Compose, deployed to Kubernetes (Minikube) with verified service-to-service networking
- [ ] **Phase 3** — Terraform provisioning to AWS, observability (Prometheus/Grafana), authenticated API gateway (Nginx)
- [ ] **Phase 4** — Consumer-facing dashboard for product lookup/scan, IPFS integration for certificate documents

## Disclaimer

This is a proof-of-concept built for technical portfolio purposes, not an audited or officially certified production system by any halal certifying authority.

## License

MIT
