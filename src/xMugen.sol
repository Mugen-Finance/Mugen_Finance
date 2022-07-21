//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./interfaces/IERC4626.sol";
import "openzeppelin/contracts/token/ERC20/ERC20.sol";

contract xMugen is IERC4626, ERC20 {
    error TRANSFER_FAILED();
    uint256 public immutable precision; // Precision of rates, equals max deposit amounts before rounding errors occur
    uint256 public rewardsPerAssetStored;

    address public asset; // Underlying ERC-20 asset used by ERC-4626 functionality.
    address public rewardAsset;
    address public owner; // Current owner of the contract, able to update the vesting schedule.

    uint256 public freeAssets; // Amount of assets unlocked regardless of time passed.
    uint256 public issuanceRate; // asset/second rate dependent on aggregate vesting schedule.
    uint256 public lastUpdated; // Timestamp of when issuance equation was last updated.
    uint256 public vestingPeriodFinish; // Timestamp when current vesting schedule ends.

    uint256 private locked = 1; // Used in reentrancy check.

    mapping(address => uint256) userRewardPerAssetPaid;
    mapping(address => uint256) userRewards; //Updated in the modifier

    /*****************/
    /*** Modifiers ***/
    /*****************/

    modifier updateReward(address account) {
        rewardsPerAssetStored = rewardPerToken();
        lastUpdated = block.timestamp;
        userRewards[account] = earned(account);
        userRewardPerAssetPaid[account] = rewardsPerAssetStored;
        _;
    }

    modifier nonReentrant() {
        require(locked == 1, "RDT:LOCKED");

        locked = 2;

        _;

        locked = 1;
    }

    constructor(
        string memory name_,
        string memory symbol_,
        address owner_,
        address asset_,
        address rewardAsset_,
        uint256 precision_
    ) ERC20(name_, symbol_) {
        require((owner = owner_) != address(0), "RDT:C:OWNER_ZERO_ADDRESS");
        require((asset = asset_) != address(0), "RDT:C:ASSET_ZERO_ADDRESS");
        require(
            (rewardAsset = rewardAsset_) != address(0),
            "RDT:C:REWARD_ASSET_ZERO_ADDRESS"
        );
        precision = precision_;
    }

    /********************************/
    /*** Administrative Functions ***/
    /********************************/

    function rewardDeposit(uint256 rewardAssets_, uint256 _vestingTime)
        external
    {
        require(msg.sender == owner, "NOT_OWNER");
        bool success = ERC20(rewardAsset).transferFrom(
            msg.sender,
            address(this),
            rewardAssets_
        );
        if (!success) {
            revert TRANSFER_FAILED();
        }

        uint256 issuanceRate_ = _updateIssuanceParams();

        updateVestingSchedule(_vestingTime);
    }

    function updateVestingSchedule(uint256 vestingPeriod_)
        internal
        virtual
        returns (uint256 issuanceRate_, uint256 freeAssets_)
    {
        require(msg.sender == owner, "RDT:UVS:NOT_OWNER");
        require(totalSupply() != 0, "RDT:UVS:ZERO_SUPPLY");

        // Update "y-intercept" to reflect current available asset.
        freeAssets_ = freeAssets = totalAssets();

        // Calculate slope.
        issuanceRate_ = issuanceRate =
            ((ERC20(rewardAsset).balanceOf(address(this)) - freeAssets_) *
                precision) /
            vestingPeriod_;

        // Update timestamp and period finish.
        vestingPeriodFinish = (lastUpdated = block.timestamp) + vestingPeriod_;

        emit IssuanceParamsUpdated(freeAssets_, issuanceRate_);
        emit VestingScheduleUpdated(msg.sender, vestingPeriodFinish);
    }

    /************************/
    /*** Accounting Logic ***/
    /************************/

    function rewardPerToken() public view returns (uint256) {
        if (totalSupply() == 0) {
            return rewardsPerAssetStored;
        }
        return
            rewardsPerAssetStored +
            (((block.timestamp - lastUpdated) * issuanceRate * precision) /
                totalSupply());
    }

    function earned(address account) public view returns (uint256) {
        return
            ((balanceOf(account) *
                (rewardPerToken() - userRewardPerAssetPaid[account])) /
                precision) + userRewards[account];
    }

    /************************/
    /*** Staker Functions ***/
    /************************/

    function deposit(uint256 assets_, address receiver_)
        external
        virtual
        updateReward(msg.sender)
        nonReentrant
        returns (uint256 shares_)
    {
        _mint(shares_ = assets_, assets_, receiver_, msg.sender);
    }

    function mint(uint256 shares_, address receiver_)
        external
        virtual
        updateReward(msg.sender)
        nonReentrant
        returns (uint256 assets_)
    {
        _mint(shares_, assets_ = shares_, receiver_, msg.sender);
    }

    function redeem(
        uint256 shares_,
        address receiver_,
        address owner_
    )
        external
        virtual
        updateReward(msg.sender)
        nonReentrant
        returns (uint256 assets_)
    {
        _burn(shares_, assets_ = shares_, receiver_, owner_, msg.sender);
    }

    function withdraw(
        uint256 assets_,
        address receiver_,
        address owner_
    )
        external
        virtual
        updateReward(msg.sender)
        nonReentrant
        returns (uint256 shares_)
    {
        _burn(shares_ = assets_, assets_, receiver_, owner_, msg.sender);
    }

    /**************************/
    /*** Internal Functions ***/
    /**************************/

    function _mint(
        uint256 shares_,
        uint256 assets_,
        address receiver_,
        address caller_
    ) internal {
        require(receiver_ != address(0), "RDT:M:ZERO_RECEIVER");
        require(shares_ != uint256(0), "RDT:M:ZERO_SHARES");
        require(assets_ != uint256(0), "RDT:M:ZERO_ASSETS");

        _mint(receiver_, shares_);

        emit Deposit(caller_, receiver_, assets_, shares_);

        bool success = ERC20(asset).transferFrom(
            caller_,
            address(this),
            assets_
        );
        if (!success) {
            revert TRANSFER_FAILED();
        }
    }

    function _burn(
        uint256 shares_,
        uint256 assets_,
        address receiver_,
        address owner_,
        address caller_
    ) internal {
        require(receiver_ != address(0), "RDT:B:ZERO_RECEIVER");
        require(shares_ != uint256(0), "RDT:B:ZERO_SHARES");
        require(assets_ != uint256(0), "RDT:B:ZERO_ASSETS");

        // if (caller_ != owner_) {
        //     _decreaseAllowance(owner_, caller_, shares_);
        // }

        _burn(owner_, shares_);

        emit Withdraw(caller_, receiver_, owner_, assets_, shares_);

        bool success = ERC20(asset).transfer(receiver_, assets_);
        claimReward(shares_);

        if (!success) {
            revert TRANSFER_FAILED();
        }
    }

    function _updateIssuanceParams() internal returns (uint256 issuanceRate_) {
        return
            issuanceRate = (lastUpdated = block.timestamp) > vestingPeriodFinish
                ? 0
                : issuanceRate;
    }

    /**********************/
    /*** View Functions ***/
    /**********************/

    function balanceOfAssets(address account_)
        public
        view
        virtual
        returns (uint256 balanceOfAssets_)
    {
        return balanceOf(account_);
    }

    function convertToAssets(uint256 shares_)
        public
        view
        virtual
        returns (uint256 assets_)
    {
        assets_ = shares_;
    }

    function convertToShares(uint256 assets_)
        public
        view
        virtual
        returns (uint256 shares_)
    {
        shares_ = assets_;
    }

    function maxDeposit(address receiver_)
        external
        pure
        virtual
        returns (uint256 maxAssets_)
    {
        receiver_; // Silence warning
        maxAssets_ = type(uint256).max;
    }

    function maxMint(address receiver_)
        external
        pure
        virtual
        returns (uint256 maxShares_)
    {
        receiver_; // Silence warning
        maxShares_ = type(uint256).max;
    }

    function maxRedeem(address owner_)
        external
        view
        virtual
        returns (uint256 maxShares_)
    {
        maxShares_ = balanceOf(owner_);
    }

    function maxWithdraw(address owner_)
        external
        view
        virtual
        returns (uint256 maxAssets_)
    {
        maxAssets_ = balanceOfAssets(owner_);
    }

    function previewDeposit(uint256 assets_)
        public
        view
        virtual
        returns (uint256 shares_)
    {
        // As per https://eips.ethereum.org/EIPS/eip-4626#security-considerations,
        // it should round DOWN if it’s calculating the amount of shares to issue to a user, given an amount of assets provided.
        shares_ = assets_;
    }

    function previewMint(uint256 shares_)
        public
        view
        virtual
        returns (uint256 assets_)
    {
        // As per https://eips.ethereum.org/EIPS/eip-4626#security-considerations,
        // it should round UP if it’s calculating the amount of assets a user must provide, to be issued a given amount of shares.
        assets_ = shares_;
    }

    function previewRedeem(uint256 shares_)
        public
        view
        virtual
        returns (uint256 assets_)
    {
        // As per https://eips.ethereum.org/EIPS/eip-4626#security-considerations,
        // it should round DOWN if it’s calculating the amount of assets to send to a user, given amount of shares returned.
        assets_ = convertToAssets(shares_);
    }

    function previewWithdraw(uint256 assets_)
        public
        view
        virtual
        returns (uint256 shares_)
    {
        // As per https://eips.ethereum.org/EIPS/eip-4626#security-considerations,
        // it should round UP if it’s calculating the amount of shares a user must return, to be sent a given amount of assets.
        shares_ = assets_;
    }

    function totalAssets()
        public
        view
        virtual
        returns (uint256 totalManagedAssets_)
    {
        uint256 issuanceRate_ = issuanceRate;

        if (issuanceRate_ == 0) return freeAssets;

        uint256 vestingPeriodFinish_ = vestingPeriodFinish;
        uint256 lastUpdated_ = lastUpdated;

        uint256 vestingTimePassed = block.timestamp > vestingPeriodFinish_
            ? vestingPeriodFinish_ - lastUpdated_
            : block.timestamp - lastUpdated_;

        return ((issuanceRate_ * vestingTimePassed) / precision) + freeAssets;
    }

    /***************************/
    /*** Internal Functions ***/
    /*************************/

    function claimReward(uint256 shares_) internal updateReward(msg.sender) {
        uint256 reward = userRewards[msg.sender] *
            (balanceOf(msg.sender) / shares_);
        userRewards[msg.sender] -= reward;
        uint256 freeAssetsCache = freeAssets = totalAssets() - reward;
        uint256 issuanceRate_ = _updateIssuanceParams();
        emit RewardsClaimed(msg.sender, reward);
        emit IssuanceParamsUpdated(freeAssetsCache, issuanceRate_);

        bool success = ERC20(rewardAsset).transfer(msg.sender, reward);
        if (!success) {
            revert TRANSFER_FAILED();
        }
    }
}
