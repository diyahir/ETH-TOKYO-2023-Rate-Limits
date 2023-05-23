# DeFi Guardian (Token rate limits)

![DeFi Guardian](https://github.com/diyahir/ETH-TOKYO-2023-Rate-Limits/assets/32445955/8de3f2f5-5085-4cd1-856c-688cc9084d06)

## Features

- Protocol Agnositic approach to token rate limiting
- Performant Codebase
- Easy integration
- Multiple tokens supports with individual withdrawal rate limits and periods.
- Records inflows of tokens and locks them for withdrawal if rate limit hit.
- Enforces withdrawal limits and periods to prevent excessive fund withdrawals (hack prevention).
- Allows the contract owner to register tokens, override limits, and transfer admin privileges.
- Provides a convenient function for guarded contracts to record inflows and withdraw available funds.

## Testing

```bash
forge test
```

## Integration

There are three easy points of integration that you must do to have your protocol guardian properly set up.

1. Onboard Token Logic
2. Deposit Token integration
3. Withdraw Token integration

#### Example Integration

## License

The smart contract is licensed under the UNLICENSED license.

**Note:** The provided smart contract is a simplified example and might not cover all security considerations and edge cases. It is always recommended to conduct a thorough security review and testing before deploying any smart contract in a production environment.
