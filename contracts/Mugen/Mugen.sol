//SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "./OFTCore.sol";
import {IMugen} from "../interfaces/IMugen.sol";

contract Mugen is OFTCore, ERC20Votes, IMugen {
    error NotOwner();
    error MinterSet();

    address public minter;

    constructor(address _lzEndpoint) ERC20("Mugen", "MGN") ERC20Permit("Mugen") OFTCore(_lzEndpoint) {}

    function _afterTokenTransfer(address from, address to, uint256 amount) internal override (ERC20Votes) {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal override (ERC20Votes) {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount) internal override (ERC20Votes) {
        super._burn(account, amount);
    }

    function setTrustedRemote(uint16 _srcChainId, bytes calldata _srcAddress) external override (LzApp) onlyOwner {
        trustedRemoteLookup[_srcChainId] = _srcAddress;
        emit SetTrustedRemote(_srcChainId, _srcAddress);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override (OFTCore, IERC165) returns (bool) {
        return interfaceId == type(IMugen).interfaceId || interfaceId == type(IERC20).interfaceId
            || super.supportsInterface(interfaceId);
    }

    function circulatingSupply() public view virtual override returns (uint256) {
        return totalSupply();
    }

    function _debitFrom(address _from, uint16, bytes memory, uint256 _amount) internal virtual override {
        address spender = _msgSender();
        if (_from != spender) {
            _spendAllowance(_from, spender, _amount);
        }
        _burn(_from, _amount);
    }

    function _creditTo(uint16, address _toAddress, uint256 _amount) internal virtual override {
        _mint(_toAddress, _amount);
    }

    function mint(address _to, uint256 _amount) external override onlyMinter {
        _mint(_to, _amount);
    }

    function setMinter(address _minter) external onlyOwner {
        if (minter != address(0)) {
            revert MinterSet();
        }
        minter = _minter;
    }

    modifier onlyMinter() {
        require(msg.sender == minter || msg.sender == owner(), "Only minter can call this");
        _;
    }
}
