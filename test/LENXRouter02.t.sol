// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../contracts/LENXFactory.sol";
import "../contracts/LENXPair.sol";
import "../contracts/LENXRouter02.sol";
import "./mocks/ERC20Mintable.sol";

contract LENXRouter02_Test is Test {
    address feeSetter = address(69);
    LENXERC20 lenx;
    ERC20Mintable WCHZ;

    LENXRouter02 router;
    LENXFactory factory;

    ERC20Mintable tokenA;
    ERC20Mintable tokenB;
    ERC20Mintable tokenC;

    function setUp() public {
        lenx = new LENXERC20();
        WCHZ = new ERC20Mintable("Wrapped CHZ", "WCHZ");

        factory = new LENXFactory(feeSetter, address(lenx));
        router = new LENXRouter02(address(factory), address(WCHZ));

        tokenA = new ERC20Mintable("Token A", "TKNA");
        tokenB = new ERC20Mintable("Token B", "TKNB");
        tokenC = new ERC20Mintable("Token C", "TKNC");

        tokenA.mint(20 ether, address(this));
        tokenB.mint(20 ether, address(this));
        tokenC.mint(20 ether, address(this));
    }

    function encodeError(string memory error) internal pure returns (bytes memory encoded) {
        encoded = abi.encodeWithSignature(error);
    }

    function test_AddLiquidityCreatesPair() public {
        tokenA.approve(address(router), 1 ether);
        tokenB.approve(address(router), 1 ether);

        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            1 ether,
            1 ether,
            1 ether,
            1 ether,
            address(this),
            block.timestamp
        );

        address pairAddress = factory.getPair(address(tokenA), address(tokenB));
        assertEq(pairAddress, 0xbDB8083deBF23F108CCA813BFA57fB192Ecd8E63);
    }

    function test_AddLiquidityNoPair() public {
        tokenA.approve(address(router), 1 ether);
        tokenB.approve(address(router), 1 ether);

        (uint256 amountA, uint256 amountB, uint256 liquidity) = router.addLiquidity(
            address(tokenA),
            address(tokenB),
            1 ether,
            1 ether,
            1 ether,
            1 ether,
            address(this),
            block.timestamp
        );

        assertEq(amountA, 1 ether);
        assertEq(amountB, 1 ether);
        assertEq(liquidity, 1 ether - 1000);

        address pairAddress = factory.getPair(address(tokenA), address(tokenB));

        assertEq(tokenA.balanceOf(pairAddress), 1 ether);
        assertEq(tokenB.balanceOf(pairAddress), 1 ether);

        LENXPair pair = LENXPair(pairAddress);

        assertEq(pair.token0(), address(tokenB));
        assertEq(pair.token1(), address(tokenA));
        assertEq(pair.totalSupply(), 1 ether);
        assertEq(pair.balanceOf(address(this)), 1 ether - 1000);

        assertEq(tokenA.balanceOf(address(this)), 19 ether);
        assertEq(tokenB.balanceOf(address(this)), 19 ether);
    }

    function test_AddLiquidityAmountBOptimalIsOk() public {
        address pairAddress = factory.createPair(address(tokenA), address(tokenB));

        LENXPair pair = LENXPair(pairAddress);

        assertEq(pair.token0(), address(tokenB));
        assertEq(pair.token1(), address(tokenA));

        tokenA.transfer(pairAddress, 1 ether);
        tokenB.transfer(pairAddress, 2 ether);
        pair.mint(address(this));

        tokenA.approve(address(router), 1 ether);
        tokenB.approve(address(router), 2 ether);

        (uint256 amountA, uint256 amountB, uint256 liquidity) = router.addLiquidity(
            address(tokenA),
            address(tokenB),
            1 ether,
            2 ether,
            1 ether,
            1.9 ether,
            address(this),
            block.timestamp
        );

        assertEq(amountA, 1 ether);
        assertEq(amountB, 2 ether);
        assertEq(liquidity, 1414213562373095048);
    }

    function test_AddLiquidityAmountBOptimalIsTooLow() public {
        address pairAddress = factory.createPair(address(tokenA), address(tokenB));

        LENXPair pair = LENXPair(pairAddress);
        assertEq(pair.token0(), address(tokenB));
        assertEq(pair.token1(), address(tokenA));

        tokenA.transfer(pairAddress, 5 ether);
        tokenB.transfer(pairAddress, 10 ether);
        pair.mint(address(this));

        tokenA.approve(address(router), 1 ether);
        tokenB.approve(address(router), 2 ether);

        vm.expectRevert("LENXRouter: INSUFFICIENT_B_AMOUNT");
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            1 ether,
            2 ether,
            1 ether,
            2.1 ether,
            address(this),
            block.timestamp
        );
    }

    function test_AddLiquidityAmountBOptimalTooHighAmountATooLow() public {
        address pairAddress = factory.createPair(address(tokenA), address(tokenB));
        LENXPair pair = LENXPair(pairAddress);

        assertEq(pair.token0(), address(tokenB));
        assertEq(pair.token1(), address(tokenA));

        tokenA.transfer(pairAddress, 10 ether);
        tokenB.transfer(pairAddress, 5 ether);
        pair.mint(address(this));

        tokenA.approve(address(router), 2 ether);
        tokenB.approve(address(router), 1 ether);

        vm.expectRevert("LENXRouter: INSUFFICIENT_A_AMOUNT");
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            2 ether,
            0.9 ether,
            2 ether,
            1 ether,
            address(this),
            block.timestamp
        );
    }

    function test_AddLiquidityAmountBOptimalIsTooHighAmountAOk() public {
        address pairAddress = factory.createPair(address(tokenA), address(tokenB));
        LENXPair pair = LENXPair(pairAddress);

        assertEq(pair.token0(), address(tokenB));
        assertEq(pair.token1(), address(tokenA));

        tokenA.transfer(pairAddress, 10 ether);
        tokenB.transfer(pairAddress, 5 ether);
        pair.mint(address(this));

        tokenA.approve(address(router), 2 ether);
        tokenB.approve(address(router), 1 ether);

        (uint256 amountA, uint256 amountB, uint256 liquidity) = router.addLiquidity(
            address(tokenA),
            address(tokenB),
            2 ether,
            0.9 ether,
            1.7 ether,
            1 ether,
            address(this),
            block.timestamp
        );
        assertEq(amountA, 1.8 ether);
        assertEq(amountB, 0.9 ether);
        assertEq(liquidity, 1272792206135785543);
    }

    function test_RemoveLiquidity() public {
        tokenA.approve(address(router), 1 ether);
        tokenB.approve(address(router), 1 ether);

        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            1 ether,
            1 ether,
            1 ether,
            1 ether,
            address(this),
            block.timestamp
        );

        address pairAddress = factory.getPair(address(tokenA), address(tokenB));
        LENXPair pair = LENXPair(pairAddress);
        uint256 liquidity = pair.balanceOf(address(this));

        pair.approve(address(router), liquidity);

        router.removeLiquidity(
            address(tokenA),
            address(tokenB),
            liquidity,
            1 ether - 1000,
            1 ether - 1000,
            address(this),
            block.timestamp
        );

        (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
        assertEq(reserve0, 1000);
        assertEq(reserve1, 1000);
        assertEq(pair.balanceOf(address(this)), 0);
        assertEq(pair.totalSupply(), 1000);
        assertEq(tokenA.balanceOf(address(this)), 20 ether - 1000);
        assertEq(tokenB.balanceOf(address(this)), 20 ether - 1000);
    }

    function test_RemoveLiquidityPartially() public {
        tokenA.approve(address(router), 1 ether);
        tokenB.approve(address(router), 1 ether);

        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            1 ether,
            1 ether,
            1 ether,
            1 ether,
            address(this),
            block.timestamp
        );

        address pairAddress = factory.getPair(address(tokenA), address(tokenB));
        LENXPair pair = LENXPair(pairAddress);
        uint256 liquidity = pair.balanceOf(address(this));

        liquidity = (liquidity * 3) / 10;
        pair.approve(address(router), liquidity);

        router.removeLiquidity(
            address(tokenA),
            address(tokenB),
            liquidity,
            0.3 ether - 300,
            0.3 ether - 300,
            address(this),
            block.timestamp
        );

        (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
        assertEq(reserve0, 0.7 ether + 300);
        assertEq(reserve1, 0.7 ether + 300);
        assertEq(pair.balanceOf(address(this)), 0.7 ether - 700);
        assertEq(pair.totalSupply(), 0.7 ether + 300);
        assertEq(tokenA.balanceOf(address(this)), 20 ether - 0.7 ether - 300);
        assertEq(tokenB.balanceOf(address(this)), 20 ether - 0.7 ether - 300);
    }

    function test_RemoveLiquidityInsufficientAAmount() public {
        tokenA.approve(address(router), 1 ether);
        tokenB.approve(address(router), 1 ether);

        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            1 ether,
            1 ether,
            1 ether,
            1 ether,
            address(this),
            block.timestamp
        );

        address pairAddress = factory.getPair(address(tokenA), address(tokenB));
        LENXPair pair = LENXPair(pairAddress);
        uint256 liquidity = pair.balanceOf(address(this));

        pair.approve(address(router), liquidity);

        vm.expectRevert("LENXRouter: INSUFFICIENT_A_AMOUNT");
        router.removeLiquidity(
            address(tokenA),
            address(tokenB),
            liquidity,
            1 ether,
            1 ether - 1000,
            address(this),
            block.timestamp
        );
    }

    function test_RemoveLiquidityInsufficientBAmount() public {
        tokenA.approve(address(router), 1 ether);
        tokenB.approve(address(router), 1 ether);

        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            1 ether,
            1 ether,
            1 ether,
            1 ether,
            address(this),
            block.timestamp
        );

        address pairAddress = factory.getPair(address(tokenA), address(tokenB));
        LENXPair pair = LENXPair(pairAddress);
        uint256 liquidity = pair.balanceOf(address(this));

        pair.approve(address(router), liquidity);

        vm.expectRevert("LENXRouter: INSUFFICIENT_B_AMOUNT");
        router.removeLiquidity(
            address(tokenA),
            address(tokenB),
            liquidity,
            1 ether - 1000,
            1 ether,
            address(this),
            block.timestamp
        );
    }

    function test_SwapExactTokensForTokens() public {
        tokenA.approve(address(router), 1 ether);
        tokenB.approve(address(router), 2 ether);
        tokenC.approve(address(router), 1 ether);

        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            1 ether,
            1 ether,
            1 ether,
            1 ether,
            address(this),
            block.timestamp
        );

        router.addLiquidity(
            address(tokenB),
            address(tokenC),
            1 ether,
            1 ether,
            1 ether,
            1 ether,
            address(this),
            block.timestamp
        );

        address[] memory path = new address[](3);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        path[2] = address(tokenC);

        tokenA.approve(address(router), 0.3 ether);
        router.swapExactTokensForTokens(0.3 ether, 0.1 ether, path, address(this), block.timestamp);

        // Swap 0.3 TKNA for ~0.186 TKNB
        assertEq(tokenA.balanceOf(address(this)), 20 ether - 1 ether - 0.3 ether);
        assertEq(tokenB.balanceOf(address(this)), 20 ether - 2 ether);
        assertEq(tokenC.balanceOf(address(this)), 20 ether - 1 ether + 0.186691414219734305 ether);
    }

    function test_SwapTokensForExactTokens() public {
        tokenA.approve(address(router), 1 ether);
        tokenB.approve(address(router), 2 ether);
        tokenC.approve(address(router), 1 ether);

        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            1 ether,
            1 ether,
            1 ether,
            1 ether,
            address(this),
            block.timestamp
        );

        router.addLiquidity(
            address(tokenB),
            address(tokenC),
            1 ether,
            1 ether,
            1 ether,
            1 ether,
            address(this),
            block.timestamp
        );

        address[] memory path = new address[](3);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        path[2] = address(tokenC);

        tokenA.approve(address(router), 0.3 ether);
        router.swapTokensForExactTokens(0.186691414219734305 ether, 0.3 ether, path, address(this), block.timestamp);

        // Swap 0.3 TKNA for ~0.186 TKNB
        assertEq(tokenA.balanceOf(address(this)), 20 ether - 1 ether - 0.3 ether);
        assertEq(tokenB.balanceOf(address(this)), 20 ether - 2 ether);
        assertEq(tokenC.balanceOf(address(this)), 20 ether - 1 ether + 0.186691414219734305 ether);
    }
}
