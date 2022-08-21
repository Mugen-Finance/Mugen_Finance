// //SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
// import "@openzeppelin/contracts/access/AccessControl.sol";
// import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
// //import "../VaultsV2/JonesAsset.sol";
// import "./IVault.sol";

// //import "./library/FixedPointMath.sol";

// /**
//  * @title Jones Abstract Vault V3
//  * @author JonesDAO
//  */
// abstract contract JonesVaultV3 is IVault, AccessControl, ReentrancyGuard {
//     using SafeERC20 for IERC20;
//     //using FixedPointMath for uint256;

//     /// Role for the entities that will manage the vault
//     bytes32 public constant GOVERNOR = keccak256("GOVERNOR_ROLE");
//     /// Role for the strategies that will use the vault's assets
//     bytes32 public constant STRATEGIES = keccak256("STRATEGIES_ROLE");

//     /// The asset that can be deposited into the vault
//     address public immutable asset;
//     /// The shares that will represent the deposits
//     address public immutable share;

//     /// Snapshot of total shares supply from previous epoch / before management starts
//     uint256 public snapshotSharesSupply;

//     /// Snapshot of total asset supply from previous epoch / before management starts
//     uint256 public snapshotAssetBalance;

//     /// Max amount of assets that can be deposited into the vault
//     uint256 public vaultCap;

//     /// `true` if the vault should charge management & performance fees, `false` otherwise
//     bool public chargeFees;
//     /// The address that will receive the fees
//     address public feeDistributor;

//     /// By default, deposits and withdrawals can only be called by
//     /// allowed users (ie when `msg.sender` is not a contract). This
//     /// mapping can be used to whitelist contracts that need to be able to
//     /// perform deposits and withdrawals.
//     mapping(address => bool) public whitelistedContract;

//     /// The current state of the vault
//     State public state = State.INITIAL;

//     /**
//      * @param _asset The address of the asset that can be deposited into the vault
//      * @param _share The address of the asset that will represent deposits
//      * @param _governor The address of the entity that will manage the vault
//      * @param _feeDistributor The address of the entity that will receive fees
//      * @param _vaultCap The initial vault cap
//      */
//     constructor(
//         address _asset,
//         address _share,
//         address _governor,
//         address _feeDistributor,
//         uint256 _vaultCap
//     ) {
//         if (_asset == address(0)) {
//             revert INVALID_ADDRESS();
//         }

//         if (_share == address(0)) {
//             revert INVALID_ADDRESS();
//         }

//         if (_governor == address(0)) {
//             revert INVALID_ADDRESS();
//         }

//         if (_feeDistributor == address(0)) {
//             revert INVALID_ADDRESS();
//         }

//         asset = _asset;
//         share = _share;
//         feeDistributor = _feeDistributor;
//         vaultCap = _vaultCap;

//         // Default value for snapshot. Will be overridden when calling `initialRun`
//         snapshotSharesSupply = 1;
//         snapshotAssetBalance = 1;

//         // Grant roles
//         _grantRole(GOVERNOR, _governor);
//     }

//     // ============================= View functions ================================

//     /**
//      * @inheritdoc IVault
//      */
//     function convertToShares(uint256 _assets)
//         public
//         view
//         virtual
//         override
//         returns (uint256)
//     {
//         uint256 supply = snapshotSharesSupply;
//         return
//             supply == 0
//                 ? _assets
//                 : _assets.mulDivDown(supply, snapshotAssetBalance);
//     }

//     /**
//      * @dev We charge fees at the end of an epoch so it doens't make sense to calculate fees here
//      * @inheritdoc IVault
//      */
//     function previewDeposit(uint256 _assets)
//         public
//         view
//         virtual
//         override
//         returns (uint256)
//     {
//         return convertToShares(_assets);
//     }

//     /**
//      * @inheritdoc IVault
//      */
//     function convertToAssets(uint256 _shares)
//         public
//         view
//         virtual
//         override
//         returns (uint256)
//     {
//         uint256 supply = snapshotSharesSupply;
//         return
//             supply == 0
//                 ? _shares
//                 : _shares.mulDivDown(snapshotAssetBalance, supply);
//     }

//     /**
//      * @inheritdoc IVault
//      */
//     function maxWithdraw(address _owner)
//         public
//         view
//         virtual
//         override
//         returns (uint256)
//     {
//         return convertToAssets(JonesAsset(share).balanceOf(_owner));
//     }

//     /**
//      * @inheritdoc IVault
//      */
//     function maxDeposit(address)
//         public
//         view
//         virtual
//         override
//         returns (uint256)
//     {
//         // If management window is open deposits are disabled
//         if (state == State.INITIAL || state == State.MANAGED) {
//             return 0;
//         }

//         // If vault cap was breached deposits are disabled
//         if (totalAssets() >= vaultCap) {
//             return 0;
//         }

//         return vaultCap;
//     }

//     /**
//      * @dev If the vault deposit assets in farms, those should be considered here too
//      * @inheritdoc IVault
//      */
//     function totalAssets() public view virtual override returns (uint256) {
//         if (state == State.MANAGED) {
//             return snapshotAssetBalance;
//         }

//         return IERC20(asset).balanceOf(address(this));
//     }

//     /**
//      * @inheritdoc IVault
//      */
//     function maxMint(address) public view virtual override returns (uint256) {
//         return type(uint256).max;
//     }

//     /**
//      * @inheritdoc IVault
//      */
//     function previewMint(uint256 _shares)
//         public
//         view
//         virtual
//         override
//         returns (uint256)
//     {
//         uint256 supply = snapshotSharesSupply;
//         return
//             supply == 0
//                 ? _shares
//                 : _shares.mulDivUp(snapshotAssetBalance, supply);
//     }

//     /**
//      * @inheritdoc IVault
//      */
//     function previewWithdraw(uint256 _assets)
//         public
//         view
//         virtual
//         override
//         returns (uint256)
//     {
//         uint256 supply = snapshotSharesSupply;
//         return
//             supply == 0
//                 ? _assets
//                 : _assets.mulDivUp(supply, snapshotAssetBalance);
//     }

//     /**
//      * @inheritdoc IVault
//      */
//     function maxRedeem(address _owner)
//         public
//         view
//         virtual
//         override
//         returns (uint256)
//     {
//         return JonesAsset(share).balanceOf(_owner);
//     }

//     /**
//      * @inheritdoc IVault
//      */
//     function previewRedeem(uint256 _shares)
//         public
//         view
//         virtual
//         override
//         returns (uint256)
//     {
//         return convertToAssets(_shares);
//     }

//     // ============================= User functions ================================

//     /**
//      * @inheritdoc IVault
//      */
//     function deposit(uint256 _assets, address _receiver)
//         public
//         virtual
//         override
//         nonReentrant
//         returns (uint256 shares)
//     {
//         _senderIsEligible();
//         _onState(State.UNMANAGED);

//         if (_assets == 0) {
//             revert INVALID_ASSETS_AMOUNT();
//         }

//         _checkDepositAmountIsValid(_assets);
//         shares = previewDeposit(_assets);

//         // Check for rounding error since we round down in previewDeposit.
//         if (shares == 0) {
//             revert ZERO_SHARES_AVAILABLE_WHEN_DEPOSITING();
//         }

//         _mint(_receiver, _assets, shares);
//     }

//     /**
//      * @inheritdoc IVault
//      */
//     function mint(uint256 _shares, address _receiver)
//         public
//         virtual
//         override
//         nonReentrant
//         returns (uint256 assets)
//     {
//         _senderIsEligible();
//         _onState(State.UNMANAGED);

//         if (_shares == 0) {
//             revert INVALID_SHARES_AMOUNT();
//         }

//         assets = previewMint(_shares); // No need to check for rounding error, previewMint rounds up.
//         _checkDepositAmountIsValid(assets);
//         _mint(_receiver, assets, _shares);
//     }

//     /**
//      * @inheritdoc IVault
//      */
//     function withdraw(
//         uint256 _assets,
//         address _receiver,
//         address
//     ) public virtual override nonReentrant returns (uint256 shares) {
//         _onState(State.UNMANAGED);
//         if (_assets == 0) {
//             revert INVALID_ASSETS_AMOUNT();
//         }
//         shares = previewWithdraw(_assets); // No need to check for rounding error, previewWithdraw rounds up.

//         _burn(_receiver, _assets, shares);
//     }

//     /**
//      * @inheritdoc IVault
//      */
//     function redeem(
//         uint256 _shares,
//         address _receiver,
//         address
//     ) public virtual override nonReentrant returns (uint256 assets) {
//         _onState(State.UNMANAGED);

//         assets = previewRedeem(_shares);
//         // Check for rounding error since we round down in previewRedeem.
//         if (assets == 0) {
//             revert INVALID_ASSETS_AMOUNT();
//         }

//         _burn(_receiver, assets, _shares);
//     }

//     // ============================= Strategy functions ================================

//     /**
//      * @inheritdoc IVault
//      */
//     function pull(uint256 _assets)
//         public
//         virtual
//         override
//         onlyRole(STRATEGIES)
//     {
//         _onState(State.MANAGED);
//         if (_assets == 0) {
//             revert INVALID_ASSETS_AMOUNT();
//         }
//         IERC20(asset).safeTransfer(msg.sender, _assets);
//     }

//     /**
//      * @inheritdoc IVault
//      */
//     function depositStrategyFunds(uint256 _assets)
//         public
//         virtual
//         override
//         onlyRole(STRATEGIES)
//     {
//         _onState(State.MANAGED);
//         if (_assets == 0) {
//             revert INVALID_ASSETS_AMOUNT();
//         }
//         IERC20(asset).safeTransferFrom(msg.sender, address(this), _assets);
//     }

//     // ============================= Admin functions ================================

//     /**
//      * @inheritdoc IVault
//      */
//     function whitelistStrategy(address _strategyAddress)
//         public
//         virtual
//         override
//         onlyRole(GOVERNOR)
//     {
//         _grantRole(STRATEGIES, _strategyAddress);
//     }

//     /**
//      * @inheritdoc IVault
//      */
//     function removeStrategyFromWhitelist(address _strategyAddress)
//         public
//         virtual
//         override
//         onlyRole(GOVERNOR)
//     {
//         _revokeRole(STRATEGIES, _strategyAddress);
//     }

//     /**
//      * @inheritdoc IVault
//      */
//     function addContractAddressToWhitelist(address _contractAddress)
//         public
//         virtual
//         override
//         onlyRole(GOVERNOR)
//     {
//         whitelistedContract[_contractAddress] = true;
//     }

//     /**
//      * @inheritdoc IVault
//      */
//     function removeContractAddressFromWhitelist(address _contractAddress)
//         public
//         virtual
//         override
//         onlyRole(GOVERNOR)
//     {
//         whitelistedContract[_contractAddress] = false;
//     }

//     /**
//      * @inheritdoc IVault
//      */
//     function migrate(address _to, address[] memory _tokens)
//         public
//         virtual
//         override
//         onlyRole(GOVERNOR)
//     {
//         // migrate other ERC20 Tokens
//         for (uint256 i = 0; i < _tokens.length; i++) {
//             IERC20 token = IERC20(_tokens[i]);
//             uint256 assetBalance = token.balanceOf(address(this));
//             if (assetBalance > 0) {
//                 token.transfer(_to, assetBalance);
//             }
//         }

//         // migrate ETH balance
//         uint256 balanceGwei = address(this).balance;
//         if (balanceGwei > 0) {
//             payable(_to).transfer(balanceGwei);
//         }
//     }

//     /**
//      * @inheritdoc IVault
//      */
//     function setVaultCap(uint256 _amount)
//         public
//         virtual
//         override
//         onlyRole(GOVERNOR)
//     {
//         vaultCap = _amount;
//     }

//     /**
//      * @inheritdoc IVault
//      */
//     function setChargeFees(bool _status)
//         public
//         virtual
//         override
//         onlyRole(GOVERNOR)
//     {
//         chargeFees = _status;
//     }

//     function setFeeDistributor(address _feeDistributor)
//         public
//         virtual
//         override
//         onlyRole(GOVERNOR)
//     {
//         if (_feeDistributor == address(0)) {
//             revert INVALID_ADDRESS();
//         }

//         feeDistributor = _feeDistributor;
//     }

//     /**
//      * @inheritdoc IVault
//      */
//     function initialRun(
//         uint256 _snapshotAssetBalance,
//         uint256 _snapshotSharesSupply
//     ) public virtual override onlyRole(GOVERNOR) {
//         _onState(State.INITIAL);

//         if (_snapshotAssetBalance == 0 || _snapshotSharesSupply == 0) {
//             revert INVALID_SNAPSHOT_VALUE();
//         }

//         snapshotAssetBalance = _snapshotAssetBalance;
//         snapshotSharesSupply = _snapshotSharesSupply;

//         state = State.UNMANAGED;

//         emit EpochEnded(
//             block.timestamp,
//             snapshotAssetBalance,
//             snapshotSharesSupply
//         );
//     }

//     /**
//      * @inheritdoc IVault
//      */
//     function openManagementWindow() public virtual override onlyRole(GOVERNOR) {
//         _onState(State.UNMANAGED);

//         _beforeOpenManagementWindow();

//         state = State.MANAGED;

//         emit EpochStarted(
//             block.timestamp,
//             snapshotAssetBalance,
//             snapshotSharesSupply
//         );

//         _afterOpenManagementWindow();
//     }

//     /**
//      * @inheritdoc IVault
//      */
//     function closeManagementWindow()
//         public
//         virtual
//         override
//         onlyRole(GOVERNOR)
//     {
//         _onState(State.MANAGED);

//         _beforeCloseManagementWindow();

//         state = State.UNMANAGED;

//         emit EpochEnded(
//             block.timestamp,
//             snapshotAssetBalance,
//             snapshotSharesSupply
//         );

//         _afterCloseManagementWindow();
//     }

//     // ============================= INTERNAL HOOKS LOGIC ================================
//     function _beforeWithdraw(uint256 _assets, uint256 _shares) internal virtual;

//     function _afterDeposit(uint256 _assets, uint256 _shares) internal virtual;

//     /**
//      * @notice Executed before updating the `state` on `closeManagementWindow()`
//      */
//     function _beforeOpenManagementWindow() internal virtual {
//         // Snapshot asset and share supply
//         _executeSnapshot();
//     }

//     /**
//      * @notice Executed after updating the `state` on `closeManagementWindow()`
//      */
//     function _afterOpenManagementWindow() internal virtual;

//     /**
//      * @notice Executed before updating the `state` on `openmanagementWindow()`
//      */
//     function _beforeCloseManagementWindow() internal virtual {
//         // Charge fees
//         _chargeFees();

//         // Snapshot asset and share supply
//         _executeSnapshot();
//     }

//     /**
//      * @notice Executed after updating the `state` on `openmanagementWindow()`
//      */
//     function _afterCloseManagementWindow() internal virtual;

//     // ============================== Helpers ==============================
//     /**
//      * @notice Mint `_shares` to `_receiver` and receives `_assets`
//      * @dev It doesn't provide any checks so use carefully
//      * @param _receiver The address that will receive the minted shares
//      * @param _assets The amount of assets to transfer to the vault
//      * @param _shares The amount of shares to mint
//      */
//     function _mint(
//         address _receiver,
//         uint256 _assets,
//         uint256 _shares
//     ) internal virtual {
//         IERC20(asset).safeTransferFrom(msg.sender, address(this), _assets);
//         JonesAsset(share).mint(_receiver, _shares);
//         emit Deposit(msg.sender, _receiver, _assets, _shares);
//         _afterDeposit(_assets, _shares);
//     }

//     /**
//      * @notice Burn `_shares` from `msg.sender` transfer `_assets` to `_receiver`
//      * @dev It doesn't provide any checks so use carefully
//      * @param _receiver The address that will receive the asset tokens
//      * @param _assets The amount of assets to transfer to `_receiver`
//      * @param _shares The amount of shares to burn from `owner`
//      */
//     function _burn(
//         address _receiver,
//         uint256 _assets,
//         uint256 _shares
//     ) internal virtual {
//         _beforeWithdraw(_assets, _shares);

//         JonesAsset(share).burnFrom(msg.sender, _shares);
//         emit Withdraw(msg.sender, _receiver, msg.sender, _assets, _shares);
//         IERC20(asset).safeTransfer(_receiver, _assets);
//     }

//     function _senderIsEligible() internal view {
//         if (msg.sender != tx.origin) {
//             if (!whitelistedContract[msg.sender]) {
//                 revert CONTRACT_ADDRESS_MAKING_PROHIBITED_FUNCTION_CALL();
//             }
//         }
//     }

//     /**
//      * Checks if `assets` amount is depositable given the vault cap. Reverts if amount is invalid.
//      */
//     function _checkDepositAmountIsValid(uint256 _assets) internal virtual {
//         if (vaultCap < type(uint256).max) {
//             if (totalAssets() + _assets > vaultCap) {
//                 revert DEPOSIT_ASSET_AMOUNT_EXCEEDS_MAX_DEPOSIT();
//             }
//         }
//     }

//     /**
//      * @notice Checks if the vault is on `_expectedState`
//      * @dev Will revert if `_expectedState != state`
//      */
//     function _onState(State _expectedState) internal view virtual {
//         if (state != _expectedState) {
//             revert INVALID_STATE(_expectedState, state);
//         }
//     }

//     /**
//      * @notice Takes a snapshot of the deposited assets and the minted shares
//      */
//     function _executeSnapshot() internal virtual {
//         snapshotSharesSupply = JonesAsset(share).totalSupply();
//         snapshotAssetBalance = IERC20(asset).balanceOf(address(this));

//         emit Snapshot(
//             block.timestamp,
//             snapshotAssetBalance,
//             snapshotSharesSupply
//         );
//     }

//     /**
//      * @notice Charges management & performance fees.
//      * @dev Fees are transferred to `feeDistributor`.
//      * @dev Only if `chargeFees == true`.
//      */
//     function _chargeFees() internal virtual {
//         if (chargeFees) {
//             uint256 balanceNow = IERC20(asset).balanceOf(address(this));

//             if (balanceNow > snapshotAssetBalance) {
//                 // send performance fee to fee distributor (20% on profit wrt benchmark)
//                 // 1 / 5 = 20 / 100
//                 IERC20(asset).safeTransfer(
//                     feeDistributor,
//                     (balanceNow - snapshotAssetBalance) / 5
//                 );
//             }
//             // send management fee to fee distributor (2% annually)
//             // 1 / 600 = 2 / (100 * 12)
//             IERC20(asset).safeTransfer(
//                 feeDistributor,
//                 snapshotAssetBalance / 600
//             );
//         }
//     }
// }
