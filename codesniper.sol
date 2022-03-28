// SPDX-License-Identifier: MIT
pragma solidity >=0.4.16 <0.9.0;

import './PancakePair.sol';

contract SafeBuy {
    using SafeMath for uint;
    address private owner;
    address private weth;
    uint constant deadline = 1 days;
    uint8 fee = 25;
    address private factoryAddr;

    // WETH on ETH or WBNB on BSC
    constructor(address _weth, address _factoryAddr) {
        owner = msg.sender;
        weth = _weth;
        factoryAddr = _factoryAddr;
    }
    //pending情况下的购买
    function buyByToken(address buyToken, uint amountIn) external {
        IPancakeFactory factory = IPancakeFactory(factoryAddr);
        address pairAddr = factory.getPair(weth, buyToken);
        IPancakePair pair = IPancakePair(pairAddr);
        address t0 = pair.token0();
        uint8 index = 0;
        if (t0 != weth) {
            index = 1;
        }
        buyInner(pairAddr, buyToken, index, amountIn);
    }

    //index 为BNB的位置
    function buy(address pairAddr, address buyToken, uint8 index, uint amountIn) external {
        buyInner(pairAddr, buyToken, index, amountIn);
    }

    //index 为BNB的位置
    function sell(address pairAddr, address sellTokenAddr, uint8 index, uint amountSell) external {
        sellToken(pairAddr, sellTokenAddr, index, amountSell);
    }

    //index 为BNB的位置
    function buyInner(address pairAddr, address buyToken, uint8 index, uint amountIn) internal {
        IPancakePair pair = IPancakePair(pairAddr);
        (uint112 _reserve0, uint112 _reserve1,) = pair.getReserves();
        require(_reserve0 > 0 && _reserve1 > 0, "eq 0");

        IERC20 eth = IERC20(weth);
        eth.transfer(pairAddr, amountIn);

        bytes memory zeroData;
        if (index == 0) {
            uint amountOut = getAmountOut(amountIn, _reserve0, _reserve1, fee);
            pair.swap(0, amountOut, address(this), zeroData);
        } else {
            uint amountOut = getAmountOut(amountIn, _reserve1, _reserve0, fee);
            pair.swap(amountOut, 0, address(this), zeroData);
        }
        IERC20 token = IERC20(buyToken);
        uint tokenAmount = token.balanceOf(address(this)) / 1000;
        require(tokenAmount > 0, "token err");
        //测试是否能卖
        sellToken(pairAddr, buyToken, index, tokenAmount);
        //        token.transfer(owner, tokenAmount);
    }

    //index 为BNB的位置
    function sellToken(address pairAddr, address sellTokenAddr, uint8 index, uint amountSell) internal {
        IPancakePair pair = IPancakePair(pairAddr);
        (uint112 _reserve0, uint112 _reserve1,) = pair.getReserves();
        require(_reserve0 > 0 && _reserve1 > 0, "eq 0");
        IERC20 token = IERC20(sellTokenAddr);
        token.transfer(pairAddr, amountSell);
        uint amountToken = token.balanceOf(pairAddr);
        bytes memory zeroData;
        if (index == 0) {
            uint amountIn = amountToken - _reserve1;
            uint amountOut = getAmountOut(amountIn, _reserve1, _reserve0, fee);
            pair.swap(amountOut, 0, address(this), zeroData);
        } else {
            uint amountIn = amountToken - _reserve0;
            uint amountOut = getAmountOut(amountIn, _reserve0, _reserve1, fee);
            pair.swap(0, amountOut, address(this), zeroData);
        }
    }

    function transAll(address[] memory tokens) external {
        require(msg.sender == owner, 'love53,not transAll');
        for (uint i = 0; i < tokens.length; i++) {
            IERC20 eth = IERC20(tokens[i]);
            eth.transfer(owner, eth.balanceOf(address(this)));
        }
    }

    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut, uint8 fee) internal pure returns (uint amountOut) {
        require(amountIn > 0, 'love53: INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'love53: INSUFFICIENT_LIQUIDITY');
        uint amountInWithFee = amountIn.mul(10000 - fee);
        uint numerator = amountInWithFee.mul(reserveOut);
        uint denominator = reserveIn.mul(10000).add(amountInWithFee);
        amountOut = numerator / denominator;
    }
}
