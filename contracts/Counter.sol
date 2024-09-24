// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.26;

contract Counter {

    uint256 public number;
    uint256 public duplicate;

    function setNumber(
        uint256 _newNumber
    )
        external
    {
        number = _newNumber;
    }

    function increment()
        public
    {
        number++;

        duplicate = duplicate
            + duplicate
            + duplicate;
    }
}
