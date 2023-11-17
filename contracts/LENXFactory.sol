// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "./interfaces/ILENXFactory.sol";
import "./libraries/SafeERC20.sol";
import "./LENXPair.sol";

contract LENXFactory is ILENXFactory {
    using SafeERC20 for IERC20;

    address public constant DEAD = 0x000000000000000000000000000000000000dEaD;

    bool public override flashOn;
    uint public override createFee;
    uint public override flashFee;
    address public override feeToken;
    address public override feeTo;
    address public override feeToSetter;
    mapping(address => bool) public override migrators;

    mapping(address => mapping(address => address)) public override getPair;
    address[] public override allPairs;

    event PairCreated(address indexed token0, address indexed token1, address pair, uint256);
    event SetFeeTo(address indexed feeTo);
    event SetFeeToken(address indexed feeToken);
    event SetFeeToSetter(address indexed oldFeeToSetter, address indexed newFeeToSetter);
    event SetMigrator(address indexed migrator, bool state);
    event SetFlashOn(bool state);
    event SetFlashFee(uint fee);
    event SetCreateFee(uint createFee);

    constructor(address _feeToSetter, address _feeToken) {
        feeToSetter = _feeToSetter;
        feeToken = _feeToken;
        flashOn = false;
        feeTo = DEAD;
    }

    modifier onlyFeeToSetter() {
        require(msg.sender == feeToSetter, "LENX: Only FeeToSetter");
        _;
    }

    function allPairsLength() external view override returns (uint256) {
        return allPairs.length;
    }

    function pairCodeHash() external pure returns (bytes32) {
        return keccak256(type(LENXPair).creationCode);
    }

    function createPair(address tokenA, address tokenB) external override returns (address pair) {
        require(tokenA != tokenB, "LENX: IDENTICAL_ADDRESSES");
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "LENX: ZERO_ADDRESS");
        require(getPair[token0][token1] == address(0), "LENX: PAIR_EXISTS"); // single check is sufficient
        bytes memory bytecode = type(LENXPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        LENXPair(pair).initialize(token0, token1);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        if (createFee != 0) {
            IERC20(feeToken).safeTransferFrom(msg.sender, feeTo, createFee);
        }

        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeToken(address _feeToken) external onlyFeeToSetter {
        feeToken = _feeToken;
        emit SetFeeToken(feeToken);
    }

    function setFeeTo(address _feeTo) external onlyFeeToSetter {
        feeTo = _feeTo;
        emit SetFeeTo(feeTo);
    }

    function setFeeToSetter(address _feeToSetter) external onlyFeeToSetter {
        address oldFeeToSetter = feeToSetter;
        feeToSetter = _feeToSetter;
        emit SetFeeToSetter(oldFeeToSetter, _feeToSetter);
    }

    function setMigrator(address _migrator, bool _state) external onlyFeeToSetter {
        migrators[_migrator] = _state;
        emit SetMigrator(_migrator, _state);
    }

    function setFlashOn(bool _flashOn) external onlyFeeToSetter {
        flashOn = _flashOn;
        emit SetFlashOn(_flashOn);
    }

    function setFlashFee(uint _flashFee) external onlyFeeToSetter {
        flashFee = _flashFee;
        emit SetFlashFee(_flashFee);
    }

    function setCreateFee(uint _createFee) external onlyFeeToSetter {
        createFee = _createFee;
        emit SetCreateFee(_createFee);
    }
}
