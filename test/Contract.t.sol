// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/PoolOne.sol";
import "../src/PoolTwo.sol";

contract ContractTest is Test {

    PoolOne myPoolOne;
    PoolTwo myPoolTwo;

    function setUp() public {
        myPoolOne = new PoolOne();
        myPoolTwo = new PoolTwo();
    }

    function testExample() public {
       uint res = myPoolOne.hi();
       assertEq(res, 1);
       uint resTwo = myPoolTwo.hi();
       assertEq(resTwo, 1);
    }
}