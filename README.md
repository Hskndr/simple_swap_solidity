SimpleSwap
Smart contract in Solidity for swapping ERC-20 tokens and managing liquidity between token pairs.

📌 Description
SimpleSwap is a lightweight, Uniswap-inspired smart contract that enables users to:

Add liquidity to a pool of two ERC-20 tokens.

Remove their share of liquidity proportionally.

Swap one token for another using a constant product formula.

Check the price of one token in terms of another.

Estimate the output amount before performing a swap.

It is fully compatible with a verifier contract like SwapVerifier for automated testing.

🛠 Requirements
Solidity ^0.8.0

Two ERC-20 compatible tokens

Development tools: Remix, Hardhat, Foundry, etc.

🔧 Functions
🧪 addLiquidity
solidity
Copiar
Editar
function addLiquidity(
    address tokenA,
    address tokenB,
    uint amountADesired,
    uint amountBDesired,
    uint amountAMin,
    uint amountBMin,
    address to,
    uint deadline
) external returns (uint amountA, uint amountB, uint liquidity);
Adds liquidity to the pool.

Transfers tokens from the user.

Calculates optimal amounts.

Mints and assigns liquidity tokens to to.

🧪 removeLiquidity
solidity
Copiar
Editar
function removeLiquidity(
    address tokenA,
    address tokenB,
    uint liquidity,
    uint amountAMin,
    uint amountBMin,
    address to,
    uint deadline
) external returns (uint amountA, uint amountB);
Removes liquidity and returns tokens to the user.

🔄 swapExactTokensForTokens
solidity
Copiar
Editar
function swapExactTokensForTokens(
    uint amountIn,
    uint amountOutMin,
    address[] calldata path,
    address to,
    uint deadline
) external returns (uint[] memory amounts);
Swaps an exact amount of input tokens for output tokens.
Supports simple 1-hop swaps via a path array with two addresses.

📈 getPrice
solidity
Copiar
Editar
function getPrice(address tokenA, address tokenB) external view returns (uint price);
Returns the price of tokenA in terms of tokenB.
Uses the internal reserves to calculate (reserveB * 1e18) / reserveA.

📊 getAmountOut
solidity
Copiar
Editar
function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) public pure returns (uint amountOut);
Estimates how much tokenOut will be received for amountIn tokens.

✅ Features
No fees charged on swaps or liquidity actions.

Compatible with any ERC-20 token pair.

Fully stateless regarding token ordering (normalizes internally).

Designed to pass automated tests using a verifier contract.

📝 License
MIT

