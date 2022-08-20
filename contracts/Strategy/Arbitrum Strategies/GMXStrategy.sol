//SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

/**
What will this strategy do?

Mint and stake GLP, stake esGMX, claim rewards, unstake, send yield to where it needs to go.
 */

import "../../interfaces/IRewardRouterV2.sol";

contract GMXStrategy {
    IRewardRouterV2 rewardRouterV2;

    event EsGMXStaked(address indexed _caller, uint256 _amount);
    event Unstaked(address indexed _caller, uint256 _amount);
    event GlpMinted(
        address indexed _caller,
        address indexed _token,
        uint256 _amount,
        uint256 _glpAmount
    );

    constructor(address _rewardRouterV2) {
        rewardRouterV2 = IRewardRouterV2(_rewardRouterV2);
    }

    function stakeGMXRewards(uint256 _amount) external {
        rewardRouterV2.stakeEsGmx(_amount);
        emit EsGMXStaked(msg.sender, _amount);
    }

    function mintGLP(
        address _token,
        uint256 _amount,
        uint256 _minUsdg,
        uint256 _minGlp
    ) external {
        uint256 glpAmount = rewardRouterV2.mintAndStakeGlp(
            _token,
            _amount,
            _minUsdg,
            _minGlp
        );
        emit GlpMinted(msg.sender, _token, _amount, glpAmount);
    }

    function unstake(uint256 _amount) external {
        rewardRouterV2.unstakeEsGmx(_amount);
        emit Unstaked(msg.sender, _amount);
    }

    function claimRewards() external {
        rewardRouterV2.claim();
    }
}
