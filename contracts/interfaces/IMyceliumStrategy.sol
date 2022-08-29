//SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

interface IMyceliumStrategy {
    event StakeMyc(address account, address token, uint256 amount);
    event UnstakeMyc(address account, address token, uint256 amount);

    event StakeMlp(address account, uint256 amount);
    event UnstakeMlp(address account, uint256 amount);

    // to help users who accidentally send their tokens to this contract

    function stakeMyc(uint256 _amount) external;

    function stakeEsMyc(uint256 _amount) external;

    function unstakeMyc(uint256 _amount) external;

    function unstakeEsMyc(uint256 _amount) external;

    function mintAndStakeMlp(address _token, uint256 _amount, uint256 _minUsdg, uint256 _minMlp)
        external
        returns (uint256);

    function mintAndStakeMlpETH(uint256 _minUsdg, uint256 _minMlp) external payable returns (uint256);

    function unstakeAndRedeemMlp(address _tokenOut, uint256 _mlpAmount, uint256 _minOut, address _receiver)
        external
        returns (uint256);

    function unstakeAndRedeemMlpETH(uint256 _mlpAmount, uint256 _minOut, address payable _receiver)
        external
        returns (uint256);

    function claim() external;

    function claimEsMyc() external;

    function claimFees() external;

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
    )
        external;

    function signalTransfer(address _receiver) external;

    function acceptTransfer(address _sender) external;

    function _validateReceiver(address _receiver) external view;

    function _compound(address _account) external;

    function _compoundMyc(address _account) external;

    function _compoundMlp(address _account) external;

    function _stakeMyc(address _fundingAccount, address _account, address _token, uint256 _amount) external;

    function _unstakeMyc(address _account, address _token, uint256 _amount, bool _shouldReduceBnMyc) external;
}
