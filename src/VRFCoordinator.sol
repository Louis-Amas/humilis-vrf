pragma solidity ^0.8.13;

import {VRFCoordinatorV2Interface} from "@chainlink/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import "@openzeppelin/interfaces/IERC1363.sol";
import "@openzeppelin/interfaces/IERC1363Receiver.sol";
import "@chainlink/v0.8/vrf/VRFConsumerBaseV2.sol";

import "forge-std/console.sol";

import "./Utils.sol";

import {VRF} from "./VRF.sol";

contract VRFCoordinator is VRFCoordinatorV2Interface, IERC1363Receiver {
  IERC1363 public feeToken;
  uint[2] public publicKey;
  uint public gasPriceMwei;
  uint64 public globalSubId = 0;

  error RandomRequestAlreadyFulfilled(uint requestId);
  error ProofInvalid();
  error RequestIdInvalid();
  error NotAConsumer();
  error SubscriptionInvalid();
  error minimumRequestConfirmationsToBig();
  error tooMuchWords();

  constructor(uint[2] memory _publicKey, IERC1363 _feeToken, uint _gasPriceMwei) {
    publicKey = _publicKey;
    feeToken = _feeToken;
    gasPriceMwei = _gasPriceMwei;
  }

  struct Subscription {
    uint96 balance;
    uint64 reqCount;
    address owner;
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
  mapping(uint => mapping(address => bool)) public consumers;
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

  event RandomWordsRequested(RandomRequest request);

  function requestRandomWords(
    bytes32, /*keyHash ignore keyasg */
    uint64 subId,
    uint16 minimumRequestConfirmations,
    uint32 callbackGasLimit,
    uint32 numWords
  ) external returns (uint requestId) {
    Subscription storage sub = subscriptions[subId];

    if (sub.owner == address(0)) {
      revert SubscriptionInvalid();
    }

    if (consumers[subId][msg.sender] != true) {
      revert NotAConsumer();
    }

    if (minimumRequestConfirmations > 128) {
      revert minimumRequestConfirmationsToBig();
    }

    if (numWords != 1) {
      revert tooMuchWords();
    }

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
    returns (uint96 balance, uint64 reqCount, address owner, address[] memory)
  {
    Subscription storage sub = subscriptions[subId];
    return (sub.balance, sub.reqCount, sub.owner, new address[](0));
  }

  function requestSubscriptionOwnerTransfer(uint64, /*subId*/ address /*newOwner*/ ) external {
    revert("not implemented");
  }

  function acceptSubscriptionOwnerTransfer(uint64 /*subId*/ ) external {
    revert("not implemented");
  }

  modifier isSubscriptionOwner(uint64 subId) {
    require(subscriptions[subId].owner == msg.sender, "Only the owner can add a consumer");
    _;
  }

  function addConsumer(uint64 subId, address consumer) external isSubscriptionOwner(subId) {
    consumers[subId][consumer] = true;
  }

  function removeConsumer(uint64 subId, address consumer) external isSubscriptionOwner(subId) {
    delete consumers[subId][consumer];
  }

  function cancelSubscription(uint64 subId, address /*to*/ ) external {
    Subscription storage sub = subscriptions[subId];
    require(sub.owner == msg.sender, "Only the owner can cancel the subscription");
    delete subscriptions[subId];
  }

  function pendingRequestExists(uint64 /*subId*/ ) external pure returns (bool) {
    return false;
  }

  function onTransferReceived(address, /*operator*/ address, /*from*/ uint amount, bytes memory data)
    external
    returns (bytes4)
  {
    uint64 subId = abi.decode(data, (uint64));
    Subscription storage sub = subscriptions[subId];
    sub.balance += uint96(amount);

    return VRFCoordinator.onTransferReceived.selector;
  }

  function verifyRandomProof(uint[4] memory proof, uint requestId) internal {
    RequestDetails storage requestDetails = requests[requestId];
    if (requestDetails.fullfilled) {
      revert RandomRequestAlreadyFulfilled(requestId);
    }

    uint recoverRequestId = computeRequestId(requestDetails.request);
    if (recoverRequestId != requestId) {
      revert RequestIdInvalid();
    }

    if (!VRF.verify(publicKey, proof, abi.encodePacked(requestId))) {
      revert ProofInvalid();
    }

    requestDetails.fullfilled = true;
  }

  function fullfillRandomness(uint[4] memory proof, uint requestId) public {
    uint gasBeforeCall = gasleft();
    verifyRandomProof(proof, requestId);

    uint randomness = uint(keccak256(abi.encode(proof[0], proof[1])));
    uint[] memory array = new uint[](1);
    array[0] = randomness;

    VRFConsumerBaseV2 requestor = VRFConsumerBaseV2(requests[requestId].request.sender);

    // call the user callback with their specified gas limit. Do not revert if the call revert.
    Utils.controlledCall(
      address(requestor),
      requests[requestId].request.callbackGasLimit,
      abi.encodeCall(requestor.rawFulfillRandomWords, (requestId, array))
    );

    Subscription storage sub = subscriptions[requests[requestId].request.subId];

    uint gasSpent = gasBeforeCall - gasleft();
    sub.balance -= uint96(gasSpent * (gasPriceMwei * 10 ** 6)); // assuming feeToken is gasToken
  }
}
