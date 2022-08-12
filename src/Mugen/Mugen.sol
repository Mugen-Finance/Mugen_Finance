//SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import "openzeppelin/contracts/token/ERC20/ERC20.sol";
import "openzeppelin/contracts/utils/introspection/IERC165.sol";
import "./OFTCore.sol";
import "../interfaces/IMugen.sol";

contract Mugen is OFTCore, ERC20, IMugen {
    constructor(address _lzEndpoint)
        ERC20("Mugen", "MGN")
        OFTCore(_lzEndpoint)
    {}

    function mint(address _to, uint256 _amount) external override onlyOwner {
        _mint(_to, _amount);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(OFTCore, IERC165)
        returns (bool)
    {
        return
            interfaceId == type(IMugen).interfaceId ||
            interfaceId == type(IERC20).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function circulatingSupply()
        public
        view
        virtual
        override
        returns (uint256)
    {
        return totalSupply();
    }

    function _debitFrom(
        address _from,
        uint16,
        bytes memory,
        uint256 _amount
    ) internal virtual override {
        address spender = _msgSender();
        if (_from != spender) _spendAllowance(_from, spender, _amount);
        _burn(_from, _amount);
    }

    function _creditTo(
        uint16,
        address _toAddress,
        uint256 _amount
    ) internal virtual override {
        _mint(_toAddress, _amount);
    }
}
