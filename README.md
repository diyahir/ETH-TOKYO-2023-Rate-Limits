# DeFi CircuitBreaker: Token rate-limits for your DeFi Protocol

![Defi_CircuitBreaker11](https://github.com/Hydrogen-Labs/DeFi-CircuitBreaker/assets/10442269/10ee3de0-ff92-4d1d-8557-1d859c91199c)

## Features

- Protocol Agnositic approach to token rate limiting
- Performant Codebase
- Easy integration
- Multiple tokens supports with custom withdrawal rate limits and periods for each token.
- Records inflows/outflows of token and maintains a Historical running total of the protocol's token liquidity.
- Enforces withdrawal limits and periods to prevent total fund drainage (hack mitigation).
- Allows the contract owner to register tokens, override limits, and transfer admin privileges.

![Rate limit](https://github.com/Hydrogen-Labs/DeFi-CircuitBreaker/assets/32445955/87bf266d-7a1d-44d3-b7d1-1d6868013a2a)
![DeFi CircuitBreaker](https://github.com/Hydrogen-Labs/DeFi-CircuitBreaker/assets/32445955/07c89cad-2045-448c-b1d9-bd93ab804253)

## Testing

```bash
forge test
```

## Integration

There are three easy points of integration that you must do to have your protocol circuitBreaker properly set up.

1. Onboard Token Logic
2. Deposit Token integration
3. Withdraw Token integration
4. Set the Contract as a protected contract on your CircuitBreaker

#### Example CircuitBreaker Integration

```bash
contract MockDeFiProtocol is ProtectedContract {
    using SafeERC20 for IERC20;

    constructor(address _circuitBreaker) ProtectedContract(_circuitBreaker) {}

    /*
     * @notice Use _depositHook to safe transfer tokens and record inflow to circuit-breaker
     */
    function deposit(address _token, uint256 _amount) external {
        _depositHook(_token, msg.sender, address(this), _amount);

        // Your logic here
    }

    /*
     * @notice Withdrawal hook for circuit breaker to safe transfer tokens and enforcement
     */
    function withdrawal(address _token, uint256 _amount) external {
        //  Your logic here

        _withdrawalHook(_token, _amount, msg.sender, false);
    }
}

```

#### Example smart contract consumer

```bash
contract MockDeFiConsumer {
    ICircuitBreaker circuitBreaker;
    IMockDeFi defi;

    error RateLimited();

    function withdrawalHook(address token, uint256 amount) external {
        defi.withdrawalHook(address token, uint256 amount);
        if(circuitBreaker.isRateLimited()){
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
