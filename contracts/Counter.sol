// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.23;

contract Counter {

    uint256 public number;
    uint256 public duplicate;

    function setNumber(uint256 newNumber) public {
        number = newNumber;
    }

    function increment() public {
        number++;
        duplicate = duplicate + duplicate + duplicate;
    }
}
