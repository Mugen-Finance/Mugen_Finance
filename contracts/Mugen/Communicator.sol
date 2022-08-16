//SPDX-License-Identifier: MIT;

//Need safe gaurds in place for failures as it will have to update the totalSupply
//when calling the treasury function.

pragma solidity 0.8.7;

import "./NonblockingLzApp.sol";
import "../interfaces/ITreasury.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Communicator is NonblockingLzApp {
    ITreasury treasury;

    error TreasurySet();
    error TransactionFailed();

    bool public set;

    mapping(address => uint16) public layerZeroAddress;

    constructor(address _endpoint) NonblockingLzApp(_endpoint) {}

    function addLayerZeroMapping(address _srcTreasuryAddress, uint16 srcChain)
        external
        onlyOwner
    {
        layerZeroAddress[_srcTreasuryAddress] = srcChain;
    }

    function sendMessage(uint256 x) public returns (uint256) {
        uint256 amount = treasury.receiveMessage(x);
        return amount;
    }

    function setTreasury(address _treasury) public {
        if (set != false) revert TreasurySet();
        treasury = ITreasury(_treasury);
        set = true;
    }

    function _nonblockingLzReceive(
        uint16,
        bytes memory _srcAddress,
        uint64, /*_nonce*/
        bytes memory _payload
    ) internal override {
        // use assembly to extract the address from the bytes memory parameter
        address sendBackToAddress;
        assembly {
            sendBackToAddress := mload(add(_srcAddress, 20))
        }
        uint16 _returnChainId = layerZeroAddress[sendBackToAddress];
        (
            uint256 _value,
            address _depositor,
            IERC20 _token,
            uint256 _amount
        ) = abi.decode(_payload, (uint256, address, IERC20, uint256));
        uint256 mintAmount = sendMessage(_value);
        bytes memory payload = abi.encode(
            mintAmount,
            _depositor,
            _token,
            _amount
        );
        uint16 version = 1;
        uint256 gasForDestinationLzReceive = 350000;
        bytes memory adapterParams = abi.encodePacked(
            version,
            gasForDestinationLzReceive
        );
        _lzSend(
            _returnChainId,
            payload,
            payable(address(this)),
            address(0x0),
            adapterParams
        );
    }
}
