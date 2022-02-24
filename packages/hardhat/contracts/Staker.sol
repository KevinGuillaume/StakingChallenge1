//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "hardhat/console.sol";
import "./ExampleExternalContract.sol";

contract Staker {


  // Balance mapping
  mapping(address => uint256) public balances;
  //keep track of how many times someones executed
  mapping(address => uint8) public executions;

  //able to withdraw boolean check
  bool public _openForWithdraw = false;

   // Staking threshold
  uint256 public constant threshold = 1 ether;

  uint256 public amountExecuted = 0;
  //staking timing deadline
  uint256 public deadline = block.timestamp + 72 hours;

  //contract event
  event Stake(address indexed sender, uint256 amount);


/**
  @notice modifier to see if time limit is met
  @param deadlineReached is the value passed in we want to check
 */
  modifier finishedDeadline(bool deadlineReached) {
    uint256 timeLeft = timeLeft();
    if(deadlineReached){
      require(timeLeft == 0,"Not reached");
    }
    else{
      require(timeLeft > 0, "Deadline already reached");
    }
    _;
  }
/**
  @notice modifier to see if we can withdraw
  @param isOpen is value passed in that we want to check (so want to check if true)
 */
  modifier isOpenForWithdraw(bool isOpen) {
    if(isOpen){
      require(_openForWithdraw == true, "Not open for withdrawal yet");
    }
    _;
  }

  ExampleExternalContract public exampleExternalContract;

  constructor(address exampleExternalContractAddress) public {
      exampleExternalContract = ExampleExternalContract(exampleExternalContractAddress);
     
  }

  // Collect funds in a payable `stake()` function and track individual `balances` with a mapping:
  //  ( make sure to add a `Stake(address,uint256)` event and emit it for the frontend <List/> display )
  function stake() public payable {
    // update the user's balance
    balances[msg.sender] += msg.value;
    
    // emit the event 
    emit Stake(msg.sender, msg.value);

    //checks if we are able to withdraw before threshold is hit
    if(address(this).balance < threshold ){
      _openForWithdraw = true;
    }
    if(address(this).balance >= threshold && timeLeft() == 0){
      (bool sent,) = address(exampleExternalContract).call{value: address(this).balance}(abi.encodeWithSignature("complete()"));
      require(sent, "exampleExternalContract.complete failed");
    }
  }

  // After some `deadline` allow anyone to call an `execute()` function
  //  It should either call `exampleExternalContract.complete{value: address(this).balance}()` to send all the value
  function execute() public finishedDeadline(true)  {
    require(amountExecuted < 1, "Executed has been called before");
    uint256 contractBal = address(this).balance;
    exampleExternalContract.complete{value: contractBal}();
    
    amountExecuted +=1;
    
  }

  // if the `threshold` was not met, allow everyone to call a `withdraw()` function
  /** 
  @notice Should let users withdraw if open for withdrawal
  @param _address to be withdrawn from
  */
  function withdraw(address payable _address) public isOpenForWithdraw(true) {
      
      uint256 userBalance = balances[_address];

      //ensure they have money to withdraw
      
      //reset their balance since they are withdrawing
      balances[_address] = 0;

      //give them their money by using a call
      (bool sent,) = _address.call{value: userBalance}("");
      require(sent, "Failed to send Ether");
      
  }


  // Add a `timeLeft()` view function that returns the time left before the deadline for the frontend
  function timeLeft() public view returns(uint256 timeRemaining) {
    if(block.timestamp >= deadline){
      return 0;
    }
    else {
      return deadline - block.timestamp;
    }
  }

  // Add the `receive()` special function that receives eth and calls stake()
  receive() external payable{
    uint256 amount = msg.value;
    (bool sent,) = address(this).call{value: amount}(abi.encodeWithSignature("stake()"));
    require(sent,"Contract recieved eth and didn't stake");
  }

}