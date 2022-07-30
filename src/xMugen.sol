// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "openzeppelin/contracts/security/ReentrancyGuard.sol";
import "openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interfaces/IERC4626.sol";
import "openzeppelin/contracts/access/Ownable.sol";

error TRANSFER_FAILED();

contract xMugen is IERC4626, ERC20, ReentrancyGuard, Ownable {
    address public s_rewardsToken;
    address public s_stakingToken;

    uint256 public REWARD_RATE;
    uint256 public s_lastUpdateTime;
    uint256 public s_rewardPerTokenStored;
    uint256 public vestingPeriodFinish;
    uint256 public unvestedRewards;

    mapping(address => uint256) public s_userRewardPerTokenPaid;
    mapping(address => uint256) public s_rewards;

    event WithdrewStake(address indexed user, uint256 indexed amount);
    event IssuanceUpdated(uint256 issuance, uint256 vestingPeriodEnd);

    constructor(address stakingToken, address rewardsToken)
        ERC20("xMugen", "xMGN")
    {
        s_stakingToken = stakingToken;
        s_rewardsToken = rewardsToken;
    }

    /**
     * @notice How much reward a token gets based on how long it's been in and during which "snapshots"
     */

    /************************/
    /*** Accounting Logic ***/
    /************************/

    function getStored() external view returns (uint256) {
        return s_rewardPerTokenStored;
    }

    function getPaid(address account) external view returns (uint256) {
        return s_userRewardPerTokenPaid[account];
    }

    function issuanceRate(uint256 rewards, uint256 _vestingPeriod)
        external
        nonReentrant
        onlyOwner
    {
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
     * @param receiver_ | How is staking and getting xMugen
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
     * @param receiver_ | Address receiving Mugen back
     * @param owner_ | Address that owns those assets
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

        if (caller_ != owner_) {
            decreaseAllowance(caller_, shares_);
        }
        claimReward(shares_);
        _burn(owner_, shares_);
        emit Withdraw(caller_, receiver_, owner_, assets_, shares_);

        bool success = ERC20(s_stakingToken).transfer(receiver_, assets_);

        if (!success) {
            revert TRANSFER_FAILED();
        }
    }

    /**
     * @notice calculates the percentage of their balance they are unstake them pays that percentage of their rewards
     * @param amount | how many tokens they are unstaking
     */
    function claimReward(uint256 amount) internal {
        uint256 reward = (s_rewards[msg.sender] * amount) /
            balanceOf(msg.sender);
        s_rewards[msg.sender] -= reward;
        unvestedRewards -= reward;
        emit RewardsClaimed(msg.sender, reward);
        bool success = ERC20(s_rewardsToken).transfer(msg.sender, reward);
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
        REWARD_RATE = block.timestamp >= vestingPeriodFinish ? 0 : REWARD_RATE;
    }

    /********************/
    /* Modifier Function */
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

    /********************/
    /* View Functions */
    /********************/

    function getStaked(address account) external view returns (uint256) {
        return balanceOf(account);
    }

    function getUnvested() public view returns (uint256) {
        return unvestedRewards;
    }

    function getRewardRate() external view returns (uint256) {
        return REWARD_RATE;
    }

    function checkVestingEnd() external view returns (uint256) {
        return vestingPeriodFinish;
    }

    function asset()
        external
        view
        override
        returns (address assetTokenAddress)
    {
        return s_stakingToken;
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
