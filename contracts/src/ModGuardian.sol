pragma solidity ^0.8.13;

contract ModGuardian {

    uint counter =0;

    function check() public returns(uint) {
        counter++;
        return counter;
    }
}
/*
contract PoolOne is Guardian {
   function hi() public returns(uint) {
      // do withdraw here
      return check();
   }
}

contract PoolTwo is Guardian {
   function hi() public returns(uint) {
      // do withdraw here
      return check();
   }
}*/