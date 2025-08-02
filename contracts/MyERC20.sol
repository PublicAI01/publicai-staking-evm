//SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyERC20 is ERC20,Ownable{
    uint8 private _decimals;
    constructor(string memory name_,string memory symbol_) ERC20(name_,symbol_){
    }

    function mint(address receiver,uint256 amount) public onlyOwner{
        super._mint(receiver,amount);
        _decimals = super.decimals();
    }
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }
    function setDecimals(uint8 _decimal) external {
        _decimals = _decimal;
    }
}