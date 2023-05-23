# DeFi Guardian

## Token rate-limits for your DeFi Protocol

![DeFi Guardian](https://github.com/diyahir/ETH-TOKYO-2023-Rate-Limits/assets/32445955/8de3f2f5-5085-4cd1-856c-688cc9084d06)

## Features

- Protocol Agnositic approach to token rate limiting
- Performant Codebase
- Easy integration
- Multiple tokens supports with custom withdrawal rate limits and periods for each token.
- Records inflows/outflows of token and maintains a Historacle Oracle of the protocol's token Liquidity.
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
4. Set the Contract as a guarded contract on your Guardian

#### Example Integration

```bash
contract MockDeFi {
    Guardian guardian;

    function setGuardian(address _guardian) external {
        guardian = Guardian(_guardian);
    }

    function deposit(address token, uint256 amount) external {
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        guardian.recordInflow(token, amount);
    }

    function withdraw(address token, uint256 amount) external {
        IERC20(token).transfer(address(guardian), amount);
        guardian.withdraw(token, amount, msg.sender);
    }
}
```

## Contributors

## License

The smart contract is licensed under the UNLICENSED license.

**Note:** The provided smart contract is a simplified example and might not cover all security considerations and edge cases. It is always recommended to conduct a thorough security review and testing before deploying any smart contract in a production environment.
