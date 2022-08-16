// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IOFTCore.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @dev Interface of the OFT standard
 */
interface IMugen is IOFTCore, IERC20 {
    function mint(address _to, uint256 amount_) external;

    function setTrustedRemote(uint16 _srcChainId, bytes calldata _srcAddress)
        external;
}
