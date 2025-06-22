# SimpleSwap

Smart contract in Solidity for swapping ERC20 tokens and managing liquidity between pairs.

## Description

`SimpleSwap` allows you to:

- Add liquidity to a token pair
- Remove proportional liquidity
- Swap between tokenA and tokenB
- Check token price and calculate expected output (`getAmountOut`)

The contract is designed to be compatible with an external verifier contract (`SwapVerifier`) and with any ERC20 tokens.

## Requirements

- Solidity 0.8.x
- ERC20-compatible tokens
- Development environment: Remix, Hardhat, or similar

## Features

### Add Liquidity

solidity
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

### Remove Liquidity

function removeLiquidity(
    address tokenA,
    address tokenB,
    uint liquidity,
    uint amountAMin,
    uint amountBMin,
    address to,
    uint deadline
) external returns (uint amountA, uint amountB);

### Swap Tokens

function swapExactTokensForTokens(
    uint amountIn,
    uint amountOutMin,
    address[] calldata path,
    address to,
    uint deadline
) external;

### Get Token Price

function getPrice(address tokenA, address tokenB) external view returns (uint price);

### Estimate Output Amount

function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) public pure returns (uint amountOut);

## Notes

    The contract is generic: works with any ERC20 token pair.

    Token order does not matter; it is normalized internally.

    The contract does not charge fees.

## License

MIT

