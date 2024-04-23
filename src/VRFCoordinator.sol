pragma solidity ^0.8.13;

import {VRFCoordinatorV2Interface} from "@chainlink/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import "@openzeppelin/interfaces/IERC1363.sol";
import "@openzeppelin/interfaces/IERC1363Receiver.sol";

import {VRF} from "./VRF.sol";

contract VRFCoordinator is VRFCoordinatorV2Interface, IERC1363Receiver {
  IERC1363 feeToken;
  uint[2] public publicKey;

  uint64 globalSubId = 0;

  constructor(uint[2] memory _publicKey, IERC1363 _feeToken) {
    publicKey = _publicKey;
    feeToken = _feeToken;
  }

  struct Subscription {
    uint96 balance;
    uint64 reqCount;
    address owner;
    address[] consumers;
  }

  struct RandomRequest {
    uint64 subId;
    uint16 minimumRequestConfirmations;
    uint32 callbackGasLimit;
    uint32 numWords;
    uint blockNumber;
    address sender;
  }

  struct RequestDetails {
    RandomRequest request;
    bool fullfilled;
  }

  mapping(uint64 => Subscription) public subscriptions;
  mapping(uint => RequestDetails) public requests;

  function computeRequestId(RandomRequest memory request) public pure returns (uint) {
    return uint(
      keccak256(
        abi.encodePacked(
          request.subId,
          request.minimumRequestConfirmations,
          request.callbackGasLimit,
          request.numWords,
          request.blockNumber,
          request.sender
        )
      )
    );
  }

  function getRequestConfig() external view returns (uint16, uint32, bytes32[] memory) {
    return (0, 0, new bytes32[](0));
  }

  function getRequest(uint requestId) public view returns (RandomRequest memory) {
    return requests[requestId].request;
  }

  event RandomWordsRequested(RandomRequest request);

  function requestRandomWords(
    bytes32, /*keyHash ignore keyasg */
    uint64 subId,
    uint16 minimumRequestConfirmations,
    uint32 callbackGasLimit,
    uint32 numWords
  ) external returns (uint requestId) {
    Subscription storage sub = subscriptions[subId];
    require(sub.owner == msg.sender, "Subscription doesn't exist or you don't own it");
    require(minimumRequestConfirmations < 128, "Max 128 block");
    require(numWords == 1, "Max 1 words");

    sub.reqCount++;

    RandomRequest memory request =
      RandomRequest(subId, minimumRequestConfirmations, callbackGasLimit, numWords, block.number, msg.sender);
    requestId = computeRequestId(request);
    requests[requestId] = RequestDetails(request, false);
    emit RandomWordsRequested(requests[requestId].request);
  }

  function createSubscription() external returns (uint64 subId) {
    subId = ++globalSubId;

    Subscription storage sub = subscriptions[subId];
    sub.owner = msg.sender;
  }

  function getSubscription(uint64 subId)
    external
    view
    returns (uint96 balance, uint64 reqCount, address owner, address[] memory consumers)
  {
    Subscription storage sub = subscriptions[subId];
    return (sub.balance, sub.reqCount, sub.owner, sub.consumers);
  }

  function requestSubscriptionOwnerTransfer(uint64, /*subId*/ address /*newOwner*/ ) external {
    revert("not implemented");
  }

  function acceptSubscriptionOwnerTransfer(uint64 /*subId*/ ) external {
    revert("not implemented");
  }

  function addConsumer(uint64 subId, address consumer) external {
    require(subscriptions[subId].owner == msg.sender, "Only the owner can add a consumer");
    subscriptions[subId].consumers.push(consumer);
  }

  function removeConsumer(uint64 subId, address consumer) external {
    Subscription storage sub = subscriptions[subId];

    if (sub.consumers.length == 0) {
      return;
    }

    for (uint64 i = 0; i < sub.consumers.length; ++i) {
      if (sub.consumers[i] == consumer) {
        sub.consumers[i] = sub.consumers[sub.consumers.length - 1];
        sub.consumers.pop();
        return;
      }
    }
  }

  function cancelSubscription(uint64 subId, address /*to*/ ) external {
    Subscription storage sub = subscriptions[subId];
    require(sub.owner == msg.sender, "Only the owner can cancel the subscription");
    delete subscriptions[subId];
  }

  function pendingRequestExists(uint64 /*subId*/ ) external pure returns (bool) {
    return false;
  }

  function onTransferReceived(address operator, address from, uint amount, bytes memory data) external returns (bytes4) {
    uint64 subId = abi.decode(data, (uint64));
    Subscription storage sub = subscriptions[subId];
    sub.balance += uint96(amount);

    return VRFCoordinator.onTransferReceived.selector;
  }

  function verifyRandomProof(uint[4] memory proof, uint requestId) public {
    uint recoverRequestId = computeRequestId(getRequest(requestId));
    require(recoverRequestId == requestId, "Invalid requestId");

    require(VRF.verify(publicKey, proof, abi.encodePacked(requestId)), "Proof is not valid");

    // uint randomNumber = keccak256(abi.encode(proof[0], proof[1]));
  }
}
