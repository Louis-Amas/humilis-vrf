// spdx-license-identifier: MIT

pragma solidity ^0.8.13;

import "@erc1363/token/ERC1363/ERC1363.sol";

contract ERC1363Mock is ERC1363 {
  constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

  receive() external payable {
    _mint(msg.sender, msg.value);
  }

  function withdraw(uint amount) external {
    _burn(msg.sender, amount);
  }
}
