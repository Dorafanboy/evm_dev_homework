// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-periphery/contracts/libraries/UniswapV2Library.sol";

contract PancakeSwapTrader is Ownable, ReentrancyGuard {
    IUniswapV2Router02 public immutable pancakeRouter;
    IUniswapV2Factory public immutable pancakeFactory;
    address public immutable WBNB;
    
    event TokensPurchased(
        address indexed token, 
        uint256 amountOut, 
        uint256 amountIn,
        address indexed buyer
    );
    
    event LiquidityAdded(
        address indexed token, 
        uint256 tokenAmount, 
        uint256 bnbAmount, 
        uint256 liquidity,
        address indexed provider
    );
    
    event SwapAndAddLiquidity(
        address indexed token, 
        uint256 tokensBought,
        uint256 tokensToLiquidity, 
        uint256 bnbUsed,
        address indexed user
    );

    constructor(address _pancakeRouter) {
        require(_pancakeRouter != address(0), "Invalid router address");
        
        pancakeRouter = IUniswapV2Router02(_pancakeRouter);
        pancakeFactory = IUniswapV2Factory(pancakeRouter.factory());
        WBNB = pancakeRouter.WETH();
    }

    function buyTokensExact(
        address token,
        uint256 amountOut,
        uint256 deadline
    ) external payable nonReentrant {
        require(token != address(0), "Invalid token address");
        require(amountOut > 0, "Amount must be greater than 0");
        require(deadline > block.timestamp, "Deadline expired");
        require(msg.value > 0, "Must send BNB");

        address[] memory path = new address[](2);
        path[0] = WBNB;
        path[1] = token;

        uint[] memory amountsIn = UniswapV2Library.getAmountsIn(
            address(pancakeFactory),
            amountOut,
            path
        );
        
        require(msg.value >= amountsIn[0], "Insufficient BNB sent");

        uint[] memory amounts = pancakeRouter.swapETHForExactTokens{value: amountsIn[0]}(
            amountOut,
            path,
            address(this),
            deadline
        );

        uint256 refund = msg.value - amounts[0];
        if (refund > 0) {
            payable(msg.sender).transfer(refund);
        }

        emit TokensPurchased(token, amounts[1], amounts[0], msg.sender);
    }

    function buyTokensExactDirect(
        address token,
        uint256 amountOut,
        uint256 deadline
    ) external payable nonReentrant {
        require(token != address(0), "Invalid token address");
        require(amountOut > 0, "Amount must be greater than 0");
        require(deadline > block.timestamp, "Deadline expired");
        require(msg.value > 0, "Must send BNB");

        address pair = pancakeFactory.getPair(WBNB, token);
        require(pair != address(0), "Pair does not exist");

        (uint reserveWBNB, uint reserveToken) = UniswapV2Library.getReserves(
            address(pancakeFactory),
            WBNB,
            token
        );

        uint amountIn = UniswapV2Library.getAmountIn(amountOut, reserveWBNB, reserveToken);
        require(msg.value >= amountIn, "Insufficient BNB sent");

        IWETH(WBNB).deposit{value: amountIn}();
        
        IERC20(WBNB).transfer(pair, amountIn);

        (address token0,) = UniswapV2Library.sortTokens(WBNB, token);
        (uint amount0Out, uint amount1Out) = WBNB == token0 ? (uint(0), amountOut) : (amountOut, uint(0));

        IUniswapV2Pair(pair).swap(amount0Out, amount1Out, address(this), new bytes(0));

        uint256 refund = msg.value - amountIn;
        if (refund > 0) {
            payable(msg.sender).transfer(refund);
        }

        emit TokensPurchased(token, amountOut, amountIn, msg.sender);
    }

    function swapAndAddLiquidity(
        address token,
        uint256 tokenAmountDesired,
        uint256 liquidityPercentage,
        uint256 deadline
    ) external payable nonReentrant {
        require(token != address(0), "Invalid token address");
        require(tokenAmountDesired > 0, "Amount must be greater than 0");
        require(liquidityPercentage <= 100, "Percentage cannot exceed 100");
        require(deadline > block.timestamp, "Deadline expired");
        require(msg.value > 0, "Must send BNB");

        address[] memory path = new address[](2);
        path[0] = WBNB;
        path[1] = token;

        uint[] memory amountsIn = UniswapV2Library.getAmountsIn(
            address(pancakeFactory),
            tokenAmountDesired,
            path
        );

        uint bnbForSwap = amountsIn[0];
        require(msg.value > bnbForSwap, "Insufficient BNB for swap and liquidity");

        uint[] memory amounts = pancakeRouter.swapETHForExactTokens{value: bnbForSwap}(
            tokenAmountDesired,
            path,
            address(this),
            deadline
        );

        uint tokensBought = amounts[1];
        uint bnbUsedForSwap = amounts[0];

        uint tokensForLiquidity = (tokensBought * liquidityPercentage) / 100;
        uint bnbForLiquidity = msg.value - bnbUsedForSwap;

        uint liquidity = 0;
        if (tokensForLiquidity > 0 && bnbForLiquidity > 0) {
            IERC20(token).approve(address(pancakeRouter), tokensForLiquidity);

            (uint amountToken, uint amountETH, uint liquidityMinted) = pancakeRouter.addLiquidityETH{value: bnbForLiquidity}(
                token,
                tokensForLiquidity,
                0,
                0,
                msg.sender,
                deadline
            );

            liquidity = liquidityMinted;
            emit LiquidityAdded(token, amountToken, amountETH, liquidity, msg.sender);

            uint unusedBNB = bnbForLiquidity - amountETH;
            if (unusedBNB > 0) {
                payable(msg.sender).transfer(unusedBNB);
            }
        }

        uint remainingTokens = tokensBought - tokensForLiquidity;
        if (remainingTokens > 0) {
            IERC20(token).transfer(msg.sender, remainingTokens);
        }

        emit SwapAndAddLiquidity(token, tokensBought, tokensForLiquidity, bnbUsedForSwap, msg.sender);
    }

    function addLiquidityWithTokens(
        address token,
        uint256 tokenAmount,
        uint256 deadline
    ) external payable nonReentrant {
        require(token != address(0), "Invalid token address");
        require(tokenAmount > 0, "Token amount must be greater than 0");
        require(msg.value > 0, "BNB amount must be greater than 0");
        require(deadline > block.timestamp, "Deadline expired");

        IERC20(token).transferFrom(msg.sender, address(this), tokenAmount);
        
        IERC20(token).approve(address(pancakeRouter), tokenAmount);

        (uint amountToken, uint amountETH, uint liquidity) = pancakeRouter.addLiquidityETH{value: msg.value}(
            token,
            tokenAmount,
            0,
            0,
            msg.sender,
            deadline
        );

        uint unusedTokens = tokenAmount - amountToken;
        if (unusedTokens > 0) {
            IERC20(token).transfer(msg.sender, unusedTokens);
        }
        
        uint unusedBNB = msg.value - amountETH;
        if (unusedBNB > 0) {
            payable(msg.sender).transfer(unusedBNB);
        }

        emit LiquidityAdded(token, amountToken, amountETH, liquidity, msg.sender);
    }

    function getTokenPrice(address token, uint256 tokenAmount) external view returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = token;
        path[1] = WBNB;

        uint[] memory amounts = UniswapV2Library.getAmountsOut(
            address(pancakeFactory),
            tokenAmount,
            path
        );
        
        return amounts[1];
    }

    function getBNBRequired(address token, uint256 tokenAmount) external view returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = WBNB;
        path[1] = token;

        uint[] memory amounts = UniswapV2Library.getAmountsIn(
            address(pancakeFactory),
            tokenAmount,
            path
        );
        
        return amounts[0];
    }

    function getPairInfo(address token) external view returns (
        address pair,
        uint256 reserveToken,
        uint256 reserveBNB,
        uint256 totalSupply
    ) {
        pair = pancakeFactory.getPair(token, WBNB);
        if (pair != address(0)) {
            (reserveToken, reserveBNB) = UniswapV2Library.getReserves(
                address(pancakeFactory),
                token,
                WBNB
            );
            totalSupply = IERC20(pair).totalSupply();
        }
    }

    function getTokenBalance(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    function getBNBBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function withdrawToken(address token, uint256 amount) external onlyOwner {
        IERC20(token).transfer(owner(), amount);
    }

    function withdrawBNB(uint256 amount) external onlyOwner {
        payable(owner()).transfer(amount);
    }

    function emergencyWithdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    receive() external payable {}
}

interface IWETH {
    function deposit() external payable;
    function withdraw(uint) external;
} 