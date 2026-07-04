// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {HalalChainRegistry} from "../src/HalalChainRegistry.sol";

contract DeployHalalChain is Script {
    function run() external {
        // Akun #0 Anvil sebagai Deployer / Admin
        uint256 deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        address deployerAddress = vm.addr(deployerPrivateKey);

        // Akun #1 Anvil yang mau kita jadikan PRODUCER_ROLE
        address producerAddress = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;

        vm.startBroadcast(deployerPrivateKey);

        HalalChainRegistry registry = new HalalChainRegistry(deployerAddress);

        // Ambil bytes32 PRODUCER_ROLE langsung dari variabel publik kontrak lo
        bytes32 producerRole = registry.PRODUCER_ROLE();

        // Kasih akses role ke akun producer
        registry.grantRole(producerRole, producerAddress);

        vm.stopBroadcast();
    }
}
