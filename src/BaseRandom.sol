// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "@openzeppelin/interfaces/IERC1363.sol";
import "@openzeppelin/access/Ownable.sol";
import "@chainlink/v0.8/vrf/VRFConsumerBaseV2.sol";

import {VRFCoordinatorV2Interface} from "@chainlink/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";

abstract contract BaseRandom is VRFConsumerBaseV2, Ownable(msg.sender) {
  bytes32 internal keyHash;
  uint8 public minimumConfirmations;
  uint32 public gasreq;
  VRFCoordinatorV2Interface public coordinator;
  IERC1363 public feeToken;

  uint64 public chainlinkSubId;

  constructor(
    VRFCoordinatorV2Interface _VRFCoordinator,
    IERC1363 _feeToken,
    uint8 _minimumConfirmations,
    uint32 _gasreq
  ) VRFConsumerBaseV2(address(_VRFCoordinator)) {
    coordinator = _VRFCoordinator;
    feeToken = _feeToken;
    minimumConfirmations = _minimumConfirmations;
    gasreq = _gasreq;
  }

  modifier isInitialized() {
    require(chainlinkSubId != 0, "Chainlink VRF is not initialized");
    _;
  }

  function initialize() public onlyOwner {
    chainlinkSubId = coordinator.createSubscription();
    coordinator.addConsumer(chainlinkSubId, address(this));
  }

  function fundSubscription(uint amount) public onlyOwner {
    feeToken.transferAndCall(address(coordinator), amount, abi.encode(chainlinkSubId));
  }

  function requestRandomNumber() internal isInitialized returns (uint) {
    return coordinator.requestRandomWords(keyHash, chainlinkSubId, minimumConfirmations, gasreq, 1);
  }
}
