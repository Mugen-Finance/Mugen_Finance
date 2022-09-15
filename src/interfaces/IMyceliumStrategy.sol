//SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

interface IMyceliumStrategy {
    event StakeMyc(address account, address token, uint256 amount);
    event UnstakeMyc(address account, address token, uint256 amount);

    event StakeMlp(address account, uint256 amount);
    event UnstakeMlp(address account, uint256 amount);

    function stakeMyc(uint256 _amount) external;

    function stakeEsMyc(uint256 _amount) external;

    function unstakeMyc(uint256 _amount) external;

    function unstakeEsMyc(uint256 _amount) external;

    function mintAndStakeMlp(
        address _token,
        uint256 _amount,
        uint256 _minUsdg,
        uint256 _minMlp
    ) external;

    function mintAndStakeMlpETH(uint256 _minUsdg, uint256 _minMlp)
        external
        payable;

    function unstakeAndRedeemMlp(
        address _tokenOut,
        uint256 _mlpAmount,
        uint256 _minOut,
        address _receiver
    ) external;

    function unstakeAndRedeemMlpETH(
        uint256 _mlpAmount,
        uint256 _minOut,
        address payable _receiver
    ) external;

    function claim() external;

    function claimEsMyc() external;

    function compound() external;

    function handleRewards(
        bool _shouldClaimMyc,
        bool _shouldStakeMyc,
        bool _shouldClaimEsMyc,
        bool _shouldStakeEsMyc,
        bool _shouldStakeMultiplierPoints,
        bool _shouldClaimWeth,
        bool _shouldConvertWethToEth,
        bool _shouldBuyMlpWithWeth
    ) external;

    function signalTransfer(address _receiver) external;

    function acceptTransfer(address _sender) external;
}
