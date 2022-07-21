//SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import "openzeppelin/contracts/token/ERC20/ERC20.sol";
import "openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IMugen.sol";

contract Mugen is ERC20, Ownable, IMugen {
    constructor() ERC20("Mugen", "MGN") {}

    function mint(address _to, uint256 _amount) external override onlyOwner {
        _mint(_to, _amount);
    }
}
