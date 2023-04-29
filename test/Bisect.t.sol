// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {Timestamped, Bisect} from "../src/RateLimit.sol";

contract BisectTest is Test {
  using Bisect for Timestamped[];
  Timestamped[] internal _history;
  function testBisect(uint8 length, uint8 skip, uint8 span) external {
    if (length > 8) {
      // keep the problem size manageable
      span = uint8(bound(span, 0, 2048 / uint256(length)));
    }
    for (uint40 i; i < length; i++) {
      _history.push(Timestamped(i * span + skip, i));
    }
    for (uint40 i = skip; i < uint40(length) * span + skip; i++) {
      (bool success, Timestamped storage found) = _history.bisect(i);
      assertTrue(success);
      assertEq(found.value, (i-skip)/span);
    }
    if (skip > 0) {
      (bool success, ) = _history.bisect(skip - 1);
      assertFalse(success);
    }
    if (length > 0) {
      (bool success, Timestamped storage found) = _history.bisect(uint40(length) * span + skip);
      assertTrue(success);
      assertEq(found.value, length - 1);
    }
  }
}
