// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IUniswapV2Pair } from "v2-core/interfaces/IUniswapV2Pair.sol";
import { IUniswapV2Callee } from "v2-core/interfaces/IUniswapV2Callee.sol";

// This is a practice contract for flash swap arbitrage
contract Arbitrage is IUniswapV2Callee, Ownable {

    struct Calldata {
        address borrowToken;
        address repayToken;
        uint256 borrowAmount;
        uint256 repayAmount;
        uint256 swapAmount;
        address borrowPool;
        address repayPool;
    }

    //
    // EXTERNAL NON-VIEW ONLY OWNER
    //

    function withdraw() external onlyOwner {
        (bool success, ) = msg.sender.call{ value: address(this).balance }("");
        require(success, "Withdraw failed");
    }

    function withdrawTokens(address token, uint256 amount) external onlyOwner {
        require(IERC20(token).transfer(msg.sender, amount), "Withdraw failed");
    }

    //
    // EXTERNAL NON-VIEW
    //

    function uniswapV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external override {
        // TODO
        Calldata memory callbackData = abi.decode(data, (Calldata));
        require(msg.sender == callbackData.borrowPool ,"msg.sender should be pair of borrowPool");
        require(sender == address(this), "sender should be this contract");
        require(amount0 > 0 || amount1 > 0, "amount- or amount1 must greater than 0");


        // step2. swap  WETH for USDC in higher price pool
        // so we need to give WETH we borrowed in lower-pool, give it to hogh-pool -> then swap
        IERC20(callbackData.borrowToken).transfer(callbackData.repayPool, callbackData.borrowAmount);
        IUniswapV2Pair(callbackData.repayPool).swap(0, callbackData.swapAmount, address(this), "");

        // step3. repay the amount to lower-pool(which is borrow-pool here)
        IERC20(callbackData.repayToken).transfer(callbackData.borrowPool, callbackData.repayAmount);
    }

    // Method 1 is
    //  - borrow WETH from lower price pool
    //  - swap WETH for USDC in higher price pool
    //  - repay USDC to lower pool
    // Method 2 is
    //  - borrow USDC from higher price pool
    //  - swap USDC for WETH in lower pool
    //  - repay WETH to higher pool
    // for testing convenient, we implement the [method 1] here
    function arbitrage(address priceLowerPool, address priceHigherPool, uint256 borrowETH) external {
        // TODO

        // calculate the swap amount that we need for "swap WETH for USDC in higher price pool"
        // => the swapAmonut is calculate by what we borrowed and the pool we're gonna to swap.
        // since we need to know how much we can swap from the high-pool, and we'll use borrowETH as token-in
        (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(priceHigherPool).getReserves();
        uint256 swaptAmount = _getAmountOut(borrowETH, reserve0, reserve1);
        
        // calculate the repay amount for "repay USDC to lower pool"
        // => repay amount is what wee need to repay to lower-pool
        // since we know the out= borrowETH so we want to calculate the token-in amount should be repaid.
        (uint112 reserve0_repay,uint112 reserve1_repay,) = IUniswapV2Pair(priceLowerPool).getReserves();
        uint256 repayAmount = _getAmountIn(borrowETH, reserve1_repay, reserve0_repay);

        // put data together send within swap to trigger uniswapV2Call
        Calldata memory data = Calldata( 
            IUniswapV2Pair(priceLowerPool).token0(), 
            IUniswapV2Pair(priceLowerPool).token1(), 
            borrowETH,
            repayAmount,
            swaptAmount,
            priceLowerPool,
            priceHigherPool)
        ;
        
        // step1. borrow WETH from lower price pool = swap the token in price-lower-pool
        IUniswapV2Pair(priceLowerPool).swap(borrowETH, 0, address(this), abi.encode(data));
    }

    //
    // INTERNAL PURE
    //

    // copy from UniswapV2Library
    function _getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountIn) {
        require(amountOut > 0, "UniswapV2Library: INSUFFICIENT_OUTPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "UniswapV2Library: INSUFFICIENT_LIQUIDITY");
        uint256 numerator = reserveIn * amountOut * 1000;
        uint256 denominator = (reserveOut - amountOut) * 997;
        amountIn = numerator / denominator + 1;
    }

    // copy from UniswapV2Library
    function _getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountOut) {
        require(amountIn > 0, "UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "UniswapV2Library: INSUFFICIENT_LIQUIDITY");
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 1000 + amountInWithFee;
        amountOut = numerator / denominator;
    }
}
