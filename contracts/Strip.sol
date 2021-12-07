//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Strip {
  // need to find a way to make yield no longer accrue after expiry
  uint expiry;
  IERC20 io;
  IERC20 po;
  IERC20 steth;
  address trackerAddr;
  mapping (address => IOStakerDeposit) public stakerDeposits;

  struct IOStakerDeposit {
    uint amount;
    uint trackerStartingValue;
  }

  constructor(IERC20 _steth, uint _expiry, address _trackerAddr) {
    // CAN CONSTRUCTOR DEPLOY IO AND PO AND SET THEM TO THE IERC20 INTERFACES
    steth = _steth;
    expiry = _expiry;
    trackerAddr = _trackerAddr;
  }

  function mint(uint _amount) external {
    // NEED TO OVERRIDE _mint FUNCTION  FOR IO AND PO AND ADD TO INTERFACE
    // (can do as function override or as an event trigger in our erc20 inherited contract)

    // recieves steth
    require(steth.transferFrom(msg.sender, address(this), _amount));

    // mints IOsteth and POsteth to sender
    // io.mint(msg.sender, _amount);
    // po.mint(msg.sender, _amount);
  }

  function redeem(uint _amount) external {
    // NEED TO OVERRIDE _burn FUNCTION  FOR IO AND PO AND ADD TO INTERFACE
    // (can do as function override or as an event trigger in our erc20 inherited contract)

    // recieves IOsteth and POsteth 
    require(io.transferFrom(msg.sender, address(this), _amount));
    require(po.transferFrom(msg.sender, address(this), _amount));

    // burns IO and PO sent to this contract
    // require(io.burn(address(this), _amount));
    // require(po.burn(address(this), _amount));

    //  sends steth to sender
    steth.transfer(msg.sender, _amount);
  }

  function claimPrincipal(uint _amount) external {
    // only after expiry
    require(block.timestamp >= expiry);

    // recieves POsteth and 
    require(po.transferFrom(msg.sender, address(this), _amount));

    // sends equal amount of steth to sender
    steth.transfer(msg.sender, _amount);
  }

  function stakeIO(uint _amount) external {
    // check if mapping key already exists (existing deposit)
    require(stakerDeposits[msg.sender].amount == 0, "You have an existing deposit.  You must first claim and unstake to create a new staking deposit");

    // recieves IO  
    require(io.transferFrom(msg.sender, address(this), _amount));

    // creates a deposit with sender address and amount of steth in tracker at deposit time
    stakerDeposits[msg.sender] = IOStakerDeposit(_amount, yieldTrackerBalance());

  }
  
  function claimYield() external {
    // check accrued yield
    uint yield = checkAccruedYield(msg.sender);

    // require non-zero yield
    require(yield < 0, "No yield to claim, bucko, have your gas back");

    // resets tracker amount on deposit to current steth tracker amount
    stakerDeposits[msg.sender].trackerStartingValue = yieldTrackerBalance();
    
    // sends that steth
    steth.transfer(msg.sender, yield);

  }

  function unstakeIOAndClaim() external {
    // Make sure they have a deposit
    require(stakerDeposits[msg.sender].amount != 0, "You have no staked IO...awk");

    // check yield amount and staked amount
    uint yield = checkAccruedYield(msg.sender); 
    uint stakedIO = stakerDeposits[msg.sender].amount;

    // delete their deposit from mapping
    delete stakerDeposits[msg.sender];

    // sends IO to user equal to staked amount and yield
    io.transfer(msg.sender, stakedIO);
    steth.transfer(msg.sender, yield);
  }

  function yieldTrackerBalance() internal view returns(uint) {
    // checks a wallet (hopefully later a vault that can't recieve other steth) for it's steth balance
    return steth.balanceOf(trackerAddr);
    
  }

  function checkAccruedYield(address _staker) public view returns(uint) {
    // calculate accrued yield by looking at yieldTrackerBalance()
    uint startingValue = stakerDeposits[_staker].trackerStartingValue;
    uint stakedIO = stakerDeposits[_staker].amount;
    uint stethYield = ((yieldTrackerBalance() - startingValue)/startingValue)*stakedIO;
    // the % growth in the value of the STETH * the amount of IO deposited is the claimable yield
    return stethYield;
  }


}