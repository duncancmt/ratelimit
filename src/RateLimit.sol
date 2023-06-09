// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.19;

struct Timestamped {
  uint40 time;
  uint216 value;
}

library Bisect {
  function _deref(uint256 ptr) private pure returns (Timestamped storage result) {
    assembly ("memory-safe") {
      result.slot := ptr
    }
  }

  function bisect(Timestamped[] storage haystack, uint40 needle)
    internal
    view
    returns (bool, Timestamped storage)
  {
    // This is an awkward bisection search. In a normal bisection search, you
    // want to find the first element after the needle. In this search we want
    // at/before the needle.
    unchecked {
      uint256 start;
      uint256 lo;
      uint256 hi;
      {
        uint256 length = haystack.length;
        assembly ("memory-safe") {
          mstore(0x00, haystack.slot)
          start := keccak256(0x00, 0x20)
        }
        if (length == 0) {
          return (false, _deref(start - 1));
        }
        uint256 stop = start + length;
        (lo, hi) = (stop - 2, stop - 1);
      }

      // To avoid accessing extra state, we bias our search towards the end
      // of the list. This does not affect the asymptotic gas, but gives
      // better constants when "hotter" data is searched for.
      while (true) {
        if (lo < start) {
          lo = start - 1;
          break;
        } else if (_deref(lo).time <= needle) {
          break;
        }
        (lo, hi) = (lo - ((hi - lo) << 1), lo);
      }

      // Peform the regular binary search.
      while (lo < hi) {
        uint256 mid = hi - ((hi - lo) >> 1); // round up
        if (_deref(mid).time <= needle) {
          lo = mid;
        } else {
          hi = mid - 1;
        }
      }
      // lo == hi

      if (lo < start) {
        return (false, _deref(start - 1));
      }
      return (true, _deref(lo));
    }
  }
}

abstract contract RateLimit {
  using Bisect for Timestamped[];

  Timestamped public rateLimitSettings;
  Timestamped public rateLimitCurrent;
  Timestamped[] private _history;

  function history(uint40 time) public view returns (bool success, uint40 foundTime, uint216 foundValue) {
    Timestamped storage found;
    (success, found) = _history.bisect(time);
    if (success) {
      (foundTime, foundValue) = (found.time, found.value);
    }
  }

  function _rateLimit(uint216 requested) internal returns (uint216 allowed) {
    unchecked {
      uint216 currentValue = rateLimitCurrent.value;
      (, , allowed) = history(uint40(block.timestamp) - rateLimitSettings.time);
      allowed += rateLimitSettings.value;
      allowed -= currentValue;
      if (requested < allowed) {
        allowed = requested;
      }
      if (allowed != 0) {
        if (rateLimitCurrent.time > 0 && rateLimitCurrent.time < block.timestamp) {
          _history.push(Timestamped(rateLimitCurrent.time, currentValue));
        }
        rateLimitCurrent.time = uint40(block.timestamp);
        rateLimitCurrent.value = currentValue + allowed;
      }
    }
  }
}
