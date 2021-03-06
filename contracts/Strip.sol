//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IOSteth.sol";
import "./POSteth.sol";
import "../artifacts/interfaces/ISTETH.sol";

contract Strip {
  // need to find a way to make yield no longer accrue after expiry
  uint expiry;
  IERC20 io;
  IERC20 po;
  ISTETH steth;
  address trackerAddr;
  mapping (address => IOStakerDeposit) public stakerDeposits;

  struct IOStakerDeposit {
    uint amount;
    uint trackerStartingValue;
  }

  constructor(ISTETH _steth, uint _expiry, address _trackerAddr) {
    steth = _steth;
    expiry = _expiry;
    trackerAddr = _trackerAddr;
    // make mint amounts equal to deposited STETH in "issue" 
    io = new IOSTeth(10000 * (10**18));
    po = new POSteth(10000 * (10**18));
    console.log(block.timestamp);
  }

  
  // replace with "issue" function
  function mint(uint _amount) external {
    // receives steth
    require(steth.transferFrom(msg.sender, address(this), _amount), "Must approve stEth transfer prior to mint!");

    // mints IOsteth and POsteth to sender
    io.transfer(msg.sender, _amount);
    po.transfer(msg.sender, _amount);
  }

  // unneeded 
  function redeem(uint _amount) external {
    // receives IOsteth and POsteth 
    require(io.transferFrom(msg.sender, address(this), _amount), "Must approve ioSteth transfer prior to redeem!");
    require(po.transferFrom(msg.sender, address(this), _amount), "Must approve poSteth transfer prior to redeem!");

    //  sends steth to sender
    steth.transfer(msg.sender, _amount);
  }

  // is PO even needed for this?
  function claimPrincipal(uint _amount) external {
    // only after expiry
    require(block.timestamp >= expiry, "No PO redemption before expiry");

    // receives POsteth and 
    require(po.transferFrom(msg.sender, address(this), _amount), "Did not recieve PO tokens");

    // sends equal amount of steth to sender
    steth.transfer(msg.sender, _amount);
  }

  function stakeIO(uint _amount) external {
    // check if mapping key already exists (existing deposit)
    require(stakerDeposits[msg.sender].amount == 0, "You have an existing deposit.  You must first claim and unstake to create a new staking deposit");

    // receives IO  
    require(io.transferFrom(msg.sender, address(this), _amount), "Must approve ioSteth transfer prior to stake!");

    // creates a deposit with sender address and amount of steth in tracker at deposit time
    stakerDeposits[msg.sender] = IOStakerDeposit(_amount, yieldTrackerBalance());

  }
  
  // Yield only at expiry?
  function claimYield() external {
    // check accrued yield
    uint yield = checkAccruedYield(msg.sender);

    // require non-zero yield
    require(yield > 0, "No yield to claim, bucko, have your gas back");

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
    // Had to reorder math here, worth checking back on
    // calculate accrued yield by looking at yieldTrackerBalance()
    uint startingValue = stakerDeposits[_staker].trackerStartingValue;
    uint stakedIO = stakerDeposits[_staker].amount;

    // the % growth in the value of the STETH * the amount of IO deposited is the claimable yield
    // have to multiply by stakeIO before dividing becuase solidity doesn't do fractions apparently
    uint stethYield = (yieldTrackerBalance() - startingValue) * stakedIO/startingValue;
  
    return stethYield;
  }


}