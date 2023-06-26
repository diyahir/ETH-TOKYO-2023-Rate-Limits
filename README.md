# DeFi Circuit Breaker: Token Rate-limits for your DeFi Protocol

## Features

- Protocol Agnositic approach to ERC20/Native rate-limiting
- Performant Codebase
- Multiple tokens supports with custom withdrawal rate limits for each token.
- Records inflows/outflows of token and maintains a Historical running total of the protocol's token liquidity.
- Enforces withdrawal limits and periods to prevent total fund drainage (hack mitigation).
- Allows the contract owner to register tokens, override limits, and transfer admin privileges.

## Integration

There are easy points of integration that you must do to have your protocol circuitBreaker properly set up.

1. Instantiate Circuit Breaker contract with appropriate constructor params
2. Register circuit breaker params for each desired token
3. Add protected contracts to circuit breaker
4. Enjoy enhanced safety

#### Example CircuitBreaker Integration

```bash
contract MockDeFiProtocol is ProtectedContract {
    using SafeERC20 for IERC20;

    constructor(address _circuitBreaker) ProtectedContract(_circuitBreaker) {}

    /*
     * @notice Use cbInflowSafeTransferFrom to safe transfer tokens and record inflow to circuit-breaker
     */
    function deposit(address _token, uint256 _amount) external {
        cbInflowSafeTransferFrom(_token, msg.sender, address(this), _amount);

        // Your logic here
    }

    /*
     * @notice Withdrawal hook for circuit breaker to safe transfer tokens and enforcement
     */
    function withdrawal(address _token, uint256 _amount) external {
        //  Your logic here

        cbOutflowSafeTransfer(_token, _amount, msg.sender, false);
    }
}

```

#### Example smart contract consumer

```bash
contract MockDeFiConsumer {
    ICircuitBreaker circuitBreaker;
    IMockDeFi defi;

    error RateLimited();

    function onTokenOutflow(address token, uint256 amount) external {
        defi.onTokenOutflow(address token, uint256 amount);
        if(circuitBreaker.isRateLimited()){
            revert RateLimited()
        }
        # If there is no revertOnRateLimit flag in the defi protocol
        # You need to revert in your smart contract to have consistent accounting
    }
}
```

## Testing

```bash
forge test
```

![DeFi CircuitBreaker](https://github.com/Hydrogen-Labs/DeFi-Guardian/assets/32445955/07c89cad-2045-448c-b1d9-bd93ab804253)
![Rate limit](https://github.com/Hydrogen-Labs/DeFi-Guardian/assets/32445955/87bf266d-7a1d-44d3-b7d1-1d6868013a2a)

## Contributors

## License

Copyright and related rights waived via [CC0](/LICENSE).
