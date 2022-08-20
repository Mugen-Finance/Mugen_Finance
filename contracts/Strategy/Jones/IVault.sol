//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

interface IVault {
    // ============================= View functions ================================

    /**
     * The amount of `shares` that the Vault would exchange for the amount of `assets` provided, in an ideal scenario where all the conditions are met.
     *
     * Does not show any variations depending on the caller.
     * Does not reflect slippage or other on-chain conditions, when performing the actual exchange.
     * Does not revert unless due to integer overflow caused by an unreasonably large input.
     * This calculation does not reflect the “per-user” price-per-share, and instead reflects the “average-user’s” price-per-share, meaning what the average user can expect to see when exchanging to and from.
     *
     * @param assets Amount of assets to convert.
     * @return shares Amount of shares calculated for the amount of given assets, rounded down towards 0. Does not include any fees that are charged against assets in the Vault.
     */
    function convertToShares(uint256 assets)
        external
        view
        returns (uint256 shares);

    /**
     * The amount of `assets` that the Vault would exchange for the amount of `shares` provided, in an ideal scenario where all the conditions are met.
     *
     * Does not show any variations depending on the caller.
     * Does not reflect slippage or other on-chain conditions, when performing the actual exchange.
     * Does not revert unless due to integer overflow caused by an unreasonably large input.
     * This calculation does not reflect the “per-user” price-per-share, and instead reflects the “average-user’s” price-per-share, meaning what the average user can expect to see when exchanging to and from.
     *
     * @return assets Amount of assets calculated for the given amount of shares, rounded down towards 0. Does not include fees that are charged against assets in the Vault.
     */
    function convertToAssets(uint256 shares)
        external
        view
        returns (uint256 assets);

    /**
     * Maximum amount of the underlying asset that can be deposited into the Vault for the receiver, through a deposit call.
     * Returns the maximum amount of assets deposit would allow to be deposited for receiver and not cause a revert, which should be higher than the actual maximum that would be accepted (it should underestimate if necessary). This assumes that the user has infinite assets, i.e. does not rely on balanceOf of asset.
     *
     * Does not revert.
     * This is akin to `vaultCap` in legacy vaults.
     *
     * The `receiver` parameter is added for ERC-4626 parity and is not relevant to our use case
     * since we are not going to have user specific limits for deposits. Either deposits are limited
     * to everyone or no one.
     *
     * @return maxAssets Max assets that can be deposited for receiver. Returns 2 ** 256 - 1 if there is no limit on the maximum amount of assets that may be deposited. Returns 0 if deposits are entirely disabled (even temporarily).
     */
    function maxDeposit(address receiver)
        external
        view
        returns (uint256 maxAssets);

    /**
     * Allows an on-chain or off-chain user to simulate the effects of their deposit at the current block, given current on-chain conditions.
     *
     * Returns as close to and no more than the exact amount of Vault shares that would be minted in a deposit call in the same transaction. I.e. deposit will return the same or more shares as previewDeposit if called in the same transaction.
     * Does not account for deposit limits like those returned from maxDeposit and always acts as though the deposit would be accepted, regardless if the user has enough tokens approved, etc.
     * Does not revert due to vault specific user/global limits. May revert due to other conditions that would also cause deposit to revert.
     *
     * Any unfavorable discrepancy between convertToShares and previewDeposit will be considered slippage in share price or some other type of condition, meaning the depositor will lose assets by depositing.
     *
     * @return shares exact amount of shares that would be minted in a deposit call. That includes deposit fees. Integrators should be aware of the existence of deposit fees.
     */
    function previewDeposit(uint256 assets)
        external
        view
        returns (uint256 shares);

    /**
     * @return The current vault State
     */
    function state() external view returns (State);

    /**
     * The address of the underlying token used for the Vault for accounting, depositing, and withdrawing.
     */
    function asset() external view returns (address);

    /**
     * The address of the underlying shares token used used to represent tokenized vault.
     */
    function share() external view returns (address);

    /**
     * Total amount of the underlying asset that is managed by this vault.
     *
     * This includes any compounding that occurs from yield.
     * It must be inclusive of any fees that are charged against assets in the Vault.
     * Must not revert.
     *
     * @return totalManagedAssets amount of underlying asset managed by vault.
     */
    function totalAssets() external view returns (uint256 totalManagedAssets);

    /**
     * Maximum amount of shares that can be minted from the Vault for the `receiver`, through a `mint` call.
     *
     * Returns `2 ** 256 - 1` if there is no limit on the maximum amount of shares that may be minted.
     */
    function maxMint(address receiver)
        external
        view
        returns (uint256 maxShares);

    /**
     * Allows an on-chain or off-chain user to simulate the effects of their mint at the current block, given current on-chain conditions.
     * MUST NOT revert due to vault specific user/global limits. MAY revert due to other conditions that would also cause mint to revert.
     * note: Any unfavorable discrepancy between `convertToAssets` and `previewMint` should be considered slippage in share price or some other type of condition, meaning the depositor will lose assets by minting.
     *
     * Does not account for mint limits like those returned from maxMint and always acts as though the mint would be accepted, regardless if the user has enough tokens approved, etc.
     */
    function previewMint(uint256 shares) external view returns (uint256 assets);

    /**
     * Maximum amount of the underlying asset that can be withdrawn from the `owner` balance in the Vault, through a `withdraw` call.
     *
     * Factors in both global and user-specific limits, like if withdrawals are entirely disabled (even temporarily) it must return 0.
     * Does not revert.
     *
     * @return maxAssets The maximum amount of assets that could be transferred from `owner` through `withdraw` and not cause a revert, which must not be higher than the actual maximum that would be accepted (it should underestimate if necessary).
     */
    function maxWithdraw(address owner)
        external
        view
        returns (uint256 maxAssets);

    /**
     * Allows an on-chain or off-chain user to simulate the effects of their withdrawal at the current block, given current on-chain conditions.
     *
     * Does not revert due to vault specific user/global limits. May revert due to other conditions that would also cause withdraw to revert.
     * Any unfavorable discrepancy between convertToShares and previewWithdraw should be considered slippage in share price or some other type of condition, meaning the depositor will lose assets by depositing.
     *
     * @return shares Shares available to withdraw for specified assets. This includes of withdrawal fees. Integrators should be aware of the existence of withdrawal fees.
     */
    function previewWithdraw(uint256 assets)
        external
        view
        returns (uint256 shares);

    /**
     * Maximum amount of Vault shares that can be redeemed from the `owner` balance in the Vault, through a `redeem` call.
     *
     * @return maxShares Max shares that can be redeemed. Factors in both global and user-specific limits, like if redemption is entirely disabled (even temporarily) it will return 0.
     */
    function maxRedeem(address owner) external view returns (uint256 maxShares);

    /**
     * Allows an on-chain or off-chain user to simulate the effects of their redeemption at the current block, given current on-chain conditions.
     * Does not account for redemption limits like those returned from maxRedeem and should always act as though the redemption would be accepted, regardless if the user has enough shares, etc.
     *
     * Does not revert due to vault specific user/global limits. May revert due to other conditions that would also cause redeem to revert.
     *
     * @return assets Amount of assets redeemable for given shares. Includes of withdrawal fees. Integrators should be aware of the existence of withdrawal fees.
     */
    function previewRedeem(uint256 shares)
        external
        view
        returns (uint256 assets);

    // ============================= User functions ================================

    /**
     * @dev Mints `shares` Vault shares to `receiver` by depositing `amount` of underlying tokens. This should only be called outside the management window.
     *
     * Reverts if all of assets cannot be deposited (ex due to deposit limit, slippage, approvals, etc).
     *
     * Emits a {Deposit} event
     */
    function deposit(uint256 assets, address receiver)
        external
        returns (uint256 shares);

    /**
     * Mints exactly `shares` Vault shares to `receiver` by depositing `amount` of underlying tokens.
     *
     * Reverts if all of shares cannot be minted (ex. due to deposit limit being reached, slippage, etc).
     *
     * Emits a {Deposit} event
     */
    function mint(uint256 shares, address receiver)
        external
        returns (uint256 assets);

    /**
     * Burns `shares` from `owner` and sends exactly `assets` of underlying tokens to `receiver`. Only available outside of management window.
     *
     * Reverts if all of assets cannot be withdrawn (due to withdrawal limit being reached, slippage, the owner not having enough shares, etc).
     * Any pre-requesting methods before withdrawal should be performed separately.
     *
     * Emits a {Withdraw} event
     */
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) external returns (uint256 shares);

    /**
     * Burns exactly `shares` from `owner` and sends `assets` of underlying tokens to `receiver`. Only available outside of management window.
     *
     * Reverts if all of shares cannot be redeemed (due to withdrawal limit being reached, slippage, the owner not having enough shares, etc).
     * Any pre-requesting methods before withdrawal should be performed separately.
     *
     * Emits a {Withdraw} event
     */
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) external returns (uint256 assets);

    // ============================= Strategy functions ================================

    /**
     * Sends the required amount of Asset from this vault to the calling strategy.
     * @dev can only be called by whitelisted strategies (KEEPER role)
     * @dev reverts if management window is closed.
     * @param assets the amount of tokens to pull
     */
    function pull(uint256 assets) external;

    /**
     * Deposits funds from Strategy (both profits and principal amounts).
     * @dev can only be called by whitelisted strategies (KEEPER role)
     * @dev reverts if management window is closed.
     * @param assets the amount of Assets being deposited from the strategy.
     */
    function depositStrategyFunds(uint256 assets) external;

    // ============================= Admin functions ================================

    /**
     * Sets the max deposit `amount` for vault. Akin to setting vault cap in v2 vaults.
     * Since we will not be limiting deposits per user there is no need to add `receiver` input
     * in the argument.
     */
    function setVaultCap(uint256 amount) external;

    /**
     * Adds a strategy to the whitelist.
     * @dev can only be called by governor (GOVERNOR role)
     * @param _address of the strategy to whitelist
     */
    function whitelistStrategy(address _address) external;

    /**
     * Removes a strategy from the whitelist.
     * @dev can only be called by governor (GOVERNOR role)
     * @param _address of the strategy to remove from whitelist
     */
    function removeStrategyFromWhitelist(address _address) external;

    /**
     * @notice Adds a contract to the whitelist.
     * @dev By default only EOA cann interact with the vault.
     * @dev Whitelisted contracts will be able to interact with the vault too.
     * @param contractAddress The address of the contract to whitelist.
     */
    function addContractAddressToWhitelist(address contractAddress) external;

    /**
     * @notice Used to check wheter a contract address is whitelisted to use the vault
     * @param _contractAddress The address of the contract to check
     * @return `true` if the contract is whitelisted, `false` otherwise
     */
    function whitelistedContract(address _contractAddress)
        external
        view
        returns (bool);

    /**
     * @notice Removes a contract from the whitelist.
     * @dev Removed contracts wont be able to interact with the vault.
     * @param contractAddress The address of the contract to whitelist.
     */
    function removeContractAddressFromWhitelist(address contractAddress)
        external;

    /**
     * Migrate vault to new vault contract.
     * @dev acts as emergency withdrawal if needed.
     * @dev can only be called by governor (GOVERNOR role)
     * @param _to New vault contract address.
     * @param _tokens Addresses of tokens to be migrated.
     *
     */
    function migrate(address _to, address[] memory _tokens) external;

    /**
     * Deposits and withdrawals close, assets are under vault control.
     * @dev can only be called by governor (GOVERNOR role)
     */
    function openManagementWindow() external;

    /**
     * Open vault for deposits and claims.
     * @dev can only be called by governor (GOVERNOR role)
     */
    function closeManagementWindow() external;

    /**
     * Open vault for deposits and claims, sets the snapshot of assets balance manually
     * @dev can only be called by governor (GOVERNOR role)
     * @dev can only be called on `State.INITIAL`
     * @param _snapshotAssetBalance Overrides the value of the snapshotted asset balance
     * @param _snapshotShareSupply Overrides the value of the snapshotted share supply
     */
    function initialRun(
        uint256 _snapshotAssetBalance,
        uint256 _snapshotShareSupply
    ) external;

    /**
     * Enable/diable charging performance & management fees
     * @dev can only be called by GOVERNOR role
     * @param _status `true` if the vault should charge fees, `false` otherwise
     */
    function setChargeFees(bool _status) external;

    /**
     * Updated the fee distributor address
     * @dev can only be called by GOVERNOR role
     * @param _feeDistributor The address of the new fee distributor
     */
    function setFeeDistributor(address _feeDistributor) external;

    // ============================= Enums =================================

    /**
     * Enum to represent the current state of the vault
     * INITIAL = Right after deployment, can move to `UNMANAGED` by calling `initialRun`
     * UNMANAGED = Users are able to interact with the vault, can move to `MANAGED` by calling `openManagementWindow`
     * MANAGED = Strategies will be able to borrow & repay, can move to `UNMANAGED` by calling `closeManagementWindow`
     */
    enum State {
        INITIAL,
        UNMANAGED,
        MANAGED
    }

    // ============================= Events ================================

    /**
     * `caller` has exchanged `assets` for `shares`, and transferred those `shares` to `owner`.
     * Emitted when tokens are deposited into the Vault via the `mint` and `deposit` methods.
     */
    event Deposit(
        address indexed caller,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );

    /**
     * `caller` has exchanged `shares`, owned by `owner`, for `assets`, and transferred those `assets` to `receiver`.
     * Will be emitted when shares are withdrawn from the Vault in `ERC4626.redeem` or `ERC4626.withdraw` methods.
     */
    event Withdraw(
        address indexed caller,
        address indexed receiver,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );

    /**
     * emitted when vault balance snapshot is taken
     * @param _timestamp snapshot timestamp (indexed)
     * @param _vaultBalance vault balance value
     * @param _jonesAssetSupply jDPX total supply value
     */
    event Snapshot(
        uint256 indexed _timestamp,
        uint256 _vaultBalance,
        uint256 _jonesAssetSupply
    );

    /**
     * emitted when asset management window is opened
     * @param _timestamp snapshot timestamp (indexed)
     * @param _assetBalance new vault balance value
     * @param _shareSupply share token total supply at this time
     */
    event EpochStarted(
        uint256 indexed _timestamp,
        uint256 _assetBalance,
        uint256 _shareSupply
    );

    /** emitted when claim and deposit windows are open
     * @param _timestamp snapshot timestamp (indexed)
     * @param _assetBalance new vault balance value
     * @param _shareSupply share token total supply at this time
     */
    event EpochEnded(
        uint256 indexed _timestamp,
        uint256 _assetBalance,
        uint256 _shareSupply
    );

    // ============================= Errors ================================
    error MSG_SENDER_NOT_WHITELISTED_USER();
    error DEPOSIT_ASSET_AMOUNT_EXCEEDS_MAX_DEPOSIT();
    error MINT_SHARE_AMOUNT_EXCEEDS_MAX_MINT();
    error ZERO_SHARES_AVAILABLE_WHEN_DEPOSITING();
    error INVALID_STATE(State _expected, State _actual);
    error INVALID_ASSETS_AMOUNT();
    error INVALID_SHARES_AMOUNT();
    error CONTRACT_ADDRESS_MAKING_PROHIBITED_FUNCTION_CALL();
    error INVALID_ADDRESS();
    error INVALID_SNAPSHOT_VALUE();
}
