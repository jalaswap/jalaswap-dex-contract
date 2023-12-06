// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../contracts/JALAFactory.sol";
import "../contracts/tokens/JALAERC20.sol";
import "../contracts/JALAPair.sol";
import "../contracts/interfaces/IJALAFactory.sol";
import "../contracts/mocks/ERC20Mintable.sol";

contract JALAFactory_Test is Test {
    address feeSetter = address(69);
    JALAFactory factory;

    ERC20Mintable token0;
    ERC20Mintable token1;
    ERC20Mintable token2;
    ERC20Mintable token3;

    function setUp() public {
        factory = new JALAFactory(feeSetter);

        token0 = new ERC20Mintable("Token A", "TKNA");
        token1 = new ERC20Mintable("Token B", "TKNB");
        token2 = new ERC20Mintable("Token C", "TKNC");
        token3 = new ERC20Mintable("Token D", "TKND");
    }

    function encodeError(string memory error) internal pure returns (bytes memory encoded) {
        encoded = abi.encodeWithSignature(error);
    }

    function test_CreatePair() public {
        address pairAddress = factory.createPair(address(token1), address(token0));

        JALAPair pair = JALAPair(pairAddress);

        assertEq(pair.token0(), address(token0));
        assertEq(pair.token1(), address(token1));
    }

    function test_CreatePairZeroAddress() public {
        vm.expectRevert(IJALAFactory.ZeroAddress.selector);
        factory.createPair(address(0), address(token0));

        vm.expectRevert(IJALAFactory.ZeroAddress.selector);
        factory.createPair(address(token1), address(0));
    }

    function test_CreatePairPairExists() public {
        factory.createPair(address(token1), address(token0));

        vm.expectRevert(IJALAFactory.PairExists.selector);
        factory.createPair(address(token1), address(token0));
    }

    function test_CreatePairIdenticalTokens() public {
        vm.expectRevert(IJALAFactory.IdenticalAddresses.selector);
        factory.createPair(address(token0), address(token0));
    }
}
