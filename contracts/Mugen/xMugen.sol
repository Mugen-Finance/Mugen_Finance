// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../interfaces/IERC4626.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

error TRANSFER_FAILED();

contract xMugen is IERC4626, ERC20, ReentrancyGuard, Ownable {
    ERC20 public rewardsToken;
    ERC20 public stakingToken;

    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    uint256 public periodFinish = 0;
    uint256 public rewardRate = 0;
    uint256 public rewardsDuration = 30 days;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    event WithdrewStake(address indexed user, uint256 indexed amount);
    event IssuanceUpdated(uint256 issuance, uint256 vestingPeriodEnd);

    constructor(address _stakingToken, address _rewardsToken)
        ERC20("xMugen", "xMGN")
    {
        rewardsToken = ERC20(_rewardsToken);
        stakingToken = ERC20(_stakingToken);
    }

    /************************/
    /*** Accounting Logic ***/
    /************************/

    function issuanceRate(uint256 _rewards)
        external
        nonReentrant
        onlyOwner
        updateReward(address(0))
    {
        require(totalSupply() != 0, "xMGN:UVS:ZERO_SUPPLY");
        if (block.timestamp >= periodFinish) {
            rewardRate = _rewards / rewardsDuration;
        } else {
            uint256 remaining = periodFinish - block.timestamp;
            uint256 leftover = remaining * rewardRate;
            rewardRate = (_rewards + leftover) / rewardsDuration;
        }

        // Ensure the provided reward amount is not more than the balance in the contract.
        // This keeps the reward rate in the right range, preventing overflows due to
        // very high values of rewardRate in the earned and rewardsPerToken functions;
        // Reward + leftover must be less than 2^256 / 10^18 to avoid overflow.
        bool success = ERC20(rewardsToken).transferFrom(
            msg.sender,
            address(this),
            _rewards
        );

        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + rewardsDuration;

        emit RewardDeposit(msg.sender, _rewards);
        if (!success) revert TRANSFER_FAILED();
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalSupply() == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored +
            (((lastTimeRewardApplicable() - lastUpdateTime) *
                rewardRate *
                1e18) / totalSupply());
    }

    function earned(address account) public view returns (uint256) {
        return
            ((balanceOf(account) *
                (rewardPerToken() - userRewardPerTokenPaid[account])) / 1e18) +
            rewards[account];
    }

    function getRewardForDuration() external view returns (uint256) {
        return rewardRate * rewardsDuration;
    }

    /************************/
    /**** User Functions ****/
    /************************/

    //examine these for just basic interface purposes (IERC4626);

    /**
     * @notice Deposit tokens into this contract
     * @param assets_ | How much to stake
     * @param receiver_ | Who is receiving xMugen
     */
    function deposit(uint256 assets_, address receiver_)
        external
        virtual
        override
        updateReward(receiver_)
        nonReentrant
        returns (uint256 shares_)
    {
        _mint(shares_ = assets_, assets_, receiver_, msg.sender);
    }

    function mint(uint256 assets_, address receiver_)
        external
        virtual
        override
        updateReward(receiver_)
        nonReentrant
        returns (uint256 shares_)
    {
        _mint(shares_ = assets_, assets_, receiver_, msg.sender);
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
        updateReward(owner_)
        nonReentrant
        returns (uint256 shares_)
    {
        burn(shares_ = assets_, assets_, receiver_, owner_, msg.sender);
    }

    function redeem(
        uint256 assets_,
        address receiver_,
        address owner_
    )
        external
        virtual
        override
        updateReward(owner_)
        nonReentrant
        returns (uint256 shares_)
    {
        burn(shares_ = assets_, assets_, receiver_, owner_, msg.sender);
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

        _mint(receiver_, shares_);
        bool success = ERC20(stakingToken).transferFrom(
            msg.sender,
            address(this),
            assets_
        );
        if (!success) {
            revert TRANSFER_FAILED();
        }

        emit Deposit(caller_, msg.sender, receiver_, assets_, shares_);
    }

    /**
     * @notice User claims their tokens
     */
    function burn(
        uint256 shares_,
        uint256 assets_,
        address receiver_,
        address owner_,
        address caller_
    ) internal {
        require(receiver_ != address(0), "xMGN:B:ZERO_RECEIVER");
        require(shares_ != uint256(0), "xMGN:B:ZERO_SHARES");

        if (caller_ != owner_) {
            _spendAllowance(owner_, caller_, shares_);
        }
        claimReward(shares_);
        _burn(owner_, shares_);
        emit Withdraw(caller_, receiver_, owner_, assets_, shares_);

        if (caller_ != owner_) increaseAllowance(caller_, shares_);

        bool success = ERC20(stakingToken).transfer(receiver_, assets_);

        if (!success) {
            revert TRANSFER_FAILED();
        }
    }

    /**
     * @notice calculates the percentage of their balance they are unstake them pays that percentage of their rewards
     * @param amount | how many tokens they are unstaking
     */
    function claimReward(uint256 amount) internal {
        uint256 reward = (rewards[msg.sender] * amount) / balanceOf(msg.sender);
        rewards[msg.sender] -= reward;
        emit RewardsClaimed(msg.sender, reward);
        bool success = ERC20(rewardsToken).transfer(msg.sender, reward);
        if (!success) {
            revert TRANSFER_FAILED();
        }
    }

    /********************/
    /* Modifier Function */
    /********************/

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    /********************/
    /* View Functions */
    /********************/

    function getStored() external view returns (uint256) {
        return rewardPerTokenStored;
    }

    function getPaid(address account) external view returns (uint256) {
        return userRewardPerTokenPaid[account];
    }

    function getStaked(address account) external view returns (uint256) {
        return balanceOf(account);
    }

    function getRewardRate() external view returns (uint256) {
        return rewardRate;
    }

    function asset()
        external
        view
        override
        returns (address assetTokenAddress)
    {
        return address(stakingToken);
    }

    function totalAssets()
        external
        view
        override
        returns (uint256 totalManagedMugen, uint256 totalManagedReward)
    {
        uint256 stakedAmount = ERC20(stakingToken).balanceOf(address(this));
        uint256 rewardAmount = ERC20(rewardsToken).balanceOf(address(this));
        return (stakedAmount, rewardAmount);
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