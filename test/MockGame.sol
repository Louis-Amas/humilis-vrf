// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "../src/BaseGame.sol";

contract MockGame is BaseGame {
  mapping(uint => uint) public randomValues;

  constructor(
    VRFCoordinatorV2Interface _VRFCoordinator,
    IERC1363 _feeToken,
    uint8 _minimumConfirmations,
    uint32 _gasreq
  ) BaseGame(_VRFCoordinator, _feeToken, _minimumConfirmations, _gasreq) {}

  function getRandom() public returns (uint) {
    return requestRandomNumber();
  }

  function fulfillRandomWords(uint requestId, uint[] memory randomWords) internal override {
    randomValues[requestId] = randomWords[0];
  }
}
