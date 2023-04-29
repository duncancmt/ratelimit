// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {RateLimit} from "../src/RateLimit.sol";

contract RateLimitMock is RateLimit {
  function setRateLimitPeriod(uint40 newValue) external {
    rateLimitSettings.time = newValue;
  }
  function setRateLimitValue(uint216 newValue) external {
    rateLimitSettings.value = newValue;
  }
  function rateLimit(uint216 requested) external returns (uint216 allowed) {
    return _rateLimit(requested);
  }
}

contract TimestampKludge {
  function get() external view returns (uint256) {
    return block.timestamp;
  }
}

contract RateLimitTest is Test {
  RateLimitMock internal _rateLimit;
  TimestampKludge internal _timestamp;
  function setUp() external {
    _rateLimit = new RateLimitMock();
    _rateLimit.setRateLimitPeriod(1 days);
    _rateLimit.setRateLimitValue(10 wei);
    _timestamp = new TimestampKludge();
  }
  function testRateLimit() external {
    vm.warp(_timestamp.get() + 365 days);
    for (uint256 i; i < 10; i++) {
      assertEq(_rateLimit.rateLimit(1), 1, "got ratelimited too early");
      vm.warp(_timestamp.get() + 1 seconds);
    }
    (bool success, uint40 time, uint216 value) = _rateLimit.history(uint40(_timestamp.get()));
    assertTrue(success);
    assertNotEq(time, 0);
    assertNotEq(value, 0);
    assertEq(_rateLimit.rateLimit(1), 0, "ratelimit not applied");
    vm.warp(_timestamp.get() + 1 days + 1 seconds);
    assertEq(_rateLimit.rateLimit(1), 1, "ratelimit did not expire");
  }
}
