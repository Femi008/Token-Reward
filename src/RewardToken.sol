// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;


import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 * @title RewardToken
 * @notice ERC20 token with capped supply for task rewards
 */
contract RewardToken is ERC20, Ownable {
    uint256 public immutable cap;
    
    event TokensMinted(address indexed to, uint256 amount);
    
    constructor(
        string memory name,
        string memory symbol,
        uint256 _cap,
        address initialOwner
    ) ERC20(name, symbol) Ownable(initialOwner) {
        require(_cap > 0, "Cap must be greater than 0");
        cap = _cap;
    }
    
    function mint(address to, uint256 amount) external onlyOwner {
        require(totalSupply() + amount <= cap, "Cap exceeded");
        _mint(to, amount);
        emit TokensMinted(to, amount);
    }
    
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}

