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
  }

  event coinflipResult(uint result, uint winnings);
  event uncoughtException(string message);
  event hasBeenWithdrawn(uint toTransfer);
  event playerCreated(string message);
  event playerUpdated(uint lastResult, uint lastWin, uint totalWin, uint totalPlay, uint totalWon);
  event playerQueryUpdate(string message);
  event generatedRandomNumber(uint randomNumber);
  event logNewProvableQuery(string message);
  event logNewQueryResponse(string message);
  event newPayoutInitiated(string message);
  event showResult(uint res);

  uint private balance;
  mapping (address => Player) private player;
  mapping (bytes32 => address) private queries;
  address[] private players;
  uint constant NUM_RANDOM_BYTES_REQUESTED = 1;

  function createPlayer() private{
    Player memory newPlayer;
    newPlayer.id = 1;
    newPlayer.queryId = 0;
    newPlayer.lastRandomNumber = 99;
    newPlayer.lastBetValue = 0;
    newPlayer.lastWin = 0;
    newPlayer.totalWin = 0;
    newPlayer.totalPlay = 0;
    newPlayer.totalWon = 0;
    newPlayer.lastWinPayed = 1;

    insertPlayer(newPlayer);
    players.push(msg.sender);

    emit playerCreated("New Player created");
  }

  function insertPlayer(Player memory _newPlayer) private{
    address creator = msg.sender;
    player[creator] = _newPlayer;
  }

  function getPlayer() public view returns(uint lastResult, uint lastBetValue, uint lastWin, uint totalWin, uint totalPlay, uint totalWon){
    address creator = msg.sender;
    return (player[creator].lastResult, player[creator].lastBetValue, player[creator].lastWin, player[creator].totalWin, player[creator].totalPlay, player[creator].totalWon);
  }

  function updatePlayer(uint _lastResult, uint _lastWin) private {
    address _creator = msg.sender;
    player[_creator].lastResult = _lastResult;
    player[_creator].lastWin = _lastWin;
    player[_creator].totalWin += _lastResult;
    player[_creator].totalPlay += 1;
    player[_creator].totalWon += _lastWin;
    emit playerUpdated(player[_creator].lastResult, player[_creator].lastWin, player[_creator].totalWin, player[_creator].totalPlay, player[_creator].totalWon);
  }

  function updatePlayerPayout(address _creator, uint _lastWinPayed) private{
    player[_creator].lastWinPayed = _lastWinPayed;
  }

  function updatePlayerQuery(address _creator, bytes32 _queryId, uint _randomNumber) private {
    queries[_queryId] = _creator;
    player[_creator].queryId = _queryId;
    player[_creator].lastRandomNumber = _randomNumber;
    emit playerQueryUpdate("Player query updated");
  }

  function updateBetValue(address _creator, uint _betValue) private{
    player[_creator].lastBetValue = _betValue;
  }


  function playerNotExists() private view returns (bool exists){
    address creator = msg.sender;
    if (player[creator].id != 0){
      exists = false;
    }
    else{
      exists = true;
    }
    return exists;
  }

  /*function random() private view returns(uint result){
    uint res = block.timestamp % 2;
    return res;
  }*/

  function __callback(bytes32 _queryId, string memory _result, bytes memory _proof) public {
    require(msg.sender == provable_cbAddress());
    address creator = queries[_queryId];
    updatePlayerPayout(creator, 0);

    emit logNewQueryResponse("Query response received");

    uint randomNumber = uint(keccak256(abi.encodePacked(_result))) % 2;
    updatePlayerQuery(creator, 0, randomNumber);
    emit generatedRandomNumber(randomNumber);
  }

  function oracleRandom() private {
    address creator = msg.sender;
    uint QUERY_EXECUTION_DELAY = 0;
    uint GAS_FOR_CALLBACK = 2000000;
    bytes32 queryId = provable_newRandomDSQuery( QUERY_EXECUTION_DELAY, NUM_RANDOM_BYTES_REQUESTED, GAS_FOR_CALLBACK);
    updatePlayerQuery(creator, queryId, 100);
    balance = balance - 20000000000000000;
    emit logNewProvableQuery("Provable query sent, waiting for response...");
  }


  function coinFlip() payable public{
    uint bet_value = msg.value;
    address creator = msg.sender;
    //uint winnings;
    //uint winner;
    require(msg.value <= balance, "Insufficient contract balance");
    require(player[creator].queryId == 0, "Current result pending");

    if (playerNotExists()){
      createPlayer();
    }

    updateBetValue(creator, bet_value);

    oracleRandom();

    //uint res = random();
    //uint res = block.timestamp % 2;
    /*if(res == 0){
      winner = 0;
      balance = balance + bet_value;
      winnings = 0;
      emit coinflipResult(res, winnings);
    }
    else if(res == 1){
      winner = 1;
      winnings = 2* bet_value;
      balance = balance - bet_value;
      msg.sender.transfer(winnings);
      emit coinflipResult(res, winnings);
    }
    else{
      emit uncoughtException(1);
    }
    updatePlayer(winner, winnings);
    return (winner, winnings);
    */
  }

  function payout() public payable returns(uint){
    uint winnings;
    uint winner;
    address payable payCreator = msg.sender;
    require(player[payCreator].queryId == 0, "No payout, query still pending");

    uint res = player[payCreator].lastRandomNumber;
    emit newPayoutInitiated("Payout initiated with result");
    emit showResult(res);

    if(res == 0){
      winner = 0;
      balance = balance + player[payCreator].lastBetValue;
      winnings = 0;
    }
    else if(res == 1){
      winner = 1;
      winnings = 2* player[payCreator].lastBetValue;
      balance = balance - player[payCreator].lastBetValue;
      if (player[payCreator].lastWinPayed == 0){
        payCreator.transfer(winnings);
      }
    }
    else{
      emit uncoughtException("Random Number not updated - RESULT NOT 1 OR 0");
    }
    updatePlayer(winner, winnings);
    updatePlayerPayout(payCreator, 1);
    emit coinflipResult(res, winnings);
    return winnings;
  }

  function depositeBalance() public onlyOwner payable returns(uint) {
      uint newBalance = balance + msg.value;
      balance = newBalance;
      return newBalance;
  }

  function withdrawAll() public onlyOwner payable returns(uint) {
      uint toTransfer = balance;
      balance = 0;
      msg.sender.transfer(toTransfer);
      emit hasBeenWithdrawn(toTransfer);
      return toTransfer;
  }

  function withdrawAmount(uint _amount) public onlyOwner payable returns(uint) {
      require(_amount <= balance, "Requested amount exeeds current balance");
      balance = balance - _amount;
      msg.sender.transfer(_amount);
      emit hasBeenWithdrawn(_amount);
      return _amount;
  }

  function getBalance() public view returns(uint){
    return balance;
  }

  function isQueryPending() public view returns(uint){
    address creator = msg.sender;
    if(player[creator].queryId == 0){
      return 0;
    }
    else{
      return 1;
    }
  }

}
