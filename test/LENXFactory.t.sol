// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../contracts/LENXFactory.sol";
import "../contracts/tokens/LENXERC20.sol";
import "../contracts/LENXPair.sol";
import "./mocks/ERC20Mintable.sol";

contract LENXFactory_Test is Test {
    address feeSetter = address(69);
    LENXFactory factory;
    LENXERC20 lenx;

    ERC20Mintable token0;
    ERC20Mintable token1;
    ERC20Mintable token2;
    ERC20Mintable token3;

    function setUp() public {
        lenx = new LENXERC20();
        factory = new LENXFactory(feeSetter, address(lenx));

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

        LENXPair pair = LENXPair(pairAddress);

        assertEq(pair.token0(), address(token0));
        assertEq(pair.token1(), address(token1));
    }

    function test_CreatePairZeroAddress() public {
        vm.expectRevert("LENX: ZERO_ADDRESS");
        factory.createPair(address(0), address(token0));

        vm.expectRevert("LENX: ZERO_ADDRESS");
        factory.createPair(address(token1), address(0));
    }

    function test_CreatePairPairExists() public {
        factory.createPair(address(token1), address(token0));

        vm.expectRevert("LENX: PAIR_EXISTS");
        factory.createPair(address(token1), address(token0));
    }

    function test_CreatePairIdenticalTokens() public {
        vm.expectRevert("LENX: IDENTICAL_ADDRESSES");
        factory.createPair(address(token0), address(token0));
    }
}
