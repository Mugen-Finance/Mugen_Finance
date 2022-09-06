// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IBancorFormula.sol";
import "./Power.sol";

contract BancorFormula is IBancorFormula, Power {
    using SafeMath for uint256;

    uint256 private constant ONE = 1;
    uint32 private constant MAX_WEIGHT = 1000000;
    uint8 private constant MIN_PRECISION = 32;
    uint8 private constant MAX_PRECISION = 127;

    // Auto-generated via 'PrintMaxExpArray.py'
    uint256[128] private maxExpArray;

    /**
     * @dev should be executed after construction (too large for the constructor)
     */
    function init() public {
        initMaxExpArray();
        // initLambertArray();
    }

    /**
     * @dev given a token supply, reserve balance, weight and a deposit amount (in the reserve token),
     * calculates the target amount for a given conversion (in the main token)
     *
     * Formula:
     * return = _supply * ((1 + _amount / _reserveBalance) ^ (_reserveWeight / 1000000) - 1)
     *
     * @param _supply          liquid token supply
     * @param _reserveBalance  reserve balance
     * @param _reserveWeight   reserve weight, represented in ppm (1-1000000)
     * @param _amount          amount of reserve tokens to get the target amount for
     *
     * @return target
     */
    function purchaseTargetAmount(uint256 _supply, uint256 _reserveBalance, uint32 _reserveWeight, uint256 _amount)
        public
        view
        override
        returns (uint256)
    {
        // validate input
        require(_supply > 0, "ERR_INVALID_SUPPLY");
        require(_reserveBalance > 0, "ERR_INVALID_RESERVE_BALANCE");
        require(_reserveWeight > 0 && _reserveWeight <= MAX_WEIGHT, "ERR_INVALID_RESERVE_WEIGHT");

        // special case for 0 deposit amount
        if (_amount == 0) {
            return 0;
        }

        // special case if the weight = 100%
        if (_reserveWeight == MAX_WEIGHT) {
            return _supply.mul(_amount) / _reserveBalance;
        }

        uint256 result;
        uint8 precision;
        uint256 baseN = _amount.add(_reserveBalance);
        (result, precision) = power(baseN, _reserveBalance, _reserveWeight, MAX_WEIGHT);
        uint256 temp = _supply.mul(result) >> precision;
        return temp - _supply;
    }

    /**
     * @dev given a token supply, reserve balance, weight and a sell amount (in the main token),
     * calculates the target amount for a given conversion (in the reserve token)
     *
     * Formula:
     * return = _reserveBalance * (1 - (1 - _amount / _supply) ^ (1000000 / _reserveWeight))
     *
     * @param _supply          liquid token supply
     * @param _reserveBalance  reserve balance
     * @param _reserveWeight   reserve weight, represented in ppm (1-1000000)
     * @param _amount          amount of liquid tokens to get the target amount for
     *
     * @return reserve token amount
     */
    function saleTargetAmount(uint256 _supply, uint256 _reserveBalance, uint32 _reserveWeight, uint256 _amount)
        public
        view
        override
        returns (uint256)
    {
        // validate input
        require(_supply > 0, "ERR_INVALID_SUPPLY");
        require(_reserveBalance > 0, "ERR_INVALID_RESERVE_BALANCE");
        require(_reserveWeight > 0 && _reserveWeight <= MAX_WEIGHT, "ERR_INVALID_RESERVE_WEIGHT");
        require(_amount <= _supply, "ERR_INVALID_AMOUNT");

        // special case for 0 sell amount
        if (_amount == 0) {
            return 0;
        }

        // special case for selling the entire supply
        if (_amount == _supply) {
            return _reserveBalance;
        }

        // special case if the weight = 100%
        if (_reserveWeight == MAX_WEIGHT) {
            return _reserveBalance.mul(_amount) / _supply;
        }

        uint256 result;
        uint8 precision;
        uint256 baseD = _supply - _amount;
        (result, precision) = power(_supply, baseD, MAX_WEIGHT, _reserveWeight);
        uint256 temp1 = _reserveBalance.mul(result);
        uint256 temp2 = _reserveBalance << precision;
        return (temp1 - temp2) / result;
    }

    /**
     * @dev given two reserve balances/weights and a sell amount (in the first reserve token),
     * calculates the target amount for a conversion from the source reserve token to the target reserve token
     *
     * Formula:
     * return = _targetReserveBalance * (1 - (_sourceReserveBalance / (_sourceReserveBalance + _amount)) ^ (_sourceReserveWeight / _targetReserveWeight))
     *
     * @param _sourceReserveBalance    source reserve balance
     * @param _sourceReserveWeight     source reserve weight, represented in ppm (1-1000000)
     * @param _targetReserveBalance    target reserve balance
     * @param _targetReserveWeight     target reserve weight, represented in ppm (1-1000000)
     * @param _amount                  source reserve amount
     *
     * @return target reserve amount
     */
    function crossReserveTargetAmount(
        uint256 _sourceReserveBalance,
        uint32 _sourceReserveWeight,
        uint256 _targetReserveBalance,
        uint32 _targetReserveWeight,
        uint256 _amount
    )
        public
        view
        override
        returns (uint256)
    {
        // validate input
        require(_sourceReserveBalance > 0 && _targetReserveBalance > 0, "ERR_INVALID_RESERVE_BALANCE");
        require(
            _sourceReserveWeight > 0 && _sourceReserveWeight <= MAX_WEIGHT && _targetReserveWeight > 0
                && _targetReserveWeight <= MAX_WEIGHT,
            "ERR_INVALID_RESERVE_WEIGHT"
        );

        // special case for equal weights
        if (_sourceReserveWeight == _targetReserveWeight) {
            return _targetReserveBalance.mul(_amount) / _sourceReserveBalance.add(_amount);
        }

        uint256 result;
        uint8 precision;
        uint256 baseN = _sourceReserveBalance.add(_amount);
        (result, precision) = power(baseN, _sourceReserveBalance, _sourceReserveWeight, _targetReserveWeight);
        uint256 temp1 = _targetReserveBalance.mul(result);
        uint256 temp2 = _targetReserveBalance << precision;
        return (temp1 - temp2) / result;
    }

    /**
     * @dev given a pool token supply, reserve balance, reserve ratio and an amount of requested pool tokens,
     * calculates the amount of reserve tokens required for purchasing the given amount of pool tokens
     *
     * Formula:
     * return = _reserveBalance * (((_supply + _amount) / _supply) ^ (MAX_WEIGHT / _reserveRatio) - 1)
     *
     * @param _supply          pool token supply
     * @param _reserveBalance  reserve balance
     * @param _reserveRatio    reserve ratio, represented in ppm (2-2000000)
     * @param _amount          requested amount of pool tokens
     *
     * @return reserve token amount
     */
    function fundCost(uint256 _supply, uint256 _reserveBalance, uint32 _reserveRatio, uint256 _amount)
        public
        view
        override
        returns (uint256)
    {
        // validate input
        require(_supply > 0, "ERR_INVALID_SUPPLY");
        require(_reserveBalance > 0, "ERR_INVALID_RESERVE_BALANCE");
        require(_reserveRatio > 1 && _reserveRatio <= MAX_WEIGHT * 2, "ERR_INVALID_RESERVE_RATIO");

        // special case for 0 amount
        if (_amount == 0) {
            return 0;
        }

        // special case if the reserve ratio = 100%
        if (_reserveRatio == MAX_WEIGHT) {
            return (_amount.mul(_reserveBalance) - 1) / _supply + 1;
        }

        uint256 result;
        uint8 precision;
        uint256 baseN = _supply.add(_amount);
        (result, precision) = power(baseN, _supply, MAX_WEIGHT, _reserveRatio);
        uint256 temp = ((_reserveBalance.mul(result) - 1) >> precision) + 1;
        return temp - _reserveBalance;
    }

    /**
     * @dev given a pool token supply, reserve balance, reserve ratio and an amount of reserve tokens to fund with,
     * calculates the amount of pool tokens received for purchasing with the given amount of reserve tokens
     *
     * Formula:
     * return = _supply * ((_amount / _reserveBalance + 1) ^ (_reserveRatio / MAX_WEIGHT) - 1)
     *
     * @param _supply          pool token supply
     * @param _reserveBalance  reserve balance
     * @param _reserveRatio    reserve ratio, represented in ppm (2-2000000)
     * @param _amount          amount of reserve tokens to fund with
     *
     * @return pool token amount
     */
    function fundSupplyAmount(uint256 _supply, uint256 _reserveBalance, uint32 _reserveRatio, uint256 _amount)
        public
        view
        override
        returns (uint256)
    {
        // validate input
        require(_supply > 0, "ERR_INVALID_SUPPLY");
        require(_reserveBalance > 0, "ERR_INVALID_RESERVE_BALANCE");
        require(_reserveRatio > 1 && _reserveRatio <= MAX_WEIGHT * 2, "ERR_INVALID_RESERVE_RATIO");

        // special case for 0 amount
        if (_amount == 0) {
            return 0;
        }

        // special case if the reserve ratio = 100%
        if (_reserveRatio == MAX_WEIGHT) {
            return _amount.mul(_supply) / _reserveBalance;
        }

        uint256 result;
        uint8 precision;
        uint256 baseN = _reserveBalance.add(_amount);
        (result, precision) = power(baseN, _reserveBalance, _reserveRatio, MAX_WEIGHT);
        uint256 temp = _supply.mul(result) >> precision;
        return temp - _supply;
    }

    /**
     * @dev given a pool token supply, reserve balance, reserve ratio and an amount of pool tokens to liquidate,
     * calculates the amount of reserve tokens received for selling the given amount of pool tokens
     *
     * Formula:
     * return = _reserveBalance * (1 - ((_supply - _amount) / _supply) ^ (MAX_WEIGHT / _reserveRatio))
     *
     * @param _supply          pool token supply
     * @param _reserveBalance  reserve balance
     * @param _reserveRatio    reserve ratio, represented in ppm (2-2000000)
     * @param _amount          amount of pool tokens to liquidate
     *
     * @return reserve token amount
     */
    function liquidateReserveAmount(uint256 _supply, uint256 _reserveBalance, uint32 _reserveRatio, uint256 _amount)
        public
        view
        override
        returns (uint256)
    {
        // validate input
        require(_supply > 0, "ERR_INVALID_SUPPLY");
        require(_reserveBalance > 0, "ERR_INVALID_RESERVE_BALANCE");
        require(_reserveRatio > 1 && _reserveRatio <= MAX_WEIGHT * 2, "ERR_INVALID_RESERVE_RATIO");
        require(_amount <= _supply, "ERR_INVALID_AMOUNT");

        // special case for 0 amount
        if (_amount == 0) {
            return 0;
        }

        // special case for liquidating the entire supply
        if (_amount == _supply) {
            return _reserveBalance;
        }

        // special case if the reserve ratio = 100%
        if (_reserveRatio == MAX_WEIGHT) {
            return _amount.mul(_reserveBalance) / _supply;
        }

        uint256 result;
        uint8 precision;
        uint256 baseD = _supply - _amount;
        (result, precision) = power(_supply, baseD, MAX_WEIGHT, _reserveRatio);
        uint256 temp1 = _reserveBalance.mul(result);
        uint256 temp2 = _reserveBalance << precision;
        return (temp1 - temp2) / result;
    }

    /**
     * @dev The arbitrage incentive is to convert to the point where the on-chain price is equal to the off-chain price.
     * We want this operation to also impact the primary reserve balance becoming equal to the primary reserve staked balance.
     * In other words, we want the arbitrager to convert the difference between the reserve balance and the reserve staked balance.
     *
     * Formula input:
     * - let t denote the primary reserve token staked balance
     * - let s denote the primary reserve token balance
     * - let r denote the secondary reserve token balance
     * - let q denote the numerator of the rate between the tokens
     * - let p denote the denominator of the rate between the tokens
     * Where p primary tokens are equal to q secondary tokens
     *
     * Formula output:
     * - compute x = W(t / r * q / p * log(s / t)) / log(s / t)
     * - return x / (1 + x) as the weight of the primary reserve token
     * - return 1 / (1 + x) as the weight of the secondary reserve token
     * Where W is the Lambert W Function
     *
     * If the rate-provider provides the rates for a common unit, for example:
     * - P = 2 ==> 2 primary reserve tokens = 1 ether
     * - Q = 3 ==> 3 secondary reserve tokens = 1 ether
     * Then you can simply use p = P and q = Q
     *
     * If the rate-provider provides the rates for a single unit, for example:
     * - P = 2 ==> 1 primary reserve token = 2 ethers
     * - Q = 3 ==> 1 secondary reserve token = 3 ethers
     * Then you can simply use p = Q and q = P
     *
     * @param _primaryReserveStakedBalance the primary reserve token staked balance
     * @param _primaryReserveBalance       the primary reserve token balance
     * @param _secondaryReserveBalance     the secondary reserve token balance
     * @param _reserveRateNumerator        the numerator of the rate between the tokens
     * @param _reserveRateDenominator      the denominator of the rate between the tokens
     *
     * Note that `numerator / denominator` should represent the amount of secondary tokens equal to one primary token
     *
     * @return the weight of the primary reserve token and the weight of the secondary reserve token, both in ppm (0-1000000)
     */
    // function balancedWeights(
    //     uint256 _primaryReserveStakedBalance,
    //     uint256 _primaryReserveBalance,
    //     uint256 _secondaryReserveBalance,
    //     uint256 _reserveRateNumerator,
    //     uint256 _reserveRateDenominator
    // ) public view override returns (uint32, uint32) {
    //     if (_primaryReserveStakedBalance == _primaryReserveBalance)
    //         require(
    //             _primaryReserveStakedBalance > 0 ||
    //                 _secondaryReserveBalance > 0,
    //             "ERR_INVALID_RESERVE_BALANCE"
    //         );
    //     else
    //         require(
    //             _primaryReserveStakedBalance > 0 &&
    //                 _primaryReserveBalance > 0 &&
    //                 _secondaryReserveBalance > 0,
    //             "ERR_INVALID_RESERVE_BALANCE"
    //         );
    //     require(
    //         _reserveRateNumerator > 0 && _reserveRateDenominator > 0,
    //         "ERR_INVALID_RESERVE_RATE"
    //     );

    //     uint256 tq = _primaryReserveStakedBalance.mul(_reserveRateNumerator);
    //     uint256 rp = _secondaryReserveBalance.mul(_reserveRateDenominator);

    //     if (_primaryReserveStakedBalance < _primaryReserveBalance)
    //         return
    //             balancedWeightsByStake(
    //                 _primaryReserveBalance,
    //                 _primaryReserveStakedBalance,
    //                 tq,
    //                 rp,
    //                 true
    //             );

    //     if (_primaryReserveStakedBalance > _primaryReserveBalance)
    //         return
    //             balancedWeightsByStake(
    //                 _primaryReserveStakedBalance,
    //                 _primaryReserveBalance,
    //                 tq,
    //                 rp,
    //                 false
    //             );

    //     return normalizedWeights(tq, rp);
    // }
}
