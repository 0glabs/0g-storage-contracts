// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;

import "../utils/UQ112x112.sol";
import "../token/ISafeERC20.sol";
import "../token/IUploadToken.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract PeakSwap {
    using UQ112x112 for uint224;

    ISafeERC20 public immutable token0; // ZeroGStorage token
    IUploadToken public immutable token1; // Storage token

    uint112 private reserve0;
    uint112 private reserve1;

    uint256 public lastDripBlockNumber;
    uint256 public constant TOKENS_PER_BLOCK = 1;
    uint256 public constant BOUNDARY_PRICE = 1;

    address immutable public stake;
    address immutable public cashier;

    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    constructor(address zgsToken, address uploadToken, address stake_, address cashier_) {
        token0 = ISafeERC20(zgsToken);
        token1 = IUploadToken(uploadToken);
        stake = stake_;
        cashier = cashier_;
    }

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "UniswapV2Router: EXPIRED");
        _;
    }

    // update reserves and, on the first call per block, price accumulators
    function _update(uint256 balance0, uint256 balance1) private {
        require(
            balance0 <= type(uint112).max && balance1 <= type(uint112).max,
            "UniswapV2: OVERFLOW"
        );

        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);

        emit Sync(reserve0, reserve1);
    }

    function _getByDirection(bool direction)
        internal
        view
        returns (
            uint256 reserveIn,
            uint256 reserveOut,
            ISafeERC20 tokenIn
        )
    {
        if (direction) {
            tokenIn = token0;
            reserveIn = reserve0;
            reserveOut = reserve1;
        } else {
            tokenIn = token1;
            reserveIn = reserve1;
            reserveOut = reserve0;
        }
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        bool direction,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256 amountOut) {
        updateMarket();
        (
            uint256 reserveIn,
            uint256 reserveOut,
            ISafeERC20 tokenIn
        ) = _getByDirection(direction);
        _getAmountIn(amountOut, reserveIn, reserveOut);
        require(
            amountOut >= amountOutMin,
            "UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT"
        );
        tokenIn.transferFrom(msg.sender, address(this), amountIn);
        _swapByDirection(direction, amountOut, amountIn, to);
    }

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        bool direction,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256 amountIn) {
        updateMarket();
        (
            uint256 reserveIn,
            uint256 reserveOut,
            ISafeERC20 tokenIn
        ) = _getByDirection(direction);
        _getAmountOut(amountIn, reserveIn, reserveOut);
        require(
            amountIn <= amountInMax,
            "UniswapV2Router: EXCESSIVE_INPUT_AMOUNT"
        );
        tokenIn.transferFrom(msg.sender, address(this), amountIn);
        _swapByDirection(direction, amountOut, amountIn, to);
    }

    function _swapByDirection(
        bool direction,
        uint256 amountOut,
        uint256 amountIn,
        address to
    ) internal {
        if (direction) {
            _swap(0, amountOut, amountIn, 0, to);
        } else {
            _swap(amountOut, 0, 0, amountIn, to);
        }
    }

    function _swap(
        uint256 amount0Out,
        uint256 amount1Out,
        uint256 amount0In,
        uint256 amount1In,
        address to
    ) internal {
        require(
            amount0Out > 0 || amount1Out > 0,
            "UniswapV2: INSUFFICIENT_OUTPUT_AMOUNT"
        );
        require(
            amount0Out < reserve0 && amount1Out < reserve1,
            "UniswapV2: INSUFFICIENT_LIQUIDITY"
        );
        require(
            to != address(token0) && to != address(token1),
            "UniswapV2: INVALID_TO"
        );
        if (amount0Out > 0) token0.transfer(to, amount0Out);
        if (amount1Out > 0) token1.transfer(to, amount1Out);
        uint256 balance0 = token0.balanceOf(address(this));
        uint256 balance1 = token1.balanceOf(address(this));

        require(balance0 * balance1 >= reserve0 * reserve1, "UniswapV2: K");

        _update(balance0, balance1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function _getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountOut) {
        require(amountIn > 0, "UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT");
        require(
            reserveIn > 0 && reserveOut > 0,
            "UniswapV2Library: INSUFFICIENT_LIQUIDITY"
        );
        amountOut = (amountIn * reserveOut) / (reserveIn + amountIn);
    }

    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    function _getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountIn) {
        require(amountOut > 0, "UniswapV2Library: INSUFFICIENT_OUTPUT_AMOUNT");
        require(
            reserveIn > 0 && reserveOut > 0,
            "UniswapV2Library: INSUFFICIENT_LIQUIDITY"
        );
        amountIn = Math.ceilDiv(reserveIn * amountOut, reserveOut - amountOut);
    }

    function updateMarket()
        public
        returns (uint256 amount1In, uint256 amount0Out)
    {
        require(
            reserve0 > 0 && reserve1 > 0,
            "UniswapV2Library: INSUFFICIENT_LIQUIDITY"
        );

        if (lastDripBlockNumber == block.number) {
            return (0, 0);
        }

        uint256 reserve1Max = Math.sqrt((reserve0 * reserve1) / BOUNDARY_PRICE);
        if (reserve1 > reserve1Max) {
            return (0, 0);
        }

        uint256 amount1InMax = reserve1Max - reserve1;
        uint256 amount1InActual = (block.number - lastDripBlockNumber) *
            TOKENS_PER_BLOCK;
        lastDripBlockNumber = block.number;
        amount1In = Math.min(amount1InMax, amount1InActual);

        token1.mintForMarket(amount1In);
        amount0Out = _getAmountOut(amount1In, reserve1, reserve0);
        _swapByDirection(false, amount0Out, amount1In, stake);

        uint256 basicFee = amount1In * BOUNDARY_PRICE;
        if(basicFee > amount0Out) {
            basicFee = amount0Out;
        }
        token0.transferFrom(stake, cashier, basicFee);
    }

    // force balances to match reserves
    function skim(address to) external {
        token0.transfer(to, token0.balanceOf(address(this)) - reserve0);
        token1.transfer(to, token1.balanceOf(address(this)) - reserve1);
    }
}
