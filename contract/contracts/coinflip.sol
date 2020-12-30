import "./Ownable.sol";
import "./provableAPI.sol";
pragma solidity 0.5.12;

contract Coinflip is Ownable, usingProvable{

  struct Player{
    uint id;
    bytes32 queryId;
    uint lastRandomNumber;
    uint lastBetValue;
    uint lastResult;
    uint lastWin;
    uint totalWin;
    uint totalPlay;
    uint totalWon;
    uint lastWinPayed;
    uint unpayedWinnings;
  }

  event payedOut(uint payout);
  event uncoughtException(string message);
  event hasBeenWithdrawn(uint toTransfer);
  event playerCreated(string message, address Creator);
  event playerUpdated(uint lastResult, uint lastWin, uint totalWin, uint totalPlay, uint totalWon);
  event playerQueryUpdate(string message);
  event generatedRandomNumber(uint randomNumber);
  event logNewProvableQuery(string message, bytes32 queryId);
  event newPayoutInitiated(string message);
  event currentBetValue(uint value);

  uint private balance;
  mapping (address => Player) private player;
  mapping (bytes32 => address) private queries;
  address[] private players;
  uint constant NUM_RANDOM_BYTES_REQUESTED = 1;

  function createPlayer(address _creator, uint _betValue) private{
    //Function to creat a player initially
    Player memory newPlayer;
    newPlayer.id = 1;
    newPlayer.queryId = 0;
    newPlayer.lastRandomNumber = 99;
    newPlayer.lastBetValue = _betValue;
    newPlayer.lastWin = 0;
    newPlayer.totalWin = 0;
    newPlayer.totalPlay = 0;
    newPlayer.totalWon = 0;
    newPlayer.lastWinPayed = 1;
    newPlayer.unpayedWinnings = 0;

    insertPlayer(newPlayer);
    players.push(_creator);

    emit playerCreated("New Player created. ID:", _creator);
  }

  function insertPlayer(Player memory _newPlayer) private{
    //Function to add new player
    address creator = msg.sender;
    player[creator] = _newPlayer;
  }

  function getPlayer() public view returns(uint lastRandomNumber, uint lastResult, uint lastBetValue, uint lastWin, uint totalWin, uint totalPlay, uint totalWon, uint lastWinPayed, uint unpayedWinnings){
    //Function to get the player stats
    address creator = msg.sender;
    return (player[creator].lastRandomNumber, player[creator].lastResult, player[creator].lastBetValue,
      player[creator].lastWin, player[creator].totalWin, player[creator].totalPlay, player[creator].totalWon,
      player[creator].lastWinPayed, player[creator].unpayedWinnings);
  }

  function updatePlayer(address _creator, uint _lastResult, uint _lastWin) private {
    //Function to update player stats and information
    player[_creator].lastResult = _lastResult;
    player[_creator].lastWin = _lastWin;
    player[_creator].totalWin += _lastResult;
    player[_creator].totalPlay += 1;
    player[_creator].totalWon += _lastWin;
    //Check for unpayed winnigs and accordingly add winings or just overwrite
    //May be obsolete due to recent change to updatePlayerPayout() function
    if (player[_creator].lastWinPayed == 0){
      player[_creator].unpayedWinnings += 2*_lastWin;
    }
    else{
      player[_creator].unpayedWinnings = 2*_lastWin;
    }
    emit playerUpdated(player[_creator].lastResult, player[_creator].lastWin, player[_creator].totalWin, player[_creator].totalPlay, player[_creator].totalWon);
  }

  function updatePlayerPayout(address _creator, uint _lastWinPayed) private{
    //Function to ensure payout is only possible when payouts are pending
    player[_creator].lastWinPayed = _lastWinPayed;
    if (_lastWinPayed == 1){
      player[_creator].unpayedWinnings = 0;
    }
  }

  function updatePlayerQuery(address _creator, bytes32 _queryId, uint _randomNumber) private {
    //Function to change oracel query status and update player
    queries[_queryId] = _creator;
    player[_creator].queryId = _queryId;
    player[_creator].lastRandomNumber = _randomNumber;
    emit playerQueryUpdate("Player query updated");
  }

  function updateBetValue(address _creator, uint _betValue) private{
    //Function to change only the bet Value - maybe not necessary
    player[_creator].lastBetValue = _betValue;
    emit currentBetValue(_betValue);
  }


  function playerNotExists(address _creator) private view returns (bool exists){
    //Check if player already exists in the listing
    if (player[_creator].id != 0){
      exists = false;
    }
    else{
      exists = true;
    }
    return exists;
  }

  function __callback(bytes32 _queryId, string memory _result, bytes memory _proof) public {
    //Funciton oracel callback
    require(msg.sender == provable_cbAddress());
    address creator = queries[_queryId];

    uint randomNumber = uint(keccak256(abi.encodePacked(_result))) % 2;
    updatePlayerQuery(creator, 0, randomNumber);
    if (randomNumber == 1){
      uint winnings = player[creator].lastBetValue;
      updatePlayer(creator, 1, winnings);
    }
    else{
      updatePlayer(creator, 0, 0);
    }
    emit generatedRandomNumber(randomNumber);
    updatePlayerPayout(creator, 0);
  }

  function oracleRandom() private {
    //Function for the oracle call
    address creator = msg.sender;
    uint QUERY_EXECUTION_DELAY = 0;
    uint GAS_FOR_CALLBACK = 2000000;
    bytes32 queryId = provable_newRandomDSQuery( QUERY_EXECUTION_DELAY, NUM_RANDOM_BYTES_REQUESTED, GAS_FOR_CALLBACK);
    updatePlayerQuery(creator, queryId, 100);
    balance = address(this).balance;
    emit logNewProvableQuery("Provable query sent, waiting for response...", queryId);
  }


  function coinFlip() payable public{
    //Main Funciton to flip a coin
    uint bet_value = msg.value;
    address creator = msg.sender;

    require(msg.value <= address(this).balance, "Insufficient contract balance"); //Needs to be changed to consider the unpaid winnings
    require(player[creator].queryId == 0, "Current result pending"); //Prevents new bet whilst a query is still pending

    if (playerNotExists(creator)){
      createPlayer(creator, bet_value);
    }
    else{
      updateBetValue(creator, bet_value);
    }

    oracleRandom();
  }

  function payout() public payable returns(uint){
    //Function to payout the unpayed winnings
    address payable payCreator = msg.sender;
    require(player[payCreator].lastWinPayed == 0, "No payout available");

    emit newPayoutInitiated("Payout initiated");

    payCreator.transfer(player[payCreator].unpayedWinnings);

    updatePlayerPayout(payCreator, 1);  //Set the payout to has been executed
    emit payedOut(player[payCreator].unpayedWinnings);

    return player[payCreator].unpayedWinnings;  //Will return 0 due to the last change on updatePlayerPayout - add variable to carry value
  }

  function depositeBalance() public onlyOwner payable returns(uint) {
    //Function to add balance to the contract
      uint newBalance = address(this).balance + msg.value;
      balance = newBalance;
      return newBalance;
  }

  function withdrawAll() public onlyOwner payable returns(uint) {
    //Function to withdraw entire contract balance
    //Change Required: Consider the unpayed winnings of the players for withdrawable balance
      uint toTransfer = address(this).balance;
      balance = 0;
      msg.sender.transfer(toTransfer);
      emit hasBeenWithdrawn(toTransfer);
      return toTransfer;
  }

  function withdrawAmount(uint _amount) public onlyOwner payable returns(uint) {
    //Function to withdraw an amount to be specified
    //Change Required: Consider the upayed winnings of the players for withdrawable balance
      require(_amount <= address(this).balance, "Requested amount exeeds current balance");
      balance = address(this).balance - _amount;
      msg.sender.transfer(_amount);
      emit hasBeenWithdrawn(_amount);
      return _amount;
  }

  function getBalance() public view returns(uint){
    //Function to request contract balance
    return address(this).balance;
  }

  function isQueryPending() public view returns(uint){
    //Function to check if a oracle query is waiting for callback
    address creator = msg.sender;
    if(player[creator].queryId == 0){
      return 0;
    }
    else{
      return 1;
    }
  }

}
