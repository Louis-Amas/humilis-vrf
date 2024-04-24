// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "@openzeppelin/interfaces/IERC1363.sol";

import {VRFCoordinator} from "../src/VRFCoordinator.sol";
import {VRF} from "../src/VRF.sol";
import {ERC1363Mock} from "./ERC1363Mock.sol";
import {MockRandom} from "./MockRandom.sol";

contract VRFCoordinatorTest is Test {
  uint[2] public publicKey = VRF.decodePoint(hex"032C8C31FC9F990C6B55E3865A184A4CE50E09481F2EAEB3E60EC1CEA13A6AE645");

  VRFCoordinator public coordinator;
  IERC1363 public feeToken;
  uint64 public subId;
  MockRandom public mockRandom;

  function setUp() public {
    feeToken = IERC1363(address(new ERC1363Mock("Test", "TST")));
    coordinator = new VRFCoordinator(publicKey, feeToken, 100);

    mockRandom = new MockRandom(coordinator, feeToken, 1, 100_000);
  }

  function createSubscription() public {
    subId = coordinator.createSubscription();
  }

  function addConsumer(address consumer) public {
    createSubscription();
    coordinator.addConsumer(subId, consumer);
  }

  function testCreateSubscription() public {
    createSubscription();
    assert(subId == 1);
  }

  function testAddConsumer() public {
    addConsumer(address(this));

    (uint96 balance, uint64 reqCount, address owner) = coordinator.subscriptions(subId);
    assert(owner == address(this));
    assert(reqCount == 0);
    assert(balance == 0);
  }

  function fundSubscription(uint amount) public {
    addConsumer(address(this));
    feeToken.transferAndCall(address(coordinator), amount, abi.encode(subId));
  }

  function testFund() public {
    uint amount = 1000;
    fundSubscription(amount);
    (uint96 balance,,) = coordinator.subscriptions(subId);

    assert(balance == amount);
  }

  function testRandomWordsRequested() public {
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

  function testMockRandom() public {
    deal(address(feeToken), address(mockRandom), 1 ether);

    mockRandom.initialize();
    mockRandom.fundSubscription(0.5 ether);

    uint requestId = mockRandom.getRandom();

    uint[4] memory proof = VRF.decodeProof(
      hex"0252eef5f1c0d7d44f3e5f6c76b1641334f04513c6a9373b39b70ad85169f352ba5c63ea3d06b3900f1e2b19fb26b7aad43ff01d7962c4d4d5b3556cff839beb8637886f9b07d66f79ab37e15133a906c5"
    );

    coordinator.fullfillRandomness(proof, requestId);
    assertNotEq(mockRandom.randomValues(requestId), 0);
  }
}
