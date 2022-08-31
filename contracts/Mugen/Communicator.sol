//SPDX-License-Identifier: MIT;

pragma solidity 0.8.7;

import {NonblockingLzApp} from "./NonblockingLzApp.sol";
import {ITreasury} from "../interfaces/ITreasury.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Communicator is NonblockingLzApp {
    /*///////////////////////////////////////////////////////////////
                              Errors
    //////////////////////////////////////////////////////////////*/

    error TreasurySet();
    error TransactionFailed();

    /*///////////////////////////////////////////////////////////////
                        State Variables
    //////////////////////////////////////////////////////////////*/

    bool public set;
    ITreasury public treasury;

    /*///////////////////////////////////////////////////////////////
                              Mapping 
    //////////////////////////////////////////////////////////////*/

    mapping(address => uint16) public layerZeroAddress;

    constructor(address _endpoint) NonblockingLzApp(_endpoint) {}

    /*///////////////////////////////////////////////////////////////
                        Admin Functions
    //////////////////////////////////////////////////////////////*/

    function addLayerZeroMapping(address _srcTreasuryAddress, uint16 srcChain)
        external
        onlyOwner
    {
        layerZeroAddress[_srcTreasuryAddress] = srcChain;
    }

    ///@notice sets the treasury address
    ///@param _treasury address of the treasury contract
    function setTreasury(address _treasury) public {
        if (set != false) {
            revert TreasurySet();
        }
        treasury = ITreasury(_treasury);
    }

    ///@notice permenantly locks the treasury address

    function lockTreasuryAddress() external onlyOwner {
        set = true;
    }

    /*///////////////////////////////////////////////////////////////
                        Internal Functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice calls the bonding function in the treasury contract.
     * @param x is the value received from the cross chain message
     */
    function sendMessage(uint256 x) internal returns (uint256) {
        uint256 amount = treasury.receiveMessage(x);
        return amount;
    }

    /*///////////////////////////////////////////////////////////////
                        Layer0 Functions
    //////////////////////////////////////////////////////////////*/

    function _nonblockingLzReceive(
        uint16,
        bytes memory _srcAddress,
        uint64,
        /*_nonce*/
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

    receive() external payable {}
}
