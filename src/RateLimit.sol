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
    // want to find the last element at/after the needle. In this search you
    // want to find the first element at/before the needle.
    unchecked {
      uint256 start;
      uint256 stop;
      {
        uint256 length = haystack.length;
        assembly ("memory-safe") {
          mstore(0x00, haystack.slot)
          start := keccak256(0x00, 0x20)
        }
        if (length == 0) {
          return (false, _deref(start - 1));
        }
        stop = start + length;
      }

      uint256 lo;
      uint256 hi;
      // To avoid accessing extra state, we bias our search towards the end
      // of the list. This does not affect the asymptotic gas, but gives
      // better constants when "hotter" data is searched for.
      (lo, hi) = (stop - 2, stop - 1);
      while (true) {
        if (lo < start || lo > stop) { // TODO: condition `lo > stop` is probably unnecessary, given that `start` is a hash value
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

      if (lo < start || lo > stop) { // TODO: see above
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
    (foundTime, foundValue) = (found.time, found.value);
  }

  function _rateLimit(uint216 requested) internal returns (uint216 allowed) {
    (uint40 currentTime, uint216 currentValue) = (rateLimitCurrent.time, rateLimitCurrent.value);
    if (currentTime > 0 && currentTime < block.timestamp) {
      _history.push(Timestamped(currentTime, currentValue));
    }
    allowed = rateLimitSettings.value;
    unchecked {
      (bool success, Timestamped storage found) = _history.bisect(uint40(block.timestamp) - rateLimitSettings.time);
      if (success) {
        allowed += found.value;
      }
      allowed -= currentValue;
    }
    if (requested < allowed) {
      allowed = requested;
    }
    (rateLimitCurrent.time, rateLimitCurrent.value) = (uint40(block.timestamp), currentValue + allowed);
  }
}
