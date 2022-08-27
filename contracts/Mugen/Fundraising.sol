//SPDX-License-Identifier: MIT;

pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract Fundraiser is ERC20, Pausable {
    error FundReached();
    error Cooldown();
    error NoDebt();

    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    address public asset;
    address public fund;
    address public owner;
    uint256 public debt;
    uint256 public payments;
    uint256 public remaining;

    mapping(address => uint256) public cooldown;

    event Deposit(address indexed Creditor, uint256 Amount, uint256 DebtTakenOn);
    event Payment(address indexed Debtor, uint256 PayedBack, uint256 RemainingDebt);
    event Claimed(address indexed Claimer, uint256 paid, uint256 CooldownEnd);

    constructor(address _asset, address _fund) ERC20("Mugen Debt Token", "dtMugen") {
        asset = _asset;
        fund = _fund;
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not Owner");
        _;
    }

    function deposit(uint256 amount) external whenNotPaused {
        if (debt >= 1500000 * 1e18) {
            revert FundReached();
        }
        uint256 _debt = amount.mul(5).div(2);
        debt += _debt;
        IERC20(asset).safeTransferFrom(msg.sender, fund, amount);
        _mint(msg.sender, _debt);
        emit Deposit(msg.sender, amount, _debt);
    }

    function rewardPerToken() public view returns (uint256) {
        return ((IERC20(asset).balanceOf(address(this)) * 1e18) / totalSupply());
    }

    /**
     * @notice How much reward a user has earned
     */
    function earned(address account) public view returns (uint256) {
        return ((balanceOf(account) * rewardPerToken()) / 1e18);
    }

    function payDebt(uint256 amount) external onlyOwner {
        if (totalSupply() <= 0) {
            revert NoDebt();
        }
        remaining = totalSupply() - amount;
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        emit Payment(msg.sender, amount, remaining);
    }

    function claimPayment() external {
        require(block.timestamp > cooldown[msg.sender], "Still in Cooldown");
        cooldown[msg.sender] = block.timestamp + 7 days;
        uint256 nextAvailableClaim = cooldown[msg.sender];
        uint256 _payment = earned(msg.sender);
        IERC20(asset).safeTransfer(msg.sender, _payment);
        _burn(msg.sender, _payment);
        emit Claimed(msg.sender, _payment, nextAvailableClaim);
    }

    function getRemainingDebt() external view returns (uint256 _debt) {
        return remaining;
    }

    function getCoolDownEnd(address account) external view returns (uint256 cooldownBlockNumber) {
        return cooldown[account];
    }
}
