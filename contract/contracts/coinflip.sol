import "./Ownable.sol";
import "./provableAPI.sol";
pragma solidity 0.5.12;

contract Coinflip is Ownable, usingProvable{

  //Struct to hold the player statistics
  struct Player{
    uint id;
    uint queryPending;
    //uint lastRandomNumber;
    //uint lastBetValue;
    uint lastResult;
    uint lastWin;
    uint totalWin;
    uint totalPlay;
    uint totalWon;
    uint lastWinPayed;
    uint unpayedWinnings;
  }

  //Struct to hold only the individual bets
  struct bet{
    address creator;
    uint betValue;
    uint result;
    uint headstails;
  }

  //event uncoughtException(string message);
  //event hasBeenWithdrawn(uint toTransfer);
  event playerCreated(string message, address creator);
  //event playerUpdated(uint lastResult, uint lastWin, uint totalWin, uint totalPlay, uint totalWon);
  //event playerQueryUpdate(string message);
  //event generatedRandomNumber(uint randomNumber);
  event logNewProvableQuery(string message, address creator, bytes32 queryId);
  //event currentBetValue(uint value);
  event queryResultRecieved(
    address indexed player,
    uint won,
    uint randomNumber,
    uint headstails
    );

  uint private balance;
  uint private availableBalance;
  mapping (address => Player) private player;
  //mapping (bytes32 => address) private queries; //Mapping to link adresses to queries
  mapping (bytes32 => bet) private bets;
  address[] private players;
  uint constant NUM_RANDOM_BYTES_REQUESTED = 1;

  function createPlayer(address _creator) private{
    //Function to creat a player initially
    Player memory newPlayer;
    newPlayer.id = 1;
    newPlayer.queryPending = 0;
    //newPlayer.lastRandomNumber = 99;      //Commented for integration of mapping bets
    //newPlayer.lastBetValue = _betValue;   //Commented for integration of mapping bets
    newPlayer.lastResult = 0;
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

  function createBet(address _creator, uint _betValue, uint _result, uint _headstails, bytes32 _queryId) private{
    bet memory newBet;
    newBet.creator = _creator;
    newBet.betValue = _betValue;
    newBet.result = _result;
    newBet.headstails = _headstails;
    insertBet(newBet, _queryId);
  }

  function insertBet(bet memory _newBet, bytes32 _queryId) private {
    bets[_queryId] = _newBet;
  }

  function getPlayer() public view returns(uint queryPending, uint lastResult, uint lastWin, uint totalWin, uint totalPlay, uint totalWon, uint lastWinPayed, uint unpayedWinnings){
    //Function to get the player stats
    address creator = msg.sender;
    return (player[creator].queryPending, player[creator].lastResult, player[creator].lastWin, player[creator].totalWin,
      player[creator].totalPlay, player[creator].totalWon, player[creator].lastWinPayed, player[creator].unpayedWinnings);
  }

  function updatePlayer(address _creator, uint _lastResult, uint _lastWin) private {
    //Function to update player stats and information
    player[_creator].lastResult = _lastResult;    //Commented for integration of mapping bets
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
    //emit playerUpdated(player[_creator].lastResult, player[_creator].lastWin, player[_creator].totalWin, player[_creator].totalPlay, player[_creator].totalWon);
  }

  function updatePlayerPayout(address _creator, uint _lastWinPayed) private{
    //Function to ensure payout is only possible when payouts are pending
    player[_creator].lastWinPayed = _lastWinPayed;
    if (_lastWinPayed == 1){
      player[_creator].unpayedWinnings = 0;
    }
  }

  function updatePlayerQuery(address _creator, uint _queryPending) private {
    //Function to track pending responses per player
    if(_queryPending == 99){
      player[_creator].queryPending = player[_creator].queryPending - 1;
    }
    else if(_queryPending == 1){
      player[_creator].queryPending += _queryPending;
    }
    //queries[_queryId] = _creator;         //Commented for integration of mapping bets; Redundant as _creator present in bets
    //player[_creator].queryId = _queryId;
    //player[_creator].lastRandomNumber = _randomNumber;
    //emit playerQueryUpdate("Player query updated");
  }

  /*function updateBetValue(address _creator, uint _betValue) private{
    //Function to change only the bet Value - maybe not necessary
    player[_creator].lastBetValue = _betValue;
    emit currentBetValue(_betValue);
  }*/

  function updateBetResult(bytes32 _queryId, uint _result) private{
    bets[_queryId].result = _result;
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
    address creator = bets[_queryId].creator;

    uint randomNumber = uint(keccak256(abi.encodePacked(_result))) % 2;
    updateBetResult(_queryId, randomNumber);
    updatePlayerQuery(creator, 99);

    /*updatePlayerQuery(creator, 0, randomNumber);
    if (bets[queryId].result == bets[queryId].headstails){
      uint winnings = bets[queryId].betValue;
      updatePlayer(creator, 1, winnings);
    }
    else{
      updatePlayer(creator, 0, 0);
    }*/
    uint won = hasWon(_queryId);

    //emit generatedRandomNumber(randomNumber);
    emit queryResultRecieved(bets[_queryId].creator, won, randomNumber, bets[_queryId].headstails);
    //updatePlayerPayout(creator, 0);
  }

  function oracleRandom() private returns(bytes32){
    //Function for the oracle call
    address creator = msg.sender;
    uint QUERY_EXECUTION_DELAY = 0;
    uint GAS_FOR_CALLBACK = 2000000;
    bytes32 queryId = provable_newRandomDSQuery( QUERY_EXECUTION_DELAY, NUM_RANDOM_BYTES_REQUESTED, GAS_FOR_CALLBACK);
    updatePlayerQuery(creator, 1);
    balance = address(this).balance;
    emit logNewProvableQuery("Provable query sent, waiting for response...", creator, queryId);
    checkAvailableBalance();
    return queryId;
  }


  function coinFlip(uint _headstails) payable public{
    //Main Funciton to flip a coin
    uint bet_value = msg.value;
    address creator = msg.sender;

    require(msg.value <= address(this).balance, "Insufficient contract balance"); //Needs to be changed to consider the unpaid winnings
    //require(player[creator].queryId == 0, "Current result pending"); //Prevents new bet whilst a query is still pending

    if (playerNotExists(creator)){
      createPlayer(creator);
    }
    /*else{
      updateBetValue(creator, bet_value);
    }*/

    bytes32 queryId = oracleRandom();
    createBet(creator, bet_value, 99, _headstails, queryId);
  }

  function payout() public payable returns(uint){
    //Function to payout the unpayed winnings
    address payable payCreator = msg.sender;
    require(player[payCreator].lastWinPayed == 0, "No payout available");
    //Check
    var amountToWithdraw = player[payCreator].unpayedWinnings;
    //Effect
    updatePlayerPayout(payCreator, 1);  //Set the payout to has been executed; Improved to follow CHECK - EFFECT - INTERACTION best practive
    //Interaction
    payCreator.transfer(amountToWithdraw);

    checkAvailableBalance();

    return amountToWithdraw;
  }

  function depositeBalance() public onlyOwner payable returns(uint) {
    //Function to add balance to the contract
      uint newBalance = address(this).balance + msg.value;
      checkAvailableBalance();
      balance = newBalance;
      return newBalance;
  }

  function withdrawAll() public onlyOwner payable returns(uint) {
    //Function to withdraw entire contract balance
    //Changed: Consider the unpayed winnings of the players for withdrawable balance
    uint currentAvailableBalance = checkAvailableBalance();
    require(currentAvailableBalance > 0, "No balance to be withdrawn");

    uint toTransfer = currentAvailableBalance;
      //balance = 0;
    checkAvailableBalance();
    msg.sender.transfer(toTransfer);
    //emit hasBeenWithdrawn(toTransfer);
    //Add Assert statement currentAvailableBalance == 0
    return toTransfer;
  }

  function withdrawAmount(uint _amount) public onlyOwner payable returns(uint) {
    //Function to withdraw an amount to be specified
    //Changed: Consider the upayed winnings of the players for withdrawable balance
    uint currentAvailableBalance = checkAvailableBalance();
    require(_amount <= currentAvailableBalance, "Requested amount exeeds available balance");
      //balance = address(this).balance - _amount;
    msg.sender.transfer(_amount);
    //emit hasBeenWithdrawn(_amount);
    return _amount;
  }

  function getBalance() public view returns(uint){
    //Function to request contract balance
    return address(this).balance;
  }

  function isQueryPending() public view returns(uint){
    //Function to check if a oracle query is waiting for callback
    address creator = msg.sender;
    if(player[creator].queryPending == 0){
      return 0;
    }
    else{
      return 1;
    }
  }

  function hasWon(bytes32 _queryId) private returns(uint){
    //Function to check if won; Returns 1 for won; Retruns 0 or lost

    //Get creator adress from bets mapping
    address creator = bets[_queryId].creator;

    //Check if result does match with selection
    if (bets[_queryId].result == bets[_queryId].headstails){
      uint winnings = bets[_queryId].betValue;
      updatePlayer(creator, 1, winnings);
      //Set Player payout to unpayed
      updatePlayerPayout(creator, 0);
      checkAvailableBalance();
      return 1;
    }
    else{
      updatePlayer(creator, 0, 0);
      checkAvailableBalance();
      return 0;
    }
  }

  function checkAvailableBalance() private returns(uint){
    //Add function to check for all unpayed winnings and update balance
    uint unpayedWinnings = 0;
    if (players.length > 0){
      for (uint i = 0; i < players.length; i++){
        unpayedWinnings += player[players[i]].unpayedWinnings;
      }
    }
    availableBalance = address(this).balance - unpayedWinnings;
    return availableBalance;
  }

  function getAvailableBalance() public view returns(uint){
    return availableBalance;
  }

  function getNumberofPlayers() public view returns(uint){
    //Function to receive the number of players which have played
    return players.length;
  }

}
