// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract HalalChainRegistry is AccessControl {
    bytes32 public constant CERTIFIER_ROLE  = keccak256("CERTIFIER_ROLE");  // e.g. MUI/JAKIM-equivalent
    bytes32 public constant PRODUCER_ROLE   = keccak256("PRODUCER_ROLE");   // RPH/peternak
    bytes32 public constant DISTRIBUTOR_ROLE = keccak256("DISTRIBUTOR_ROLE");
    bytes32 public constant RETAILER_ROLE   = keccak256("RETAILER_ROLE");

    enum Status { Registered, Certified, InTransit, Delivered, Revoked, Flagged }

    struct Product {
        uint256 id;
        address producer;
        string batchNumber;       // internal batch code
        string metadataURI;       // IPFS hash: species, slaughter method, location
        bytes32 certificateHash;  // hash of the halal cert document (also on IPFS)
        Status status;
        uint256 registeredAt;
    }

    struct Certificate {
        address issuer;           // certifier address
        string ipfsHash;
        uint256 issuedAt;
        uint256 expiresAt;
        bool revoked;
    }

    // --- TAMBAHAN STRUCT & STATE FASE 1 LANJUTAN ---
    struct CertificationRequest {
        uint256 requiredApprovals;
        uint256 currentApprovals;
        mapping(address => bool) hasApproved;
        bool finalized;
    }

    mapping(uint256 => CertificationRequest) public certRequests; // productId => request
    uint256 public constant DEFAULT_REQUIRED_APPROVALS = 2;

    mapping(uint256 => Product) public products;
    mapping(uint256 => Certificate) public certificates; // productId => cert
    mapping(uint256 => address[]) public custodyChain;   // productId => history of holders
    uint256 public nextProductId;

    event ProductRegistered(uint256 indexed id, address indexed producer, string batchNumber);
    event CertificateIssued(uint256 indexed productId, address indexed issuer, string ipfsHash);
    event CertificateRevoked(uint256 indexed productId, address indexed issuer, string reason);
    event CustodyTransferred(uint256 indexed productId, address indexed from, address indexed to);
    event CrossContaminationFlagged(uint256 indexed productId, address indexed reporter, string details);
    event CertificationApproved(uint256 indexed productId, address indexed approver, uint256 currentApprovals, uint256 required);

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    // FIX CORETAN LO: Fungsi helper buat ngecek validitas sertifikat secara real-time
    function isCertificateValid(uint256 productId) public view returns (bool) {
        Certificate memory cert = certificates[productId];
        if (cert.revoked) return false;
        if (cert.expiresAt == 0) return false; // Belum di-sertifikasi atau data kosong
        return block.timestamp <= cert.expiresAt;
    }

    function registerProduct(string calldata batchNumber, string calldata metadataURI)
        external onlyRole(PRODUCER_ROLE) returns (uint256)
    {
        uint256 id = nextProductId++;
        products[id] = Product(id, msg.sender, batchNumber, metadataURI, bytes32(0), Status.Registered, block.timestamp);
        custodyChain[id].push(msg.sender);
        emit ProductRegistered(id, msg.sender, batchNumber);
        return id;
    }

    function issueCertificate(uint256 productId, string calldata ipfsHash, uint256 validDays)
        external onlyRole(CERTIFIER_ROLE)
    {
        require(products[productId].status == Status.Registered, "Not eligible");
        certificates[productId] = Certificate(msg.sender, ipfsHash, block.timestamp, block.timestamp + validDays * 1 days, false);
        products[productId].status = Status.Certified;
        products[productId].certificateHash = keccak256(bytes(ipfsHash));
        emit CertificateIssued(productId, msg.sender, ipfsHash);
    }

    function revokeCertificate(uint256 productId, string calldata reason)
        external onlyRole(CERTIFIER_ROLE)
    {
        certificates[productId].revoked = true;
        products[productId].status = Status.Revoked;
        emit CertificateRevoked(productId, msg.sender, reason);
    }

    function transferCustody(uint256 productId, address to) external {
        require(custodyChain[productId][custodyChain[productId].length - 1] == msg.sender, "Not current holder");
        
        // FIX CORETAN LO: Cek status DAN pastikan sertifikat belum expired secara real-time!
        require(
            (products[productId].status == Status.Certified && isCertificateValid(productId)) || 
            products[productId].status == Status.InTransit, 
            "Invalid status or certificate expired"
        );
        
        custodyChain[productId].push(to);
        products[productId].status = Status.InTransit;
        emit CustodyTransferred(productId, msg.sender, to);
    }

    function flagContamination(uint256 productId, string calldata details) external {
        products[productId].status = Status.Flagged;
        emit CrossContaminationFlagged(productId, msg.sender, details);
    }

    // --- TAMBAHAN FUNGSI FASE 1 LANJUTAN ---
    function approveCertification(uint256 productId, string calldata ipfsHash, uint256 validDays)
        external onlyRole(CERTIFIER_ROLE)
    {
        // Pindahkan pengecekan finalisasi ke paling atas biar sesuai ekspektasi unit test
        CertificationRequest storage req = certRequests[productId];
        require(!req.finalized, "Already finalized");
        
        // Baru cek status registrasi produknya
        require(products[productId].status == Status.Registered, "Not eligible");
        require(!req.hasApproved[msg.sender], "Already approved");

        if (req.requiredApprovals == 0) {
            req.requiredApprovals = DEFAULT_REQUIRED_APPROVALS;
        }

        req.hasApproved[msg.sender] = true;
        req.currentApprovals++;

        emit CertificationApproved(productId, msg.sender, req.currentApprovals, req.requiredApprovals);

        if (req.currentApprovals >= req.requiredApprovals) {
            req.finalized = true;
            certificates[productId] = Certificate(msg.sender, ipfsHash, block.timestamp, block.timestamp + validDays * 1 days, false);
            products[productId].status = Status.Certified;
            products[productId].certificateHash = keccak256(bytes(ipfsHash));
            emit CertificateIssued(productId, msg.sender, ipfsHash);
        }
    }

    // Consumer-facing: 1 call buat full traceability + integrasi helper real-time lo!
    function getProductFullHistory(uint256 productId) external view returns (
        Product memory product,
        Certificate memory certificate,
        address[] memory custody,
        bool certValid
    ) {
        product = products[productId];
        certificate = certificates[productId];
        custody = custodyChain[productId];
        certValid = isCertificateValid(productId); // Langsung manggil fungsi helper lo
    }
}
