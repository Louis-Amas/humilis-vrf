// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {VRF} from "../src/VRF.sol";

contract CounterTest is Test {
  function setUp() public {}

  uint[2] public_key = VRF.decodePoint(hex"032C8C31FC9F990C6B55E3865A184A4CE50E09481F2EAEB3E60EC1CEA13A6AE645");

  function test_verify() public view {
    uint[4] memory proof = VRF.decodeProof(
      hex"031f4dbca087a1972d04a07a779b7df1caa99e0f5db2aa21f3aecc4f9e10e85d08748c9fbe6b95d17359707bfb8e8ab0c93ba0c515333adcb8b64f372c535e115ccf66ebf5abe6fadb01b5efb37c0a0ec9"
    );

    bytes memory test = "sample";
    bool result = VRF.verify(public_key, proof, test);

    assertEq(result, true);
  }

  function test_verify_with_bytes() public view {
    uint[4] memory proof = VRF.decodeProof(
      hex"03941926b48557ca73e6a47e73f29f11bb6af60b7c7fe586e70be80fb6c94b095dbc4d7c222b6111026b487ab4f4736405327682469dbe72077681d8666956365068ed12013ca368cfc0eab59d9bf3cfe4"
    );

    bytes memory test = hex"1fb983642f14dbbed8a2dbd79a68c7cb33830bdf1b8474529e3b2aa0c6dc1f03";
    bool result = VRF.verify(public_key, proof, test);
    assertEq(result, true);
  }
}
