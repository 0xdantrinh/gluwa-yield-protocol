// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract yVault is ERC20 {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;
    
    struct tokenDeposit {
      uint256 depositAmount;
      uint256 depositTime;
    }

    enum LockupKind {
      NO_LOCKUP,
      EIGHT_WEEK_LOCKUP,
      ONE_YEAR_LOCKUP
    }

    IERC20 public token;
    mapping (address => mapping(LockupKind => tokenDeposit[])) userTokenDepositsByLockup;

    constructor(address _token) public ERC20(
      string(abi.encodePacked("yearn ", ERC20(_token).name())),
      string(abi.encodePacked("y", ERC20(_token).symbol()))
    ) {
      token = IERC20(_token);    
    }
     
    // userAddress => tokenAddress => token amount
    mapping (address => mapping (address => uint256)) userTokenBalance;

    event tokenDepositComplete(address tokenAddress, uint256 amount, uint256 lockupTime);
    event tokenWithdrawalComplete(address tokenAddress, uint256 amount);

    function depositToken( uint256 amount) public  {
        require(token.balanceOf(msg.sender) >= amount, "Your token amount must be greater then you are trying to deposit");
        token.safeApprove(address(this), amount);
        require(token.safeTransferFrom(msg.sender, address(this), amount));

        userTokenBalance[msg.sender][tokenAddress] += amount;
        
        emit tokenDepositComplete(tokenAddress, amount);
    }


    function withDrawAll() public {
        require(userTokenBalance[msg.sender][tokenAddress] > 0, "User doesnt has funds on this vault");
        uint256 amount = userTokenBalance[msg.sender][tokenAddress];
        require(IERC20(tokenAddress).transfer(msg.sender, amount), "the transfer failed");
        userTokenBalance[msg.sender][tokenAddress] = 0;
        emit tokenWithdrawalComplete(tokenAddress, amount);
    }

    function withDrawAmount(uint256 amount) public {
        require(userTokenBalance[msg.sender][tokenAddress] >= amount);
        require(IERC20(tokenAddress).transfer(msg.sender, amount), "the transfer failed");
        userTokenBalance[msg.sender][tokenAddress] -= amount;
        uint256 yDaiReceived
        _mint(msg.sender, shares);
        emit tokenWithdrawalComplete(tokenAddress, amount);
    }

}