# DeFi Guardian: Token rate-limits for your DeFi Protocol

## Features

- Protocol Agnositic approach to token rate limiting
- Performant Codebase
- Easy integration
- Multiple tokens supports with custom withdrawal rate limits and periods for each token.
- Records inflows/outflows of token and maintains a Historical Oracle of the protocol's token Liquidity.
- Enforces withdrawal limits and periods to prevent excessive fund withdrawals (hack prevention).
- Allows the contract owner to register tokens, override limits, and transfer admin privileges.
- Provides a convenient function for guarded contracts to record inflows and withdraw available funds.

![DeFi Guardian](https://github.com/diyahir/ETH-TOKYO-2023-Rate-Limits/assets/32445955/8de3f2f5-5085-4cd1-856c-688cc9084d06)
![Rate Limit](https://github.com/diyahir/ETH-TOKYO-2023-Rate-Limits/assets/32445955/5a2a6603-3939-4ddc-896f-b60f3d9a9895)

## Testing

```bash
forge test
```

## Code Coverage

```bash
forge coverage
```

| File                     | % Lines         | % Statements      | % Branches     | % Funcs        |
| ------------------------ | --------------- | ----------------- | -------------- | -------------- |
| src/Guardian.sol         | 100.00% (89/89) | 100.00% (99/99)   | 85.29% (29/34) | 93.33% (14/15) |
| src/MockDeFiProtocol.sol | 100.00% (5/5)   | 100.00% (5/5)     | 100.00% (0/0)  | 100.00% (3/3)  |
| src/MockToken.sol        | 100.00% (2/2)   | 100.00% (2/2)     | 100.00% (0/0)  | 100.00% (2/2)  |
| Total                    | 100.00% (96/96) | 100.00% (106/106) | 85.29% (29/34) | 95.00% (19/20) |

## Integration

There are three easy points of integration that you must do to have your protocol guardian properly set up.

1. Onboard Token Logic
2. Deposit Token integration
3. Withdraw Token integration
4. Set the Contract as a guarded contract on your Guardian

#### Example Integration

```bash
contract MockDeFi {
    using SafeERC20 for IERC20;
    IGuardian guardian;

    function setGuardian(address _guardian) external {
        guardian = IGuardian(_guardian);
    }

    function deposit(address token, uint256 amount) external {
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        guardian.recordInflow(token, amount);
    }

    function withdraw(address token, uint256 amount) external {
        IERC20(token).safeTransfer(address(guardian), amount);
        guardian.withdraw(token, amount, msg.sender);
    }
}
```

## Contributors

## License

The smart contract is licensed under the UNLICENSED license.

**Note:** The provided smart contract is a simplified example and might not cover all security considerations and edge cases. It is always recommended to conduct a thorough security review and testing before deploying any smart contract in a production environment.
