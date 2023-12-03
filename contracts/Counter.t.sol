// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.23;

import "lib/forge-std/src/Test.sol";
import "./Counter.sol";

contract CounterTest is Test {

    Counter public counter;

    function setUp()
        public
    {
        counter = new Counter();
        counter.setNumber(0);
    }

    function testIncrement()
        public
    {
        counter.increment();
        assertEq(counter.number(), 1);
    }

    function testSetNumber(uint256 x)
        public
    {
        counter.setNumber(x);
        assertEq(counter.number(), x);
    }
}
