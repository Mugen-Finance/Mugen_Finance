//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.7;

interface IJonesVaultV3 {
    // ============================= View functions ================================

    function convertToShares(uint256 _assets) external view returns (uint256);

    function previewDeposit(uint256 _assets) external view returns (uint256);

    function convertToAssets(uint256 _shares) external view returns (uint256);

    function maxWithdraw(address _owner) external view returns (uint256);

    function maxDeposit(address) external view returns (uint256);

    function totalAssets() external view returns (uint256);

    function maxMint(address) external view returns (uint256);

    function previewMint(uint256 _shares) external view returns (uint256);

    function previewWithdraw(uint256 _assets) external view returns (uint256);

    function maxRedeem(address _owner) external view returns (uint256);

    function previewRedeem(uint256 _shares) external view returns (uint256);

    // ============================= User functions ================================

    function deposit(uint256 _assets, address _receiver)
        external
        returns (uint256 shares);

    function mint(uint256 _shares, address _receiver)
        external
        returns (uint256 assets);

    function withdraw(
        uint256 _assets,
        address _receiver,
        address
    ) external returns (uint256 shares);

    function redeem(
        uint256 _shares,
        address _receiver,
        address
    ) external returns (uint256 assets);
}
