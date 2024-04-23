// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {VRF} from "../src/VRF.sol";

contract CounterTest is Test {
    function setUp() public {}

    function test_verify() public pure {
        uint256[2] memory public_key =
            VRF.decodePoint(hex"032C8C31FC9F990C6B55E3865A184A4CE50E09481F2EAEB3E60EC1CEA13A6AE645");

        uint256[4] memory proof = VRF.decodeProof(
            hex"031f4dbca087a1972d04a07a779b7df1caa99e0f5db2aa21f3aecc4f9e10e85d08748c9fbe6b95d17359707bfb8e8ab0c93ba0c515333adcb8b64f372c535e115ccf66ebf5abe6fadb01b5efb37c0a0ec9"
        );

        bytes memory test = "sample";

        bool result = VRF.verify(public_key, proof, test);

        assertEq(result, true);
    }
}
