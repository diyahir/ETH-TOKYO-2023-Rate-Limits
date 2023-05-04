pragma solidity ^0.8.13;

import "./ModGuardian.sol";

contract PoolOne is ModGuardian {
    function hi() public returns (uint) {
        // do withdraw here
        return check();
    }
}
