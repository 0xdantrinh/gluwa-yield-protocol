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

    constructor(address _token) public ERC20("yDai", "YDAI") {
      token = IERC20(_token);    
    }

    event TokenDepositComplete(address depositor, uint256 amount, uint256 lockupTime);
    event TokenWithdrawalComplete(address withdrawer, LockupKind lockupType, uint256 amount);
    event exchangeYTokenComplete(address exchanger, uint256 amount);

    function addTokenDeposit(uint256 amount, LockupKind lockupType) public  {
        require(token.balanceOf(msg.sender) >= amount, "Your token amount must be greater then you are trying to deposit");
        uint256 allowance = token.allowance(msg.sender, address(this));
        require(allowance >= amount, "Check the token allowance");

        token.safeTransferFrom(msg.sender, address(this), amount);

        TokenDeposit memory deposit;
        deposit.depositAmount = amount;
        deposit.depositTime = block.timestamp;
        deposit.lastInterestPaymentTime = block.timestamp;
        userTokenDepositsByLockupType[msg.sender][lockupType].push(deposit);
        
        emit TokenDepositComplete(msg.sender, amount, deposit.depositTime);
    }


    function exchangeYTokenForToken() public {
        require(balanceOf(msg.sender) > 0, "User doesnt has funds on this vault");
        uint256 amount = balanceOf(msg.sender);
        _burn(msg.sender, amount);

        // Send Token(DAI) from this contract to the user who exchanged yToken(yDAI)
        token.safeTransfer(msg.sender, amount);
        emit exchangeYTokenComplete(msg.sender, amount);
    }

    function withdrawAmount(uint256 noLockupAmountToWithdraw, LockupKind lockupType) public 
      returns(uint256 withdrawnAmount) {
        if (lockupType == LockupKind.NO_LOCKUP) {
          // Claim Rest of Interest for the User
          // Withdraw No Lockup Token
          console.log("withdrawing no lockup");
          withdrawnAmount = calculateNoLockupInterestPaymentsAndWithdraw(noLockupAmountToWithdraw, userTokenDepositsByLockupType[msg.sender][LockupKind.NO_LOCKUP]);
        } else {
          // Handle Withdrawing Fixed Lockup Token
          // Must withdraw All
          if (lockupType == LockupKind.EIGHT_WEEK_LOCKUP) {
            TokenDeposit[] storage eightWeekDeposits = userTokenDepositsByLockupType[msg.sender][LockupKind.EIGHT_WEEK_LOCKUP];
            for (uint i = 0; i < eightWeekDeposits.length; i++) {
              // Claim Rest of Interest for the User
              TokenDeposit storage userDeposit = eightWeekDeposits[i];
              withdrawnAmount = withdrawnAmount.add(calculateFixedInterestPaymentAndWithdraw(userDeposit, LockupKind.EIGHT_WEEK_LOCKUP));
            }
          } else if (lockupType == LockupKind.ONE_YEAR_LOCKUP) {
            TokenDeposit[] storage oneYearDeposits = userTokenDepositsByLockupType[msg.sender][LockupKind.ONE_YEAR_LOCKUP];
            for (uint i = 0; i < oneYearDeposits.length; i++) {
              // Claim Rest of Interest for the User
              TokenDeposit storage userDeposit = oneYearDeposits[i];
              withdrawnAmount = withdrawnAmount.add(calculateFixedInterestPaymentAndWithdraw(userDeposit, LockupKind.ONE_YEAR_LOCKUP));
            }
          }
        }

        require(withdrawnAmount > 0, "Must withdraw more than 0");
        token.safeTransfer(msg.sender, withdrawnAmount);
        emit TokenWithdrawalComplete(msg.sender, lockupType, withdrawnAmount);
    }

    // Allow User to claim in wrapped or unwrapped form
    function claimYInterestWithoutWithdrawal(bool wrapped) public {
      
      TokenDeposit[] storage noLockupDeposits = userTokenDepositsByLockupType[msg.sender][LockupKind.NO_LOCKUP];
      uint256 interestPayment = 0;
      for (uint i = 0; i < noLockupDeposits.length; i++) {
        TokenDeposit storage userDeposit = noLockupDeposits[i];
        interestPayment += calculateInterestPayment(userDeposit, LockupKind.NO_LOCKUP);
      }

      TokenDeposit[] storage eightWeekDeposits = userTokenDepositsByLockupType[msg.sender][LockupKind.EIGHT_WEEK_LOCKUP];
      for (uint i = 0; i < eightWeekDeposits.length; i++) {
        TokenDeposit storage userDeposit = eightWeekDeposits[i];
        interestPayment += calculateInterestPayment(userDeposit, LockupKind.EIGHT_WEEK_LOCKUP);
      }

      TokenDeposit[] storage oneYearDeposits = userTokenDepositsByLockupType[msg.sender][LockupKind.ONE_YEAR_LOCKUP];
      for (uint i = 0; i < oneYearDeposits.length; i++) {
        TokenDeposit storage userDeposit = oneYearDeposits[i];
        interestPayment += calculateInterestPayment(userDeposit, LockupKind.ONE_YEAR_LOCKUP);
      }
      require(interestPayment > 0, "No Interest to be paid out for Account Yet");
      if (!wrapped) _mint(msg.sender, interestPayment);
      else yTokenBalances[msg.sender] = yTokenBalances[msg.sender].add(interestPayment);
    }

    function calculateInterestPayment(TokenDeposit storage tokenDeposit, LockupKind lockupType) private
      returns (uint256 payment) 
    {
      uint256 weeksSinceLastPayment = block.timestamp.sub(tokenDeposit.lastInterestPaymentTime).div(1 weeks);
      if (weeksSinceLastPayment > 0) {
        uint256 lastPayment = tokenDeposit.lastInterestPaymentTime.add(weeksSinceLastPayment);
        tokenDeposit.lastInterestPaymentTime = lastPayment;
        if (lockupType == LockupKind.NO_LOCKUP) {
          // TODO IMPLEMENT 18 DECIMAL MATH TO PROPERLY CALCULATE INTEREST AND FEEDS
          payment = (tokenDeposit.depositAmount.mul((NO_LOCKUP_APY.div(52)))).mul(weeksSinceLastPayment);
        } else if (lockupType == LockupKind.EIGHT_WEEK_LOCKUP){
        // TODO IMPLEMENT 18 DECIMAL MATH TO PROPERLY CALCULATE INTEREST AND FEEDS          
          payment = (tokenDeposit.depositAmount.mul((EIGHT_WEEK_LOCKUP_APY.div(52)))).mul(weeksSinceLastPayment);
        } else if (lockupType == LockupKind.ONE_YEAR_LOCKUP){
        // TODO IMPLEMENT 18 DECIMAL MATH TO PROPERLY CALCULATE INTEREST AND FEEDS
          payment = (tokenDeposit.depositAmount.mul((ONE_YEAR_LOCKUP_APY.div(52)))).mul(weeksSinceLastPayment);
        }
      }
    }

    function calculateNoLockupInterestPaymentsAndWithdraw(uint256 amountToWithdraw, TokenDeposit[] storage tokenDeposits) private
      returns (uint256 payment) 
    {
      for (uint i = 0; i < tokenDeposits.length; i++) {
        uint256 weeksSinceLastPayment = block.timestamp.sub(tokenDeposits[i].lastInterestPaymentTime).div(1 weeks);
        if (tokenDeposits[i].depositAmount > amountToWithdraw) {
          uint256 lastPayment = tokenDeposits[i].lastInterestPaymentTime.add(weeksSinceLastPayment);
          tokenDeposits[i].lastInterestPaymentTime = lastPayment;
          // TODO IMPLEMENT 18 DECIMAL MATH TO PROPERLY CALCULATE INTEREST AND FEEDS          
          payment = amountToWithdraw.add((tokenDeposits[i].depositAmount.mul((NO_LOCKUP_APY.div(52)))).mul(weeksSinceLastPayment));
          tokenDeposits[i].depositAmount = tokenDeposits[i].depositAmount.sub(amountToWithdraw);
          return payment;
        } else if (tokenDeposits[i].depositAmount == amountToWithdraw) {
          // TODO IMPLEMENT 18 DECIMAL MATH TO PROPERLY CALCULATE INTEREST AND FEEDS
          payment = tokenDeposits[i].depositAmount.add((tokenDeposits[i].depositAmount.mul((NO_LOCKUP_APY.div(52)))).mul(weeksSinceLastPayment));
          delete tokenDeposits[i];
          return payment;
        } else {
          // TODO IMPLEMENT 18 DECIMAL MATH TO PROPERLY CALCULATE INTEREST AND FEEDS
          payment = tokenDeposits[i].depositAmount.add((tokenDeposits[i].depositAmount.mul((NO_LOCKUP_APY.div(52)))).mul(weeksSinceLastPayment));
          amountToWithdraw = amountToWithdraw.sub(tokenDeposits[i].depositAmount);
          delete tokenDeposits[i];
        }
      }
    }

    function calculateFixedInterestPaymentAndWithdraw(TokenDeposit memory tokenDeposit, LockupKind lockupType) private view
      returns (uint256 paymentAndWithdrawal) 
    {
      uint256 weeksSinceLastPayment = block.timestamp.sub(tokenDeposit.lastInterestPaymentTime).div(1 weeks);
      if (lockupType == LockupKind.EIGHT_WEEK_LOCKUP){
        //Charge early withdrawal fees
        // TODO IMPLEMENT 18 DECIMAL MATH TO PROPERLY CALCULATE INTEREST AND FEEDS
        paymentAndWithdrawal = (tokenDeposit.depositAmount.mul((EIGHT_WEEK_LOCKUP_APY.div(52)))).mul(weeksSinceLastPayment);
        paymentAndWithdrawal = paymentAndWithdrawal.add(tokenDeposit.depositAmount.mul(uint256(1).sub(FIXED_LOCKUP_EARLY_WITHDRAWAL_FEE)));
      } else if (lockupType == LockupKind.ONE_YEAR_LOCKUP){
        //Charge early withdrawal fees
        // TODO IMPLEMENT 18 DECIMAL MATH TO PROPERLY CALCULATE INTEREST AND FEEDS
        paymentAndWithdrawal = (tokenDeposit.depositAmount.mul((ONE_YEAR_LOCKUP_APY.div(52)))).mul(weeksSinceLastPayment);
        paymentAndWithdrawal = paymentAndWithdrawal.add(tokenDeposit.depositAmount.mul(1 - FIXED_LOCKUP_EARLY_WITHDRAWAL_FEE));
      }
    }

    function unwrapYTokens() public {
      uint256 amount = yTokenBalances[msg.sender];
      require(amount > 0, "You must have wrapped yTokens to unwrap");
      yTokenBalances[msg.sender] = 0;
      _mint(msg.sender, amount);
    }

}