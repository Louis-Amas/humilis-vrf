// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "@openzeppelin/interfaces/IERC1363.sol";

import {VRFCoordinator} from "../src/VRFCoordinator.sol";
import {VRF} from "../src/VRF.sol";
import {ERC1363Mock} from "./ERC1363Mock.sol";

contract VRFCoordinatorTest is Test {
  uint[2] publicKey = VRF.decodePoint(hex"032C8C31FC9F990C6B55E3865A184A4CE50E09481F2EAEB3E60EC1CEA13A6AE645");

  VRFCoordinator coordinator;
  IERC1363 feeToken;

  uint64 subId;

  function setUp() public {
    feeToken = IERC1363(address(new ERC1363Mock("Test", "TST")));
    coordinator = new VRFCoordinator(publicKey, feeToken);
  }

  function createSubscription() public {
    subId = coordinator.createSubscription();
  }

  function addConsumer() public {
    createSubscription();
    coordinator.addConsumer(subId, address(this));
  }

  function test_createSubscription() public {
    createSubscription();
    assert(subId == 1);
  }

  function test_addConsumer() public {
    addConsumer();

    (uint96 balance, uint64 reqCount, address owner) = coordinator.subscriptions(subId);
    assert(owner == address(this));
    assert(reqCount == 0);
    assert(balance == 0);
  }

  function fundSubscription(uint amount) public {
    addConsumer();
    feeToken.transferAndCall(address(coordinator), amount, abi.encode(subId));
  }

  function test_fund() public {
    uint amount = 1000;
    fundSubscription(amount);
    (uint96 balance,,) = coordinator.subscriptions(subId);

    assert(balance == amount);
  }

  function test_randomWordsRequested() public {
    fundSubscription(1000);

    vm.expectEmit();

    emit VRFCoordinator.RandomWordsRequested(
      VRFCoordinator.RandomRequest({
        subId: subId,
        minimumRequestConfirmations: 0,
        callbackGasLimit: 0,
        numWords: 1,
        blockNumber: block.number,
        sender: address(this)
      })
    );
    uint requestId = coordinator.requestRandomWords(0, subId, 0, 0, 1);

    (VRFCoordinator.RandomRequest memory request, bool fullfilled) = coordinator.requests(requestId);
    assert(request.subId == subId);
    assert(request.minimumRequestConfirmations == 0);
    assert(request.callbackGasLimit == 0);
    assert(request.numWords == 1);
    assert(request.blockNumber == block.number);
    assert(request.sender == address(this));
    assert(fullfilled == false);

    console.logBytes(abi.encode(requestId));
  }
}
