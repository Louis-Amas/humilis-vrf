// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "@openzeppelin/interfaces/IERC1363.sol";
import "@openzeppelin/access/Ownable.sol";
import "@chainlink/v0.8/vrf/VRFConsumerBaseV2.sol";

import {VRFCoordinatorV2Interface} from "@chainlink/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";

abstract contract BaseGame is VRFConsumerBaseV2, Ownable(msg.sender) {
  bytes32 internal keyHash;
  uint internal fee;
  uint public randomResult;
  VRFCoordinatorV2Interface public vrfCoordinator;
  IERC1363 public feeToken;

  uint64 chainlinkSubId;

  constructor(VRFCoordinatorV2Interface _VRFCoordinator, IERC1363 _feeToken, bytes32 _keyHash, uint _fee)
    VRFConsumerBaseV2(address(_VRFCoordinator))
  {
    vrfCoordinator = _VRFCoordinator;
    feeToken = _feeToken;
    keyHash = _keyHash;
    fee = _fee;
  }

  modifier isInitialized() {
    require(chainlinkSubId != 0, "Chainlink VRF is not initialized");
    _;
  }

  function initialize() public onlyOwner {
    chainlinkSubId = vrfCoordinator.createSubscription();
    vrfCoordinator.addConsumer(chainlinkSubId, address(this));
  }

  function fundSubscription(uint amount) public onlyOwner {
    feeToken.transferAndCall(address(vrfCoordinator), amount, abi.encode(chainlinkSubId));
  }

  function getRandomNumber() public isInitialized returns (bytes32 requestId) {
    revert("Not implemented");
    // require(feeToken.balanceOf(address(this)) >= fee, "Not enough feeToken");
    // return vrfCoordinator.requestRandomness(keyHash, fee);
  }
}
