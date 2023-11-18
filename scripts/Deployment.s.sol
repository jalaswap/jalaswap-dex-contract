// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Scripting tool
import {Script} from "forge-std/Script.sol";

// Core contracts
import {LENXFactory} from "../contracts/LENXFactory.sol";
import {LENXRouter02} from "../contracts/LENXRouter02.sol";

import {console} from "forge-std/console.sol";

contract Deployment is Script {
    error ChainIdInvalid(uint256 chainId);

    function run() external {
        uint256 chainId = block.chainid;
        uint256 deployerPrivateKey;
        address feeToSetter;
        address WCHZ;

        if (chainId == 88888) {
            deployerPrivateKey = vm.envUint("MAINNET_KEY");
            feeToSetter = 0x649f37caB0f677dd157E2074247194603FDB33d3;
            WCHZ = 0x677F7e16C7Dd57be1D4C8aD1244883214953DC47;
        } else if (chainId == 88882) {
            deployerPrivateKey = vm.envUint("TESTNET_KEY");
            feeToSetter = 0x649f37caB0f677dd157E2074247194603FDB33d3;
            WCHZ = 0x678c34581db0a7808d0aC669d7025f1408C9a3C6;
        } else {
            revert ChainIdInvalid(chainId);
        }

        vm.startBroadcast(deployerPrivateKey);

        LENXFactory factory = new LENXFactory(feeToSetter);
        LENXRouter02 router = new LENXRouter02(address(factory), WCHZ);

        console.log("FACTORY: ", address(factory));
        console.log("ROUTER: ", address(router));

        vm.stopBroadcast();
    }
}
