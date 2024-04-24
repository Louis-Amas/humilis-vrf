// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

library Utils {
  function controlledCall(address callee, uint32 gasreq, bytes memory cd) internal returns (bool success, bytes32 data) {
    unchecked {
      bytes32[4] memory retdata;

      /* if success, read returned bytes 1..32, otherwise read returned bytes 69..100. */
      assembly ("memory-safe") {
        success := call(gasreq, callee, 0, add(cd, 32), mload(cd), retdata, 100)
        data := mload(add(mul(iszero(success), 68), retdata))
      }
    }
  }
}
