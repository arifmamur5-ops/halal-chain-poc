// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/HalalChainRegistry.sol";

contract HalalChainRegistryTest is Test {
    HalalChainRegistry registry;

    address admin = makeAddr("admin");
    address certifier = makeAddr("certifier");
    address certifier2 = makeAddr("certifier2"); // Tambah certifier ke-2 buat konsensus
    address producer = makeAddr("producer");
    address distributor = makeAddr("distributor");
    address retailer = makeAddr("retailer");
    address randomUser = makeAddr("random");

    function setUp() public {
        vm.prank(admin);
        registry = new HalalChainRegistry(admin);

        vm.startPrank(admin);
        registry.grantRole(registry.CERTIFIER_ROLE(), certifier);
        registry.grantRole(registry.CERTIFIER_ROLE(), certifier2); // Daftarkan role certifier ke-2
        registry.grantRole(registry.PRODUCER_ROLE(), producer);
        registry.grantRole(registry.DISTRIBUTOR_ROLE(), distributor);
        registry.grantRole(registry.RETAILER_ROLE(), retailer);
        vm.stopPrank();
    }

    // ---------- Registration ----------

    function test_RegisterProduct_Success() public {
        vm.prank(producer);
        uint256 id = registry.registerProduct("BATCH-001", "ipfs://QmMeta1");

        (, address prod, string memory batch, , , HalalChainRegistry.Status status, ) = registry.products(id);
        assertEq(prod, producer);
        assertEq(batch, "BATCH-001");
        assertEq(uint8(status), uint8(HalalChainRegistry.Status.Registered));
    }

    function test_RegisterProduct_RevertIfNotProducer() public {
        vm.prank(randomUser);
        vm.expectRevert(); 
        registry.registerProduct("BATCH-002", "ipfs://QmMeta2");
    }

    // ---------- Certification ----------

    function test_IssueCertificate_Success() public {
        vm.prank(producer);
        uint256 id = registry.registerProduct("BATCH-001", "ipfs://QmMeta1");

        vm.prank(certifier);
        registry.issueCertificate(id, "ipfs://QmCert1", 365);

        (, , , , , HalalChainRegistry.Status status, ) = registry.products(id);
        assertEq(uint8(status), uint8(HalalChainRegistry.Status.Certified));
    }

    function test_IssueCertificate_RevertIfNotCertifier() public {
        vm.prank(producer);
        uint256 id = registry.registerProduct("BATCH-001", "ipfs://QmMeta1");

        vm.prank(randomUser);
        vm.expectRevert();
        registry.issueCertificate(id, "ipfs://QmCert1", 365);
    }

    function test_IssueCertificate_RevertIfNotRegisteredStatus() public {
        vm.prank(producer);
        uint256 id = registry.registerProduct("BATCH-001", "ipfs://QmMeta1");

        vm.prank(certifier);
        registry.issueCertificate(id, "ipfs://QmCert1", 365);

        vm.prank(certifier);
        vm.expectRevert("Not eligible");
        registry.issueCertificate(id, "ipfs://QmCert2", 365);
    }

    // ---------- Revocation ----------

    function test_RevokeCertificate_MidCustodyChain() public {
        vm.prank(producer);
        uint256 id = registry.registerProduct("BATCH-001", "ipfs://QmMeta1");

        vm.prank(certifier);
        registry.issueCertificate(id, "ipfs://QmCert1", 365);

        vm.prank(producer);
        registry.transferCustody(id, distributor);

        vm.prank(certifier);
        registry.revokeCertificate(id, "Slaughter method non-compliant");

        (, , , , , HalalChainRegistry.Status status, ) = registry.products(id);
        assertEq(uint8(status), uint8(HalalChainRegistry.Status.Revoked));

        vm.prank(distributor);
        vm.expectRevert("Invalid status or certificate expired");
        registry.transferCustody(id, retailer);
    }

    function test_RevokeCertificate_RevertIfNotCertifier() public {
        vm.prank(producer);
        uint256 id = registry.registerProduct("BATCH-001", "ipfs://QmMeta1");

        vm.prank(certifier);
        registry.issueCertificate(id, "ipfs://QmCert1", 365);

        vm.prank(randomUser);
        vm.expectRevert();
        registry.revokeCertificate(id, "trying to sabotage");
    }

    // ---------- Custody transfer ----------

    function test_TransferCustody_RevertIfNotCurrentHolder() public {
        vm.prank(producer);
        uint256 id = registry.registerProduct("BATCH-001", "ipfs://QmMeta1");

        vm.prank(certifier);
        registry.issueCertificate(id, "ipfs://QmCert1", 365);

        vm.prank(distributor);
        vm.expectRevert("Not current holder");
        registry.transferCustody(id, retailer);
    }

    function test_TransferCustody_FullChain() public {
        vm.prank(producer);
        uint256 id = registry.registerProduct("BATCH-001", "ipfs://QmMeta1");

        vm.prank(certifier);
        registry.issueCertificate(id, "ipfs://QmCert1", 365);

        vm.prank(producer);
        registry.transferCustody(id, distributor);

        vm.prank(distributor);
        registry.transferCustody(id, retailer);

        assertEq(registry.custodyChain(id, 0), producer);
        assertEq(registry.custodyChain(id, 1), distributor);
        assertEq(registry.custodyChain(id, 2), retailer);
    }

    // ---------- Contamination flag ----------

    function test_FlagContamination_AnyoneCanReport() public {
        vm.prank(producer);
        uint256 id = registry.registerProduct("BATCH-001", "ipfs://QmMeta1");

        vm.prank(randomUser);
        registry.flagContamination(id, "Found mixed with non-halal cargo in transit");

        (, , , , , HalalChainRegistry.Status status, ) = registry.products(id);
        assertEq(uint8(status), uint8(HalalChainRegistry.Status.Flagged));
    }

    // ---------- Expired certificate ----------

    function test_ExpiredCertificate_StillMarkedCertified() public {
        vm.prank(producer);
        uint256 id = registry.registerProduct("BATCH-001", "ipfs://QmMeta1");

        vm.prank(certifier);
        registry.issueCertificate(id, "ipfs://QmCert1", 1); 

        vm.warp(block.timestamp + 2 days); 

        (, , , , , HalalChainRegistry.Status status, ) = registry.products(id);
        assertEq(uint8(status), uint8(HalalChainRegistry.Status.Certified));
    }

    // TES MODIFIKASI LO: Pastiin transfer ketolak kalau expired
    function test_TransferCustody_RevertIfCertificateExpired() public {
        vm.prank(producer);
        uint256 id = registry.registerProduct("BATCH-001", "ipfs://QmMeta1");

        vm.prank(certifier);
        registry.issueCertificate(id, "ipfs://QmCert1", 1); 

        vm.warp(block.timestamp + 2 days); 

        vm.prank(producer);
        vm.expectRevert("Invalid status or certificate expired");
        registry.transferCustody(id, distributor);
    }

    // ---------- WAJIB FASE 1 LANJUTAN (KONSENSUS & VIEW) ----------

    function test_MultiCertifier_AutoFinalize() public {
        vm.prank(producer);
        uint256 id = registry.registerProduct("BATCH-005", "ipfs://QmMeta5");

        vm.prank(certifier);
        registry.approveCertification(id, "ipfs://QmConsensusCert", 365);

        (, , , , , HalalChainRegistry.Status statusBefore, ) = registry.products(id);
        assertEq(uint8(statusBefore), uint8(HalalChainRegistry.Status.Registered));

        vm.prank(certifier2);
        registry.approveCertification(id, "ipfs://QmConsensusCert", 365);

        (, , , , , HalalChainRegistry.Status statusAfter, ) = registry.products(id);
        assertEq(uint8(statusAfter), uint8(HalalChainRegistry.Status.Certified));
    }

    function test_MultiCertifier_RevertIfApprovedTwice() public {
        vm.prank(producer);
        uint256 id = registry.registerProduct("BATCH-006", "ipfs://QmMeta6");

        vm.prank(certifier);
        registry.approveCertification(id, "ipfs://QmConsensusCert", 365);

        vm.prank(certifier);
        vm.expectRevert("Already approved");
        registry.approveCertification(id, "ipfs://QmConsensusCert", 365);
    }

    function test_MultiCertifier_RevertIfAlreadyFinalized() public {
        vm.prank(producer);
        uint256 id = registry.registerProduct("BATCH-007", "ipfs://QmMeta7");

        vm.prank(certifier);
        registry.approveCertification(id, "ipfs://QmConsensusCert", 365);
        vm.prank(certifier2);
        registry.approveCertification(id, "ipfs://QmConsensusCert", 365);

        vm.prank(certifier);
        vm.expectRevert("Already finalized");
        registry.approveCertification(id, "ipfs://QmConsensusCert", 365);
    }

    function test_GetProductFullHistory_ConsumerView() public {
        vm.prank(producer);
        uint256 id = registry.registerProduct("BATCH-008", "ipfs://QmMeta8");

        vm.prank(certifier);
        registry.issueCertificate(id, "ipfs://QmCert8", 5);

        (
            HalalChainRegistry.Product memory product,
            HalalChainRegistry.Certificate memory certificate,
            address[] memory custody,
            bool certValid
        ) = registry.getProductFullHistory(id);

        assertEq(product.batchNumber, "BATCH-008");
        assertEq(certificate.ipfsHash, "ipfs://QmCert8");
        assertEq(custody[0], producer);
        assertTrue(certValid); 
    }
}
