// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract yVault is ERC20, Ownable {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;
    
    struct TokenDeposit {
      uint256 depositAmount;
      uint256 depositTime;
      uint256 lastInterestPaymentTime;
    }

    enum LockupKind {
      NO_LOCKUP,
      EIGHT_WEEK_LOCKUP,
      ONE_YEAR_LOCKUP
    }

    // APY Rates
    uint256 private constant NO_LOCKUP_APY = 0.12e18; // 12%
    uint256 private constant EIGHT_WEEK_LOCKUP_APY = 0.20e18; // 20%
    uint256 private constant ONE_YEAR_LOCKUP_APY = 0.35e18; // 35%     

    // Withdrawal Fees
    uint256 private constant FIXED_LOCKUP_EARLY_WITHDRAWAL_FEE = 0.15e18; // 15%     

    // This will be DAI, but is generically defined for good abstraction practice
    IERC20 public token;

    // userAddress => LockupKind => tokenDeposit object
    mapping (address => mapping(LockupKind => TokenDeposit[])) userTokenDepositsByLockupType;

    mapping (address => uint256) yTokenBalances;

    constructor(address _token) public ERC20(
      string(abi.encodePacked("yearn ", ERC20(_token).name())),
      string(abi.encodePacked("y", ERC20(_token).symbol()))
    ) {
      token = IERC20(_token);    
    }

    event TokenDepositComplete(IERC20 tokenAddress, uint256 amount, uint256 lockupTime);
    event TokenWithdrawalComplete(IERC20 tokenAddress, uint256 amount);
    event exchangeYTokenComplete(IERC20 tokenAddress, uint256 amount);

    function addTokenDeposit(uint256 amount, LockupKind lockupType) public  {
        require(token.balanceOf(msg.sender) >= amount, "Your token amount must be greater then you are trying to deposit");
        token.safeApprove(address(this), amount);
        token.safeTransferFrom(msg.sender, address(this), amount);

        TokenDeposit memory deposit;
        deposit.depositAmount = amount;
        deposit.depositTime = block.timestamp;
        deposit.lastInterestPaymentTime = block.timestamp;
        userTokenDepositsByLockupType[msg.sender][lockupType].push(deposit);
        
        emit TokenDepositComplete(token, amount, deposit.depositTime);
    }


    function exchangeYTokenForToken() public {
        require(balanceOf(msg.sender) > 0, "User doesnt has funds on this vault");
        uint256 amount = balanceOf(msg.sender);
        _burn(msg.sender, amount);

        // Send Token(DAI) from this contract to the user who exchanged yToken(yDAI)
        token.safeTransfer(msg.sender, amount);
        emit exchangeYTokenComplete(token, amount);
    }

    function withdrawAmountFromLockup(uint256 amount, LockupKind lockupType) public {
        if (lockupType == LockupKind.NO_LOCKUP) {
          // Withdraw No Lockup Tokens
        } else {
          // Handle Withdrawing Fixed Lockup Tokens
          if (lockupType == LockupKind.EIGHT_WEEK_LOCKUP) {
            
          } else if (lockupType == LockupKind.ONE_YEAR_LOCKUP) {

          }
        }

        // require(userTokenBalance[msg.sender][tokenAddress] >= amount);
        // require(IERC20(tokenAddress).transfer(msg.sender, amount), "the transfer failed");
        // userTokenBalance[msg.sender][tokenAddress] -= amount;
        // uint256 yDaiReceived;
        // _mint(msg.sender, yDaiReceived);
        // emit tokenWithdrawalComplete(tokenAddress, amount);
    }

    // Allow User to claim in wrapped or unwrapped form
    function claimYInterest(bool wrapped) public {
      
      TokenDeposit[] storage noLockupDeposits = userTokenDepositsByLockupType[msg.sender][LockupKind.NO_LOCKUP];
      uint256 interestPayment = 0;
      for (uint i = 0; i < noLockupDeposits.length; i++) {
        TokenDeposit storage userDeposit = noLockupDeposits[i];
        interestPayment += calculateInterestPayments(userDeposit, LockupKind.NO_LOCKUP);
      }

      TokenDeposit[] storage eightWeekDeposits = userTokenDepositsByLockupType[msg.sender][LockupKind.EIGHT_WEEK_LOCKUP];
      for (uint i = 0; i < eightWeekDeposits.length; i++) {
        TokenDeposit storage userDeposit = eightWeekDeposits[i];
        interestPayment += calculateInterestPayments(userDeposit, LockupKind.EIGHT_WEEK_LOCKUP);
      }

      TokenDeposit[] storage oneYearDeposits = userTokenDepositsByLockupType[msg.sender][LockupKind.ONE_YEAR_LOCKUP];
      for (uint i = 0; i < oneYearDeposits.length; i++) {
        TokenDeposit storage userDeposit = oneYearDeposits[i];
        interestPayment += calculateInterestPayments(userDeposit, LockupKind.ONE_YEAR_LOCKUP);
      }
      if (!wrapped) _mint(msg.sender, interestPayment.mul(10 ** uint256(decimals())));
      else yTokenBalances[msg.sender] = yTokenBalances[msg.sender].add(interestPayment);
    }

    function calculateInterestPayments(TokenDeposit storage tokenDeposit, LockupKind lockupType) private
      returns (uint256 payment) 
    {
      uint256 weeksSinceLastPayment = block.timestamp.sub(tokenDeposit.lastInterestPaymentTime).div(1 weeks);
      if (weeksSinceLastPayment > 0) {
        tokenDeposit.lastInterestPaymentTime = tokenDeposit.lastInterestPaymentTime.add(weeksSinceLastPayment);
        if (lockupType == LockupKind.NO_LOCKUP) {
          payment = (tokenDeposit.depositAmount.mul((NO_LOCKUP_APY.div(52)))).mul(weeksSinceLastPayment);
        } else if (lockupType == LockupKind.EIGHT_WEEK_LOCKUP){
          payment = (tokenDeposit.depositAmount.mul((EIGHT_WEEK_LOCKUP_APY.div(52)))).mul(weeksSinceLastPayment);
        } else if (lockupType == LockupKind.ONE_YEAR_LOCKUP){
          payment = (tokenDeposit.depositAmount.mul((ONE_YEAR_LOCKUP_APY.div(52)))).mul(weeksSinceLastPayment);
        }
      }
    }

    // function updateYVaultDeposits() public {

    // }

}