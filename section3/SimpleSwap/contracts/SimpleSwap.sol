// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ISimpleSwap } from "./interface/ISimpleSwap.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { SafeMath } from "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract SimpleSwap is ISimpleSwap, ERC20 {
    // Implement core logic here
    using SafeMath for uint;
    address public token0;
    address public token1;
    uint256 public reserve0;
    uint256 public reserve1;

    constructor(address _tokenA, address _tokenB) ERC20("simpleSwap", "simpleSwap") {
        uint tokenACodeSize;
        uint tokenBCodeSize;
        assembly {
            tokenACodeSize := extcodesize(_tokenA)
            tokenBCodeSize := extcodesize(_tokenB)
        }
        require(tokenACodeSize > 0, "SimpleSwap: TOKENA_IS_NOT_CONTRACT");
        require(tokenBCodeSize > 0, "SimpleSwap: TOKENB_IS_NOT_CONTRACT");
        require(_tokenA != _tokenB, "SimpleSwap: TOKENA_TOKENB_IDENTICAL_ADDRESS");
        if (_tokenA < _tokenB) {
            (token0, token1) = (_tokenA, _tokenB);
        } else {
            (token0, token1) = (_tokenB, _tokenA);
        }
    }

    function swap(address tokenIn, address tokenOut, uint256 amountIn) external override returns (uint256 amountOut) {
        uint reserveIn;
        uint reserveOut;

        require(tokenIn == address(token0) || tokenIn == address(token1), "SimpleSwap: INVALID_TOKEN_IN");
        require(tokenOut == address(token0) || tokenOut == address(token1), "SimpleSwap: INVALID_TOKEN_OUT");
        require(tokenIn != tokenOut, "SimpleSwap: IDENTICAL_ADDRESS");
        require(amountIn > 0, "SimpleSwap: INSUFFICIENT_INPUT_AMOUNT");

        if (tokenIn < tokenOut) {
            (reserveIn, reserveOut) = (reserve0, reserve1);
        } else {
            (reserveIn, reserveOut) = (reserve1, reserve0);
        }
        amountOut = amountIn.mul(reserveOut) / (reserveIn + amountIn);

        emit Swap(msg.sender, tokenIn, tokenOut, amountIn, amountOut);
        ERC20(address(tokenIn)).transferFrom(msg.sender, address(this), amountIn);
        ERC20(address(tokenOut)).transfer(msg.sender, amountOut);

        (reserve0, reserve1) = (
            ERC20(address(token0)).balanceOf(address(this)),
            ERC20(address(token1)).balanceOf(address(this))
        );
    }

    function addLiquidity(
        uint256 amountAIn,
        uint256 amountBIn
    ) external override returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        require(amountAIn > 0 && amountBIn > 0, "SimpleSwap: INSUFFICIENT_INPUT_AMOUNT");
        if (reserve0 == 0 && reserve1 == 0) {
            (amountA, amountB) = (amountAIn, amountBIn);
            liquidity = Math.sqrt(amountA.mul(amountB));
        } else {
            uint amountBOptimal = (amountAIn * reserve1) / reserve0;
            if (amountBOptimal <= amountBIn) {
                (amountA, amountB) = (amountAIn, amountBOptimal);
            } else {
                uint amountAOptimal = (amountBIn * reserve0) / reserve1;
                assert(amountAOptimal <= amountAIn);
                (amountA, amountB) = (amountAOptimal, amountBIn);
            }
            liquidity = Math.min(amountA.mul(totalSupply()) / reserve0, amountB.mul(totalSupply()) / reserve1);
        }
        // liquidity = Math.sqrt(amountA.mul(amountB));
        ERC20(address(token0)).transferFrom(msg.sender, address(this), amountA);
        ERC20(address(token1)).transferFrom(msg.sender, address(this), amountB);
        (reserve0, reserve1) = (reserve0 + amountA, reserve1 + amountB);
        _mint(msg.sender, liquidity);
        emit AddLiquidity(msg.sender, amountA, amountB, liquidity);
    }

    function removeLiquidity(uint256 liquidity) external override returns (uint256 amountA, uint256 amountB) {
        require(liquidity > 0, "SimpleSwap: INSUFFICIENT_LIQUIDITY_BURNED");

        amountA = reserve0.mul(liquidity) / totalSupply();
        amountB = reserve1.mul(liquidity) / totalSupply();
        ERC20(address(token0)).transfer(msg.sender, amountA);
        ERC20(address(token1)).transfer(msg.sender, amountB);
        // (reserve0, reserve1) = (
        //     ERC20(address(token0)).balanceOf(address(this)),
        //     ERC20(address(token1)).balanceOf(address(this))
        // );

        _transfer(msg.sender, address(this), liquidity);
        _burn(address(this), liquidity);
    }

    function getReserves() external view override returns (uint256 reserveA, uint256 reserveB) {
        reserveA = reserve0;
        reserveB = reserve1;
    }

    function getTokenA() external view override returns (address tokenA) {
        tokenA = address(token0);
    }

    function getTokenB() external view override returns (address tokenB) {
        tokenB = address(token1);
    }
}
