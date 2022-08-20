contract RewardRouterV2 is ReentrancyGuard, Governable {
using SafeMath for uint256;
using SafeERC20 for IERC20;
using Address for address payable;

    bool public isInitialized;

    address public weth;

    address public myc;
    address public esMyc;
    address public bnMyc;

    address public mlp; // MYC Liquidity Provider token

    address public stakedMycTracker;
    address public bonusMycTracker;
    address public feeMycTracker;

    address public stakedMlpTracker;
    address public feeMlpTracker;

    address public mlpManager;

    address public mlpVester;
    address public mycVester;

    mapping(address => address) public pendingReceivers;

    event StakeMyc(address account, address token, uint256 amount);
    event UnstakeMyc(address account, address token, uint256 amount);

    event StakeMlp(address account, uint256 amount);
    event UnstakeMlp(address account, uint256 amount);

    receive() external payable {
        require(msg.sender == weth, "Router: invalid sender");
    }







    function stakeMyc(uint256 _amount) external nonReentrant {
        _stakeMyc(msg.sender, msg.sender, myc, _amount);
    }

    function stakeEsMyc(uint256 _amount) external nonReentrant {
        _stakeMyc(msg.sender, msg.sender, esMyc, _amount);
    }

    function unstakeMyc(uint256 _amount) external nonReentrant {
        _unstakeMyc(msg.sender, myc, _amount, true);
    }

    function unstakeEsMyc(uint256 _amount) external nonReentrant {
        _unstakeMyc(msg.sender, esMyc, _amount, true);
    }

    function mintAndStakeMlp(
        address _token,
        uint256 _amount,
        uint256 _minUsdg,
        uint256 _minMlp
    ) external nonReentrant returns (uint256) {
        require(_amount > 0, "RewardRouter: invalid _amount");

        address account = msg.sender;
        uint256 mlpAmount = IMlpManager(mlpManager).addLiquidityForAccount(
            account,
            account,
            _token,
            _amount,
            _minUsdg,
            _minMlp
        );
        IRewardTracker(feeMlpTracker).stakeForAccount(
            account,
            account,
            mlp,
            mlpAmount
        );
        IRewardTracker(stakedMlpTracker).stakeForAccount(
            account,
            account,
            feeMlpTracker,
            mlpAmount
        );

        emit StakeMlp(account, mlpAmount);

        return mlpAmount;
    }

    function mintAndStakeMlpETH(uint256 _minUsdg, uint256 _minMlp)
        external
        payable
        nonReentrant
        returns (uint256)
    {
        require(msg.value > 0, "RewardRouter: invalid msg.value");

        IWETH(weth).deposit{value: msg.value}();
        IERC20(weth).approve(mlpManager, msg.value);

        address account = msg.sender;
        uint256 mlpAmount = IMlpManager(mlpManager).addLiquidityForAccount(
            address(this),
            account,
            weth,
            msg.value,
            _minUsdg,
            _minMlp
        );

        IRewardTracker(feeMlpTracker).stakeForAccount(
            account,
            account,
            mlp,
            mlpAmount
        );
        IRewardTracker(stakedMlpTracker).stakeForAccount(
            account,
            account,
            feeMlpTracker,
            mlpAmount
        );

        emit StakeMlp(account, mlpAmount);

        return mlpAmount;
    }

    function unstakeAndRedeemMlp(
        address _tokenOut,
        uint256 _mlpAmount,
        uint256 _minOut,
        address _receiver
    ) external nonReentrant returns (uint256) {
        require(_mlpAmount > 0, "RewardRouter: invalid _mlpAmount");

        address account = msg.sender;
        IRewardTracker(stakedMlpTracker).unstakeForAccount(
            account,
            feeMlpTracker,
            _mlpAmount,
            account
        );
        IRewardTracker(feeMlpTracker).unstakeForAccount(
            account,
            mlp,
            _mlpAmount,
            account
        );
        uint256 amountOut = IMlpManager(mlpManager).removeLiquidityForAccount(
            account,
            _tokenOut,
            _mlpAmount,
            _minOut,
            _receiver
        );

        emit UnstakeMlp(account, _mlpAmount);

        return amountOut;
    }

    function unstakeAndRedeemMlpETH(
        uint256 _mlpAmount,
        uint256 _minOut,
        address payable _receiver
    ) external nonReentrant returns (uint256) {
        require(_mlpAmount > 0, "RewardRouter: invalid _mlpAmount");

        address account = msg.sender;
        IRewardTracker(stakedMlpTracker).unstakeForAccount(
            account,
            feeMlpTracker,
            _mlpAmount,
            account
        );
        IRewardTracker(feeMlpTracker).unstakeForAccount(
            account,
            mlp,
            _mlpAmount,
            account
        );
        uint256 amountOut = IMlpManager(mlpManager).removeLiquidityForAccount(
            account,
            weth,
            _mlpAmount,
            _minOut,
            address(this)
        );

        IWETH(weth).withdraw(amountOut);

        _receiver.sendValue(amountOut);

        emit UnstakeMlp(account, _mlpAmount);

        return amountOut;
    }

    function claim() external nonReentrant {
        address account = msg.sender;

        IRewardTracker(feeMycTracker).claimForAccount(account, account);
        IRewardTracker(feeMlpTracker).claimForAccount(account, account);

        IRewardTracker(stakedMycTracker).claimForAccount(account, account);
        IRewardTracker(stakedMlpTracker).claimForAccount(account, account);
    }

    function claimEsMyc() external nonReentrant {
        address account = msg.sender;

        IRewardTracker(stakedMycTracker).claimForAccount(account, account);
        IRewardTracker(stakedMlpTracker).claimForAccount(account, account);
    }

    function claimFees() external nonReentrant {
        address account = msg.sender;

        IRewardTracker(feeMycTracker).claimForAccount(account, account);
        IRewardTracker(feeMlpTracker).claimForAccount(account, account);
    }

    function compound() external nonReentrant {
        _compound(msg.sender);
    }



    function handleRewards(
        bool _shouldClaimMyc,
        bool _shouldStakeMyc,
        bool _shouldClaimEsMyc,
        bool _shouldStakeEsMyc,
        bool _shouldStakeMultiplierPoints,
        bool _shouldClaimWeth,
        bool _shouldConvertWethToEth,
        bool _shouldBuyMlpWithWeth
    ) external nonReentrant {
        address account = msg.sender;

        uint256 mycAmount = 0;
        if (_shouldClaimMyc) {
            uint256 mycAmount0 = IVester(mycVester).claimForAccount(
                account,
                account
            );
            uint256 mycAmount1 = IVester(mlpVester).claimForAccount(
                account,
                account
            );
            mycAmount = mycAmount0.add(mycAmount1);
        }

        if (_shouldStakeMyc && mycAmount > 0) {
            _stakeMyc(account, account, myc, mycAmount);
        }

        uint256 esMycAmount = 0;
        if (_shouldClaimEsMyc) {
            uint256 esMycAmount0 = IRewardTracker(stakedMycTracker)
                .claimForAccount(account, account);
            uint256 esMycAmount1 = IRewardTracker(stakedMlpTracker)
                .claimForAccount(account, account);
            esMycAmount = esMycAmount0.add(esMycAmount1);
        }

        if (_shouldStakeEsMyc && esMycAmount > 0) {
            _stakeMyc(account, account, esMyc, esMycAmount);
        }

        if (_shouldStakeMultiplierPoints) {
            uint256 bnMycAmount = IRewardTracker(bonusMycTracker)
                .claimForAccount(account, account);
            if (bnMycAmount > 0) {
                IRewardTracker(feeMycTracker).stakeForAccount(
                    account,
                    account,
                    bnMyc,
                    bnMycAmount
                );
            }
        }

        if (_shouldClaimWeth) {
            if (_shouldBuyMlpWithWeth) {
                uint256 weth0 = IRewardTracker(feeMycTracker).claimForAccount(
                    account,
                    address(this)
                );
                uint256 weth1 = IRewardTracker(feeMlpTracker).claimForAccount(
                    account,
                    address(this)
                );

                uint256 wethAmount = weth0.add(weth1);

                // claimed amount can be 0
                if (wethAmount > 0) {
                    IERC20(weth).approve(mlpManager, wethAmount);
                    uint256 mlpAmount = IMlpManager(mlpManager)
                        .addLiquidityForAccount(
                            address(this),
                            account,
                            weth,
                            wethAmount,
                            0,
                            0
                        );

                    IRewardTracker(feeMlpTracker).stakeForAccount(
                        account,
                        account,
                        mlp,
                        mlpAmount
                    );
                    IRewardTracker(stakedMlpTracker).stakeForAccount(
                        account,
                        account,
                        feeMlpTracker,
                        mlpAmount
                    );

                    emit StakeMlp(account, mlpAmount);
                }
            } else if (_shouldConvertWethToEth) {
                uint256 weth0 = IRewardTracker(feeMycTracker).claimForAccount(
                    account,
                    address(this)
                );
                uint256 weth1 = IRewardTracker(feeMlpTracker).claimForAccount(
                    account,
                    address(this)
                );

                uint256 wethAmount = weth0.add(weth1);

                IWETH(weth).withdraw(wethAmount);
                payable(account).sendValue(wethAmount);
            } else {
                IRewardTracker(feeMycTracker).claimForAccount(account, account);
                IRewardTracker(feeMlpTracker).claimForAccount(account, account);
            }
        }
    }



    function signalTransfer(address _receiver) external nonReentrant {
        require(
            IERC20(mycVester).balanceOf(msg.sender) == 0,
            "RewardRouter: sender has vested tokens"
        );
        require(
            IERC20(mlpVester).balanceOf(msg.sender) == 0,
            "RewardRouter: sender has vested tokens"
        );

        _validateReceiver(_receiver);
        pendingReceivers[msg.sender] = _receiver;
    }

    function acceptTransfer(address _sender) external nonReentrant {
        require(
            IERC20(mycVester).balanceOf(_sender) == 0,
            "RewardRouter: sender has vested tokens"
        );
        require(
            IERC20(mlpVester).balanceOf(_sender) == 0,
            "RewardRouter: sender has vested tokens"
        );

        address receiver = msg.sender;
        require(
            pendingReceivers[_sender] == receiver,
            "RewardRouter: transfer not signalled"
        );
        delete pendingReceivers[_sender];

        _validateReceiver(receiver);
        _compound(_sender);

        uint256 stakedMyc = IRewardTracker(stakedMycTracker).depositBalances(
            _sender,
            myc
        );
        if (stakedMyc > 0) {
            _unstakeMyc(_sender, myc, stakedMyc, false);
            _stakeMyc(_sender, receiver, myc, stakedMyc);
        }

        uint256 stakedEsMyc = IRewardTracker(stakedMycTracker).depositBalances(
            _sender,
            esMyc
        );
        if (stakedEsMyc > 0) {
            _unstakeMyc(_sender, esMyc, stakedEsMyc, false);
            _stakeMyc(_sender, receiver, esMyc, stakedEsMyc);
        }

        uint256 stakedBnMyc = IRewardTracker(feeMycTracker).depositBalances(
            _sender,
            bnMyc
        );
        if (stakedBnMyc > 0) {
            IRewardTracker(feeMycTracker).unstakeForAccount(
                _sender,
                bnMyc,
                stakedBnMyc,
                _sender
            );
            IRewardTracker(feeMycTracker).stakeForAccount(
                _sender,
                receiver,
                bnMyc,
                stakedBnMyc
            );
        }

        uint256 esMycBalance = IERC20(esMyc).balanceOf(_sender);
        if (esMycBalance > 0) {
            IERC20(esMyc).transferFrom(_sender, receiver, esMycBalance);
        }

        uint256 mlpAmount = IRewardTracker(feeMlpTracker).depositBalances(
            _sender,
            mlp
        );
        if (mlpAmount > 0) {
            IRewardTracker(stakedMlpTracker).unstakeForAccount(
                _sender,
                feeMlpTracker,
                mlpAmount,
                _sender
            );
            IRewardTracker(feeMlpTracker).unstakeForAccount(
                _sender,
                mlp,
                mlpAmount,
                _sender
            );

            IRewardTracker(feeMlpTracker).stakeForAccount(
                _sender,
                receiver,
                mlp,
                mlpAmount
            );
            IRewardTracker(stakedMlpTracker).stakeForAccount(
                receiver,
                receiver,
                feeMlpTracker,
                mlpAmount
            );
        }

        IVester(mycVester).transferStakeValues(_sender, receiver);
        IVester(mlpVester).transferStakeValues(_sender, receiver);
    }

    function _validateReceiver(address _receiver) private view {
        require(
            IRewardTracker(stakedMycTracker).averageStakedAmounts(_receiver) ==
                0,
            "RewardRouter: stakedMycTracker.averageStakedAmounts > 0"
        );
        require(
            IRewardTracker(stakedMycTracker).cumulativeRewards(_receiver) == 0,
            "RewardRouter: stakedMycTracker.cumulativeRewards > 0"
        );

        require(
            IRewardTracker(bonusMycTracker).averageStakedAmounts(_receiver) ==
                0,
            "RewardRouter: bonusMycTracker.averageStakedAmounts > 0"
        );
        require(
            IRewardTracker(bonusMycTracker).cumulativeRewards(_receiver) == 0,
            "RewardRouter: bonusMycTracker.cumulativeRewards > 0"
        );

        require(
            IRewardTracker(feeMycTracker).averageStakedAmounts(_receiver) == 0,
            "RewardRouter: feeMycTracker.averageStakedAmounts > 0"
        );
        require(
            IRewardTracker(feeMycTracker).cumulativeRewards(_receiver) == 0,
            "RewardRouter: feeMycTracker.cumulativeRewards > 0"
        );

        require(
            IVester(mycVester).transferredAverageStakedAmounts(_receiver) == 0,
            "RewardRouter: mycVester.transferredAverageStakedAmounts > 0"
        );

        require(
            IVester(mycVester).transferredCumulativeRewards(_receiver) == 0,
            "RewardRouter: mycVester.transferredCumulativeRewards > 0"
        );
        require(
            IRewardTracker(stakedMlpTracker).averageStakedAmounts(_receiver) ==
                0,
            "RewardRouter: stakedMlpTracker.averageStakedAmounts > 0"
        );
        require(
            IRewardTracker(stakedMlpTracker).cumulativeRewards(_receiver) == 0,
            "RewardRouter: stakedMlpTracker.cumulativeRewards > 0"
        );

        require(
            IRewardTracker(feeMlpTracker).averageStakedAmounts(_receiver) == 0,
            "RewardRouter: feeMlpTracker.averageStakedAmounts > 0"
        );
        require(
            IRewardTracker(feeMlpTracker).cumulativeRewards(_receiver) == 0,
            "RewardRouter: feeMlpTracker.cumulativeRewards > 0"
        );

        require(
            IVester(mlpVester).transferredAverageStakedAmounts(_receiver) == 0,
            "RewardRouter: mlpVester.transferredAverageStakedAmounts > 0"
        );
        require(
            IVester(mlpVester).transferredCumulativeRewards(_receiver) == 0,
            "RewardRouter: mlpVester.transferredCumulativeRewards > 0"
        );

        require(
            IERC20(mycVester).balanceOf(_receiver) == 0,
            "RewardRouter: mycVester.balance > 0"
        );
        require(
            IERC20(mlpVester).balanceOf(_receiver) == 0,
            "RewardRouter: mlpVester.balance > 0"
        );
    }

    function _compound(address _account) private {
        _compoundMyc(_account);
        _compoundMlp(_account);
    }

    function _compoundMyc(address _account) private {
        uint256 esMycAmount = IRewardTracker(stakedMycTracker).claimForAccount(
            _account,
            _account
        );
        if (esMycAmount > 0) {
            _stakeMyc(_account, _account, esMyc, esMycAmount);
        }

        uint256 bnMycAmount = IRewardTracker(bonusMycTracker).claimForAccount(
            _account,
            _account
        );
        if (bnMycAmount > 0) {
            IRewardTracker(feeMycTracker).stakeForAccount(
                _account,
                _account,
                bnMyc,
                bnMycAmount
            );
        }
    }

    function _compoundMlp(address _account) private {
        uint256 esMycAmount = IRewardTracker(stakedMlpTracker).claimForAccount(
            _account,
            _account
        );
        if (esMycAmount > 0) {
            _stakeMyc(_account, _account, esMyc, esMycAmount);
        }
    }

    function _stakeMyc(
        address _fundingAccount,
        address _account,
        address _token,
        uint256 _amount
    ) private {
        require(_amount > 0, "RewardRouter: invalid _amount");

        IRewardTracker(stakedMycTracker).stakeForAccount(
            _fundingAccount,
            _account,
            _token,
            _amount
        );
        IRewardTracker(bonusMycTracker).stakeForAccount(
            _account,
            _account,
            stakedMycTracker,
            _amount
        );
        IRewardTracker(feeMycTracker).stakeForAccount(
            _account,
            _account,
            bonusMycTracker,
            _amount
        );

        emit StakeMyc(_account, _token, _amount);
    }

    function _unstakeMyc(
        address _account,
        address _token,
        uint256 _amount,
        bool _shouldReduceBnMyc
    ) private {
        require(_amount > 0, "RewardRouter: invalid _amount");

        uint256 balance = IRewardTracker(stakedMycTracker).stakedAmounts(
            _account
        );

        IRewardTracker(feeMycTracker).unstakeForAccount(
            _account,
            bonusMycTracker,
            _amount,
            _account
        );
        IRewardTracker(bonusMycTracker).unstakeForAccount(
            _account,
            stakedMycTracker,
            _amount,
            _account
        );
        IRewardTracker(stakedMycTracker).unstakeForAccount(
            _account,
            _token,
            _amount,
            _account
        );

        if (_shouldReduceBnMyc) {
            uint256 bnMycAmount = IRewardTracker(bonusMycTracker)
                .claimForAccount(_account, _account);
            if (bnMycAmount > 0) {
                IRewardTracker(feeMycTracker).stakeForAccount(
                    _account,
                    _account,
                    bnMyc,
                    bnMycAmount
                );
            }

            uint256 stakedBnMyc = IRewardTracker(feeMycTracker).depositBalances(
                _account,
                bnMyc
            );
            if (stakedBnMyc > 0) {
                uint256 reductionAmount = stakedBnMyc.mul(_amount).div(balance);
                IRewardTracker(feeMycTracker).unstakeForAccount(
                    _account,
                    bnMyc,
                    reductionAmount,
                    _account
                );
                IMintable(bnMyc).burn(_account, reductionAmount);
            }
        }

        emit UnstakeMyc(_account, _token, _amount);
    }

}
