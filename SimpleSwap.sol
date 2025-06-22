// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function totalSupply() external view returns (uint);
    function balanceOf(address account) external view returns (uint);
    function transfer(address to, uint value) external returns (bool);
    function approve(address spender, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);
}

/// @title SimpleSwap - A simple token swap and liquidity pool contract
/// @author Hiskander Aguillon
/// @notice This contract allows users to add/remove liquidity and swap between two ERC20 tokens.
/// @dev Uses a simplified constant product formula without fees.
contract SimpleSwap {
    struct Pool {
        uint reserveA; 
        uint reserveB; 
        uint totalLiquidity;
        mapping(address => uint) liquidity;
    }

    mapping(bytes32 => Pool) internal pools;

    /// @notice Emitted when liquidity is added to a pool
    event LiquidityAdded(
        address indexed tokenA, 
        address indexed tokenB, 
        address indexed provider,
        uint amountA, 
        uint amountB, 
        uint liquidity
        );

    /// @notice Emitted when liquidity is removed from a pool
    event LiquidityRemoved(
        address indexed tokenA, 
        address indexed tokenB, 
        address indexed provider, 
        uint amountA, 
        uint amountB, 
        uint liquidity);

    /// @notice Emitted when a swap is executed
    event Swap(
        address indexed tokenIn, 
        address indexed tokenOut, 
        address indexed user, 
        uint amountIn, 
        uint amountOut
        );

    /// @notice Emitted when a swap is executed
    event TokensSwapped(
        address indexed tokenIn,
        address indexed tokenOut,
        address indexed sender,
        uint amountIn,
        uint amountOut,
        address recipient
    );

    /// @dev Modifier to check deadline for time-sensitive functions
    modifier ensure(uint deadline) {
        require(block.timestamp <= deadline, "SimpleSwap: EXPIRED");
        _;
    }

    /// @dev Generates a unique identifier for a token pair
    function _pairKey(address tokenA, address tokenB) internal pure returns (bytes32) {
        return tokenA < tokenB 
            ? keccak256(abi.encodePacked(tokenA, tokenB)) 
            : keccak256(abi.encodePacked(tokenB, tokenA));
    }

    /// @dev Ensures consistent token ordering
    function _sortTokens(address tokenA, address tokenB, uint amountA, uint amountB)
        internal pure returns (address, address, uint, uint)
    {
        return tokenA < tokenB 
            ? (tokenA, tokenB, amountA, amountB)
            : (tokenB, tokenA, amountB, amountA);
    }

    /// @notice Add liquidity to the pool for a token pair
    /// @param tokenA Address of token A
    /// @param tokenB Address of token B
    /// @param amountADesired Amount of token A desired to add
    /// @param amountBDesired Amount of token B desired to add
    /// @param amountAMin Minimum amount of token A to add (slippage protection)
    /// @param amountBMin Minimum amount of token B to add (slippage protection)
    /// @param to Address to receive liquidity tokens
    /// @param deadline Time after which the transaction is invalid
    /// @return amountA Actual amount of token A added
    /// @return amountB Actual amount of token B added
    /// @return liquidity Amount of liquidity tokens minted
    function addLiquidity(
            address tokenA,
            address tokenB,
            uint amountADesired,
            uint amountBDesired,
            uint amountAMin,
            uint amountBMin,
            address to,
            uint deadline
        ) external ensure(deadline) returns (uint amountA, uint amountB, uint liquidity) {
            require(tokenA != tokenB, "IDENTICAL_ADDRESSES");
            require(
                amountADesired >= amountAMin && amountBDesired >= amountBMin, "INSUFFICIENT_AMOUNT"
                );

            (amountA, amountB, liquidity) = _addLiquidity(
                tokenA, tokenB, amountADesired, amountBDesired, to
                );

            require(amountA >= amountAMin, "SLIPPAGE_A");
            require(amountB >= amountBMin, "SLIPPAGE_B");

            emit LiquidityAdded(tokenA, tokenB, to, amountA, amountB, liquidity);
        }

    /// @dev Internal function to handle liquidity adding logic
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        address to
    ) internal returns (uint amountA, uint amountB, uint liquidity) {
        ( , , uint aDesired, uint bDesired) = _sortTokens(
            tokenA, tokenB, amountADesired, amountBDesired
            );
        bytes32 key = _pairKey(tokenA, tokenB);
        Pool storage pool = pools[key];

        if (pool.totalLiquidity == 0) {
            amountA = aDesired;
            amountB = bDesired;
            liquidity = sqrt(amountA * amountB);
        } else {
            uint ratioA = (aDesired * pool.reserveB) / pool.reserveA;
            require(ratioA <= bDesired, "WRONG_RATIO");
            amountA = aDesired;
            amountB = ratioA;
            liquidity = (amountA * pool.totalLiquidity) / pool.reserveA;
        }

        // Transfer the actual amounts used, not desired (avoid excess transfer)
        IERC20(tokenA).transferFrom(msg.sender, address(this), amountA);
        IERC20(tokenB).transferFrom(msg.sender, address(this), amountB);

        pool.reserveA += amountA;
        pool.reserveB += amountB;
        pool.totalLiquidity += liquidity;
        pool.liquidity[to] += liquidity;
    }

    /// @notice Removes liquidity from a token pair pool and returns the tokens to the user
    /// @param tokenA Address of token A
    /// @param tokenB Address of token B
    /// @param liquidity Amount of liquidity tokens to burn
    /// @param amountAMin Minimum amount of token A to receive (slippage protection)
    /// @param amountBMin Minimum amount of token B to receive (slippage protection)
    /// @param to Recipient of the withdrawn tokens
    /// @param deadline Expiry time for the transaction
    /// @return amountA Amount of token A returned
    /// @return amountB Amount of token B returned
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external ensure(deadline) returns (uint amountA, uint amountB) {
        bytes32 key = _pairKey(tokenA, tokenB);
        Pool storage pool = pools[key];

        require(pool.liquidity[msg.sender] >= liquidity, "INSUFFICIENT_LIQUIDITY");

        amountA = (liquidity * pool.reserveA) / pool.totalLiquidity;
        amountB = (liquidity * pool.reserveB) / pool.totalLiquidity;

        require(amountA >= amountAMin, "SLIPPAGE_A");
        require(amountB >= amountBMin, "SLIPPAGE_B");

        // Update state before transfers to follow CEI pattern
        pool.reserveA -= amountA;
        pool.reserveB -= amountB;
        pool.totalLiquidity -= liquidity;
        pool.liquidity[msg.sender] -= liquidity;

        // Return tokens to user
        IERC20(tokenA).transfer(to, amountA);
        IERC20(tokenB).transfer(to, amountB);

        emit LiquidityRemoved(tokenA, tokenB, msg.sender, amountA, amountB, liquidity);
    }

    /// @notice Swaps an exact amount of input tokens for as many output tokens as possible
    /// @param amountIn Amount of input tokens to send
    /// @param amountOutMin Minimum amount of output tokens to receive (slippage protection)
    /// @param path Array with exactly 2 elements: input token and output token addresses
    /// @param to Recipient of the output tokens
    /// @param deadline Time after which the transaction is invalid   
    function swapExactTokensForTokens(
            uint256 amountIn,
            uint256 amountOutMin,
            address[] calldata path,
            address to,
            uint256 deadline
        ) external ensure(deadline) {
            require(path.length == 2, "SimpleSwap: INVALID_PATH");
            _swap(amountIn, amountOutMin, path[0], path[1], to);
        }

    /// @dev Executes the internal logic for a token swap
    /// @param amountIn Amount of input token sent
    /// @param amountOutMin Minimum amount of output token required
    /// @param tokenIn Address of input token
    /// @param tokenOut Address of output token
    /// @param to Recipient of the output tokens
    function _swap(
            uint256 amountIn,
            uint256 amountOutMin,
            address tokenIn,
            address tokenOut,
            address to
        ) internal {
            bytes32 key = _pairKey(tokenIn, tokenOut);
            Pool storage pool = pools[key];

            uint reserveIn;
            uint reserveOut;

            bool isTokenInFirst = tokenIn < tokenOut;

            if (isTokenInFirst) {
                reserveIn = pool.reserveA;
                reserveOut = pool.reserveB;
            } else {
                reserveIn = pool.reserveB;
                reserveOut = pool.reserveA;
            }

            uint amountOut = getAmountOut(amountIn, reserveIn, reserveOut);
            require(amountOut >= amountOutMin, "INSUFFICIENT_OUTPUT");

            // Transfer tokens
            IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
            IERC20(tokenOut).transfer(to, amountOut);

            // Update reserves (CEI pattern)
            if (isTokenInFirst) {
                pool.reserveA += amountIn;
                pool.reserveB -= amountOut;
            } else {
                pool.reserveB += amountIn;
                pool.reserveA -= amountOut;
            }

            emit TokensSwapped(tokenIn, tokenOut, msg.sender, amountIn, amountOut, to);
        }



    /// @notice Returns the price of tokenB in terms of tokenA (18 decimals)
    /// @param tokenA Address of token A
    /// @param tokenB Address of token B
    /// @return price The price of 1 tokenA in tokenB units
    function getPrice(address tokenA, address tokenB) external view returns (uint price) {
        bytes32 key = _pairKey(tokenA, tokenB);
        Pool storage pool = pools[key];

        (uint reserveA, uint reserveB) = tokenA < tokenB
            ? (pool.reserveA, pool.reserveB)
            : (pool.reserveB, pool.reserveA);

        require(reserveA > 0, "NO_LIQUIDITY");

        price = (reserveB * 1e18) / reserveA;
    }

    /// @notice Calculates output amount given an input amount and reserves
    /// @param amountIn Amount of input tokens
    /// @param reserveIn Reserve of input token
    /// @param reserveOut Reserve of output token
    /// @return amountOut Calculated amount of output tokens
    function getAmountOut(
        uint amountIn, 
        uint reserveIn, 
        uint reserveOut
        ) public pure returns (uint amountOut) {
        require(reserveIn > 0 && reserveOut > 0, "INVALID_RESERVES");

        amountOut = (amountIn * reserveOut) / (reserveIn + amountIn);
    }

    /// @notice Calculates the integer square root of a number
    /// @dev Uses the Babylonian method for computing square root
    /// @param y Input value
    /// @return z Integer square root of input
    function sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}
