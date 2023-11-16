// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "./libraries/LENXLibrary.sol";
import "./libraries/TransferHelper.sol";
import "./interfaces/ILENXFactory.sol";
import "./interfaces/IERC20.sol";

import "./interfaces/ILENXRouter02.sol";
import "./interfaces/IWCHZ.sol";
import {console} from "forge-std/console.sol";

contract LENXRouter02 is ILENXRouter02 {
    address public immutable override factory;
    address public immutable override WCHZ;

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "LENXRouter: EXPIRED");
        _;
    }

    constructor(address _factory, address _WCHZ) {
        factory = _factory;
        WCHZ = _WCHZ;

        // approve LENX to factory for createFee
        address feeToken = ILENXFactory(factory).lenx();
        TransferHelper.safeApprove(feeToken, factory, type(uint).max);
    }

    receive() external payable {
        assert(msg.sender == WCHZ); // only accept CHZ via fallback from the WCHZ contract
    }

    // **** ADD LIQUIDITY ****
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) internal virtual returns (uint256 amountA, uint256 amountB) {
        // create the pair if it doesn't exist yet
        if (ILENXFactory(factory).getPair(tokenA, tokenB) == address(0)) {
            uint createFee = ILENXFactory(factory).createFee();
            if (createFee > 0) {
                address feeToken = ILENXFactory(factory).lenx();
                TransferHelper.safeTransferFrom(feeToken, msg.sender, address(this), createFee);
            }
            ILENXFactory(factory).createPair(tokenA, tokenB);
        }
        (uint256 reserveA, uint256 reserveB) = LENXLibrary.getReserves(factory, tokenA, tokenB);
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint256 amountBOptimal = LENXLibrary.quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, "LENXRouter: INSUFFICIENT_B_AMOUNT");
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = LENXLibrary.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, "LENXRouter: INSUFFICIENT_A_AMOUNT");
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        (amountA, amountB) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
        address pair = LENXLibrary.pairFor(factory, tokenA, tokenB);
        TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
        TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);
        liquidity = ILENXPair(pair).mint(to);
    }

    function addLiquidityCHZ(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountCHZMin,
        address to,
        uint256 deadline
    )
        external
        payable
        virtual
        override
        ensure(deadline)
        returns (uint256 amountToken, uint256 amountCHZ, uint256 liquidity)
    {
        (amountToken, amountCHZ) = _addLiquidity(
            token,
            WCHZ,
            amountTokenDesired,
            msg.value,
            amountTokenMin,
            amountCHZMin
        );
        address pair = LENXLibrary.pairFor(factory, token, WCHZ);
        TransferHelper.safeTransferFrom(token, msg.sender, pair, amountToken);
        IWCHZ(WCHZ).deposit{value: amountCHZ}();
        assert(IWCHZ(WCHZ).transfer(pair, amountCHZ));
        liquidity = ILENXPair(pair).mint(to);
        // refund dust eth, if any
        if (msg.value > amountCHZ) TransferHelper.safeTransferCHZ(msg.sender, msg.value - amountCHZ);
    }

    // **** REMOVE LIQUIDITY ****
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) public virtual override ensure(deadline) returns (uint256 amountA, uint256 amountB) {
        address pair = LENXLibrary.pairFor(factory, tokenA, tokenB);
        ILENXPair(pair).transferFrom(msg.sender, pair, liquidity); // send liquidity to pair
        (uint256 amount0, uint256 amount1) = ILENXPair(pair).burn(to);
        (address token0, ) = LENXLibrary.sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
        require(amountA >= amountAMin, "LENXRouter: INSUFFICIENT_A_AMOUNT");
        require(amountB >= amountBMin, "LENXRouter: INSUFFICIENT_B_AMOUNT");
    }

    function removeLiquidityCHZ(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountCHZMin,
        address to,
        uint256 deadline
    ) public virtual override ensure(deadline) returns (uint256 amountToken, uint256 amountCHZ) {
        (amountToken, amountCHZ) = removeLiquidity(
            token,
            WCHZ,
            liquidity,
            amountTokenMin,
            amountCHZMin,
            address(this),
            deadline
        );
        TransferHelper.safeTransfer(token, to, amountToken);
        IWCHZ(WCHZ).withdraw(amountCHZ);
        TransferHelper.safeTransferCHZ(to, amountCHZ);
    }

    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual override returns (uint256 amountA, uint256 amountB) {
        address pair = LENXLibrary.pairFor(factory, tokenA, tokenB);
        uint256 value = approveMax ? type(uint).max : liquidity;
        ILENXPair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountA, amountB) = removeLiquidity(tokenA, tokenB, liquidity, amountAMin, amountBMin, to, deadline);
    }

    function removeLiquidityCHZWithPermit(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountCHZMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual override returns (uint256 amountToken, uint256 amountCHZ) {
        address pair = LENXLibrary.pairFor(factory, token, WCHZ);
        uint256 value = approveMax ? type(uint).max : liquidity;
        ILENXPair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountToken, amountCHZ) = removeLiquidityCHZ(token, liquidity, amountTokenMin, amountCHZMin, to, deadline);
    }

    // **** REMOVE LIQUIDITY (supporting fee-on-transfer tokens) ****
    function removeLiquidityCHZSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountCHZMin,
        address to,
        uint256 deadline
    ) public virtual override ensure(deadline) returns (uint256 amountCHZ) {
        (, amountCHZ) = removeLiquidity(token, WCHZ, liquidity, amountTokenMin, amountCHZMin, address(this), deadline);
        TransferHelper.safeTransfer(token, to, IERC20(token).balanceOf(address(this)));
        IWCHZ(WCHZ).withdraw(amountCHZ);
        TransferHelper.safeTransferCHZ(to, amountCHZ);
    }

    function removeLiquidityCHZWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountCHZMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual override returns (uint256 amountCHZ) {
        address pair = LENXLibrary.pairFor(factory, token, WCHZ);
        uint256 value = approveMax ? type(uint).max : liquidity;
        ILENXPair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        amountCHZ = removeLiquidityCHZSupportingFeeOnTransferTokens(
            token,
            liquidity,
            amountTokenMin,
            amountCHZMin,
            to,
            deadline
        );
    }

    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    function _swap(uint256[] memory amounts, address[] memory path, address _to) internal virtual {
        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0, ) = LENXLibrary.sortTokens(input, output);
            uint256 amountOut = amounts[i + 1];
            (uint256 amount0Out, uint256 amount1Out) = input == token0
                ? (uint256(0), amountOut)
                : (amountOut, uint256(0));
            address to = i < path.length - 2 ? LENXLibrary.pairFor(factory, output, path[i + 2]) : _to;
            ILENXPair(LENXLibrary.pairFor(factory, input, output)).swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) returns (uint256[] memory amounts) {
        amounts = LENXLibrary.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "LENXRouter: INSUFFICIENT_OUTPUT_AMOUNT");
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            LENXLibrary.pairFor(factory, path[0], path[1]),
            amounts[0]
        );
        _swap(amounts, path, to);
    }

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) returns (uint256[] memory amounts) {
        amounts = LENXLibrary.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, "LENXRouter: EXCESSIVE_INPUT_AMOUNT");
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            LENXLibrary.pairFor(factory, path[0], path[1]),
            amounts[0]
        );
        _swap(amounts, path, to);
    }

    function swapExactCHZForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable virtual override ensure(deadline) returns (uint256[] memory amounts) {
        require(path[0] == WCHZ, "LENXRouter: INVALID_PATH");
        amounts = LENXLibrary.getAmountsOut(factory, msg.value, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "LENXRouter: INSUFFICIENT_OUTPUT_AMOUNT");
        IWCHZ(WCHZ).deposit{value: amounts[0]}();
        assert(IWCHZ(WCHZ).transfer(LENXLibrary.pairFor(factory, path[0], path[1]), amounts[0]));
        _swap(amounts, path, to);
    }

    function swapTokensForExactCHZ(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) returns (uint256[] memory amounts) {
        require(path[path.length - 1] == WCHZ, "LENXRouter: INVALID_PATH");
        amounts = LENXLibrary.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, "LENXRouter: EXCESSIVE_INPUT_AMOUNT");
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            LENXLibrary.pairFor(factory, path[0], path[1]),
            amounts[0]
        );
        _swap(amounts, path, address(this));
        IWCHZ(WCHZ).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferCHZ(to, amounts[amounts.length - 1]);
    }

    function swapExactTokensForCHZ(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) returns (uint256[] memory amounts) {
        require(path[path.length - 1] == WCHZ, "LENXRouter: INVALID_PATH");
        amounts = LENXLibrary.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "LENXRouter: INSUFFICIENT_OUTPUT_AMOUNT");
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            LENXLibrary.pairFor(factory, path[0], path[1]),
            amounts[0]
        );
        _swap(amounts, path, address(this));
        IWCHZ(WCHZ).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferCHZ(to, amounts[amounts.length - 1]);
    }

    function swapCHZForExactTokens(
        uint256 amountOut,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable virtual override ensure(deadline) returns (uint256[] memory amounts) {
        require(path[0] == WCHZ, "LENXRouter: INVALID_PATH");
        amounts = LENXLibrary.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= msg.value, "LENXRouter: EXCESSIVE_INPUT_AMOUNT");
        IWCHZ(WCHZ).deposit{value: amounts[0]}();
        assert(IWCHZ(WCHZ).transfer(LENXLibrary.pairFor(factory, path[0], path[1]), amounts[0]));
        _swap(amounts, path, to);
        // refund dust eth, if any
        if (msg.value > amounts[0]) TransferHelper.safeTransferCHZ(msg.sender, msg.value - amounts[0]);
    }

    // **** SWAP (supporting fee-on-transfer tokens) ****
    // requires the initial amount to have already been sent to the first pair
    function _swapSupportingFeeOnTransferTokens(address[] memory path, address _to) internal virtual {
        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0, ) = LENXLibrary.sortTokens(input, output);
            ILENXPair pair = ILENXPair(LENXLibrary.pairFor(factory, input, output));
            uint256 amountInput;
            uint256 amountOutput;
            {
                // scope to avoid stack too deep errors
                (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
                (uint256 reserveInput, uint256 reserveOutput) = input == token0
                    ? (reserve0, reserve1)
                    : (reserve1, reserve0);
                amountInput = IERC20(input).balanceOf(address(pair)) - reserveInput;
                amountOutput = LENXLibrary.getAmountOut(amountInput, reserveInput, reserveOutput);
            }
            (uint256 amount0Out, uint256 amount1Out) = input == token0
                ? (uint256(0), amountOutput)
                : (amountOutput, uint256(0));
            address to = i < path.length - 2 ? LENXLibrary.pairFor(factory, output, path[i + 2]) : _to;
            pair.swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) {
        TransferHelper.safeTransferFrom(path[0], msg.sender, LENXLibrary.pairFor(factory, path[0], path[1]), amountIn);
        uint256 balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
        require(
            IERC20(path[path.length - 1]).balanceOf(to) - balanceBefore >= amountOutMin,
            "LENXRouter: INSUFFICIENT_OUTPUT_AMOUNT"
        );
    }

    function swapExactCHZForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable virtual override ensure(deadline) {
        require(path[0] == WCHZ, "LENXRouter: INVALID_PATH");
        uint256 amountIn = msg.value;
        IWCHZ(WCHZ).deposit{value: amountIn}();
        assert(IWCHZ(WCHZ).transfer(LENXLibrary.pairFor(factory, path[0], path[1]), amountIn));
        uint256 balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
        require(
            IERC20(path[path.length - 1]).balanceOf(to) - balanceBefore >= amountOutMin,
            "LENXRouter: INSUFFICIENT_OUTPUT_AMOUNT"
        );
    }

    function swapExactTokensForCHZSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) {
        require(path[path.length - 1] == WCHZ, "LENXRouter: INVALID_PATH");
        TransferHelper.safeTransferFrom(path[0], msg.sender, LENXLibrary.pairFor(factory, path[0], path[1]), amountIn);
        _swapSupportingFeeOnTransferTokens(path, address(this));
        uint256 amountOut = IERC20(WCHZ).balanceOf(address(this));
        require(amountOut >= amountOutMin, "LENXRouter: INSUFFICIENT_OUTPUT_AMOUNT");
        IWCHZ(WCHZ).withdraw(amountOut);
        TransferHelper.safeTransferCHZ(to, amountOut);
    }

    // **** LIBRARY FUNCTIONS ****
    function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) public pure virtual override returns (uint256 amountB) {
        return LENXLibrary.quote(amountA, reserveA, reserveB);
    }

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) public pure virtual override returns (uint256 amountOut) {
        return LENXLibrary.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) public pure virtual override returns (uint256 amountIn) {
        return LENXLibrary.getAmountIn(amountOut, reserveIn, reserveOut);
    }

    function getAmountsOut(
        uint256 amountIn,
        address[] memory path
    ) public view virtual override returns (uint256[] memory amounts) {
        return LENXLibrary.getAmountsOut(factory, amountIn, path);
    }

    function getAmountsIn(
        uint256 amountOut,
        address[] memory path
    ) public view virtual override returns (uint256[] memory amounts) {
        return LENXLibrary.getAmountsIn(factory, amountOut, path);
    }

    function getPairInAdvance(address tokenA, address tokenB) public view virtual override returns (address) {
        return LENXLibrary.pairFor(factory, tokenA, tokenB);
    }
}
