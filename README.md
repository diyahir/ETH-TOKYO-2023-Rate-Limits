# DeFi Guardian: Token rate-limits for your DeFi Protocol

![Defi_Guardian11](https://github.com/Hydrogen-Labs/DeFi-Guardian/assets/10442269/10ee3de0-ff92-4d1d-8557-1d859c91199c)

## Features

- Protocol Agnositic approach to token rate limiting
- Performant Codebase
- Easy integration
- Multiple tokens supports with custom withdrawal rate limits and periods for each token.
- Records inflows/outflows of token and maintains a Historical running total of the protocol's token liquidity.
- Enforces withdrawal limits and periods to prevent total fund drainage (hack mitigation).
- Allows the contract owner to register tokens, override limits, and transfer admin privileges.


![Rate limit](https://github.com/Hydrogen-Labs/DeFi-Guardian/assets/32445955/87bf266d-7a1d-44d3-b7d1-1d6868013a2a)
![DeFi Guardian](https://github.com/Hydrogen-Labs/DeFi-Guardian/assets/32445955/07c89cad-2045-448c-b1d9-bd93ab804253)

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

#### Example Guardian Integration

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

#### Example smart contract consumer

```bash
contract MockDeFiConsumer {
    IGuardian guardian;
    IMockDeFi defi;

    error RateLimited();

    function withdraw(address token, uint256 amount) external {
        defi.withdraw(address token, uint256 amount);
        if(guardian.isRateLimited()){
            revert RateLimited()
        }
        # If there is no revertOnRateLimit flag be the defi protocol
        # You need to revert in your smart contract to have consistent accounting
    }
}
```

## Contributors

## License

This is free and unencumbered software released into the public domain.

Anyone is free to copy, modify, publish, use, compile, sell, or
distribute this software, either in source code form or as a compiled
binary, for any purpose, commercial or non-commercial, and by any
means.

In jurisdictions that recognize copyright laws, the author or authors
of this software dedicate any and all copyright interest in the
software to the public domain. We make this dedication for the benefit
of the public at large and to the detriment of our heirs and
successors. We intend this dedication to be an overt act of
relinquishment in perpetuity of all present and future rights to this
software under copyright law.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

For more information, please refer to <https://unlicense.org>
