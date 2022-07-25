/*
What I need to do for this contract right now:

Implement variable reward rate that changes as more rewards get added and make the other minor changes necessary.
*/

// SPDX-License-Identifier: MIT
// Inspired by https://solidity-by-example.org/defi/staking-rewards/
pragma solidity ^0.8.7;

import "openzeppelin/contracts/security/ReentrancyGuard.sol";
import "openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interfaces/IERC4626.sol";

error TRANSFER_FAILED();
error NeedsMoreThanZero();

contract xMugen is IERC4626, ERC20, ReentrancyGuard {
    address public s_rewardsToken;
    address public s_stakingToken;

    address public owner;

    // This is the reward token per second
    // Which will be multiplied by the tokens the user staked divided by the total
    // This ensures a steady reward rate of the platform
    // So the more users stake, the less for everyone who is staking.
    uint256 public REWARD_RATE;
    uint256 public s_lastUpdateTime;
    uint256 public s_rewardPerTokenStored;
    uint256 public vestingPeriodFinish;
    uint256 public unvestedRewards;

    mapping(address => uint256) public s_userRewardPerTokenPaid;
    mapping(address => uint256) public s_rewards;

    event WithdrewStake(address indexed user, uint256 indexed amount);
    event IssuanceUpdated(uint256 issuance, uint256 vestingPeriodEnd);

    constructor(
        address stakingToken,
        address rewardsToken,
        address _owner
    ) ERC20("xMugen", "xMGN") {
        s_stakingToken = stakingToken;
        s_rewardsToken = rewardsToken;
        owner = _owner;
    }

    /**
     * @notice How much reward a token gets based on how long it's been in and during which "snapshots"
     */

    /************************/
    /*** Accounting Logic ***/
    /************************/

    function issuanceRate(uint256 rewards, uint256 _vestingPeriod)
        external
        nonReentrant
    {
        require(msg.sender == owner, "NOT_OWNER");
        require(totalSupply() != 0, "xMGN:UVS:ZERO_SUPPLY");
        vestingPeriodFinish = block.timestamp + _vestingPeriod;
        bool success = ERC20(s_rewardsToken).transferFrom(
            msg.sender,
            address(this),
            rewards
        );
        REWARD_RATE =
            (ERC20(s_rewardsToken).balanceOf(address(this)) - unvestedRewards) /
            _vestingPeriod;
        uint256 _rewardRate = REWARD_RATE;
        emit RewardDeposit(msg.sender, rewards);
        emit IssuanceUpdated(_rewardRate, vestingPeriodFinish);

        if (!success) revert TRANSFER_FAILED();
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalSupply() == 0) {
            return s_rewardPerTokenStored;
        }
        return
            s_rewardPerTokenStored +
            (((block.timestamp - s_lastUpdateTime) * REWARD_RATE * 1e18) /
                totalSupply());
    }

    /**
     * @notice How much reward a user has earned
     */
    function earned(address account) public view returns (uint256) {
        return
            ((balanceOf(account) *
                (rewardPerToken() - s_userRewardPerTokenPaid[account])) /
                1e18) + s_rewards[account];
    }

    /************************/
    /*** Staker Functions ***/
    /************************/

    /**
     * @notice Deposit tokens into this contract
     * @param assets_ | How much to stake
     */
    function deposit(uint256 assets_, address receiver_)
        external
        virtual
        override
        updateReward(msg.sender)
        nonReentrant
        returns (uint256 shares_)
    {
        _mint(shares_ = assets_, assets_, receiver_, msg.sender);
    }

    function mint(uint256 shares_, address receiver_)
        external
        virtual
        override
        updateReward(msg.sender)
        nonReentrant
        returns (uint256 assets_)
    {
        _mint(shares_, assets_ = shares_, receiver_, msg.sender);
    }

    /**
     * @notice Withdraw tokens from this contract
     * @param assets_ | How much to withdraw
     */
    function withdraw(
        uint256 assets_,
        address receiver_,
        address owner_
    )
        external
        virtual
        override
        updateReward(msg.sender)
        nonReentrant
        returns (uint256 shares_)
    {
        _burn(shares_ = assets_, assets_, receiver_, owner_, msg.sender);
    }

    function redeem(
        uint256 shares_,
        address receiver_,
        address owner_
    )
        external
        virtual
        override
        updateReward(msg.sender)
        nonReentrant
        returns (uint256 assets_)
    {
        _burn(shares_, assets_ = shares_, receiver_, owner_, msg.sender);
    }

    /********************/
    /* Internal Functions */
    /********************/

    function _mint(
        uint256 shares_,
        uint256 assets_,
        address receiver_,
        address caller_
    ) internal {
        require(receiver_ != address(0), "xMGN:M:ZERO_RECEIVER");
        require(shares_ != uint256(0), "xMGN:M:ZERO_SHARES");
        require(assets_ != uint256(0), "xMGN:M:ZERO_ASSETS");

        _mint(receiver_, shares_);

        bool success = ERC20(s_stakingToken).transferFrom(
            receiver_,
            address(this),
            assets_
        );
        if (!success) {
            revert TRANSFER_FAILED();
        }

        emit Deposit(caller_, receiver_, assets_, shares_);
    }

    /**
     * @notice User claims their tokens
     */
    function _burn(
        uint256 shares_,
        uint256 assets_,
        address receiver_,
        address owner_,
        address caller_
    ) internal {
        require(receiver_ != address(0), "xMGN:B:ZERO_RECEIVER");
        require(shares_ != uint256(0), "xMGN:B:ZERO_SHARES");
        require(assets_ != uint256(0), "xMGN:B:ZERO_ASSETS");

        // if (caller_ != owner_) {
        //     _decreaseAllowance(owner_, caller_, shares_);
        // }
        claimReward(shares_);
        _burn(owner_, shares_);

        emit Withdraw(caller_, receiver_, owner_, assets_, shares_);

        bool success = ERC20(s_stakingToken).transfer(receiver_, assets_);

        if (!success) {
            revert TRANSFER_FAILED();
        }
    }

    function claimReward(uint256 amount) internal updateReward(msg.sender) {
        uint256 claimedPercentage = (100 * amount) / (balanceOf(msg.sender));
        uint256 reward = s_rewards[msg.sender];
        uint256 claimed = (reward * claimedPercentage) / 100;
        s_rewards[msg.sender] -= claimed;
        unvestedRewards = unvestedRewards - claimed;
        emit RewardsClaimed(msg.sender, claimed);
        bool success = ERC20(s_rewardsToken).transfer(msg.sender, claimed);
        if (!success) {
            revert TRANSFER_FAILED();
        }
    }

    function unVestedAssets() internal {
        if (REWARD_RATE == 0) unvestedRewards = unvestedRewards;
        unvestedRewards =
            ((block.timestamp - s_lastUpdateTime) * REWARD_RATE) +
            unvestedRewards;
    }

    function _updateIssuanceParams() internal {
        REWARD_RATE = block.timestamp > vestingPeriodFinish ? 0 : REWARD_RATE;
    }

    /********************/
    /* Modifiers Functions */
    /********************/
    modifier updateReward(address account) {
        s_rewardPerTokenStored = rewardPerToken();
        unVestedAssets();
        _updateIssuanceParams();
        s_lastUpdateTime = block.timestamp;
        s_rewards[account] = earned(account);
        s_userRewardPerTokenPaid[account] = s_rewardPerTokenStored;
        _;
    }

    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert NeedsMoreThanZero();
        }
        _;
    }

    /********************/
    /* View Functions */
    /********************/
    // Ideally, we'd have getter functions for all our s_ variables we want exposed, and set them all to private.
    // But, for the purpose of this demo, we've left them public for simplicity.

    function getStaked(address account) public view returns (uint256) {
        return balanceOf(account);
    }

    function getUnvested() public view returns (uint256) {
        return unvestedRewards;
    }

    //Checked
    function checkRR() external view returns (uint256) {
        return REWARD_RATE;
    }

    //checked
    function checkVestingEnd() external view returns (uint256) {
        return vestingPeriodFinish;
    }

    function asset()
        external
        view
        override
        returns (address assetTokenAddress)
    {
        return s_rewardsToken;
    }

    function totalAssets()
        external
        view
        override
        returns (uint256 totalManagedAssets)
    {
        uint256 stakedAmount = ERC20(s_stakingToken).balanceOf(address(this));
        uint256 rewardAmount = ERC20(s_rewardsToken).balanceOf(address(this));
        uint256 totalAmount = stakedAmount + rewardAmount;
        return totalAmount;
    }

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
        override
        returns (uint256 assets_)
    {
        assets_ = shares_;
    }

    function convertToShares(uint256 assets_)
        public
        view
        virtual
        override
        returns (uint256 shares_)
    {
        shares_ = assets_;
    }

    function maxDeposit(address receiver_)
        external
        pure
        virtual
        override
        returns (uint256 maxAssets_)
    {
        receiver_; // Silence warning
        maxAssets_ = type(uint256).max;
    }

    function maxMint(address receiver_)
        external
        pure
        virtual
        override
        returns (uint256 maxShares_)
    {
        receiver_; // Silence warning
        maxShares_ = type(uint256).max;
    }

    function maxRedeem(address owner_)
        external
        view
        virtual
        override
        returns (uint256 maxShares_)
    {
        maxShares_ = balanceOf(owner_);
    }

    function maxWithdraw(address owner_)
        external
        view
        virtual
        override
        returns (uint256 maxAssets_)
    {
        maxAssets_ = balanceOfAssets(owner_);
    }

    function previewDeposit(uint256 assets_)
        public
        view
        virtual
        override
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
        override
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
        override
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
        override
        returns (uint256 shares_)
    {
        // As per https://eips.ethereum.org/EIPS/eip-4626#security-considerations,
        // it should round UP if it’s calculating the amount of shares a user must return, to be sent a given amount of assets.
        shares_ = assets_;
    }
}
