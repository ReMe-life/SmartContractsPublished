pragma solidity ^0.6.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.2.0/contracts/token/ERC20/ERC20.sol";
contract ReMCToken is ERC20 {
    constructor(
        string memory name,
        string memory symbol,
        address tokenDistributor,
        uint256 premintedAmount
    ) public ERC20(name, symbol) {
        _mint(tokenDistributor, premintedAmount);
    }
}

