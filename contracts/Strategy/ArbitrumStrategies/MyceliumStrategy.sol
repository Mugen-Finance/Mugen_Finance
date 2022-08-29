//SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

/**
 * What will this strategy do?
 *
 * Mint and stake GLP, stake esGMX, claim rewards, unstake, send yield to where it needs to go.
 * Go through the mycelium strategy today and see how similar it is
 * Look into compounding
 */

import "../../interfaces/IMyceliumStrategy.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MyceliumStrategy {
    IMyceliumStrategy mycelium;

    event StakeMlp(address account, uint256 amount);

    constructor(address _mycelium) {
        mycelium = IMyceliumStrategy(_mycelium);
    }

    function deposit(address _token, uint256 _amount, uint256 _minUsdg, uint256 _minMlp) external {
        uint256 amountRecieved = mycelium.mintAndStakeMlp(_token, _amount, _minUsdg, _minMlp);
        emit StakeMlp(msg.sender, amountRecieved);
    }

    function withdraw(address _tokenOut, uint256 _mlpAmount, uint256 _minOut) external {
        mycelium.unstakeAndRedeemMlp(_tokenOut, _mlpAmount, _minOut, address(this));
    }

    function claimRewards() external {
        mycelium.claim();
    }

    function claimEsMYC() external {
        mycelium.claimEsMyc();
    }

    function claimRewardFees() external {
        mycelium.claimFees();
    }
}
