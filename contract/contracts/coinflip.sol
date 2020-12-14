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
    address creator = msg.sender;
    player[creator] = _newPlayer;
  }

  function getPlayer() public view returns(uint lastRandomNumber, uint lastResult, uint lastBetValue, uint lastWin, uint totalWin, uint totalPlay, uint totalWon, uint lastWinPayed, uint unpayedWinnings){
    address creator = msg.sender;
    return (player[creator].lastRandomNumber, player[creator].lastResult, player[creator].lastBetValue,
      player[creator].lastWin, player[creator].totalWin, player[creator].totalPlay, player[creator].totalWon,
      player[creator].lastWinPayed, player[creator].unpayedWinnings);
  }

  function updatePlayer(address _creator, uint _lastResult, uint _lastWin) private {
    player[_creator].lastResult = _lastResult;
    player[_creator].lastWin = _lastWin;
    player[_creator].totalWin += _lastResult;
    player[_creator].totalPlay += 1;
    player[_creator].totalWon += _lastWin;
    if (player[_creator].lastWinPayed == 0){
      player[_creator].unpayedWinnings += 2*_lastWin;
    }
    else{
      player[_creator].unpayedWinnings = 2*_lastWin;
    }
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
    emit currentBetValue(_betValue+1);
  }


  function playerNotExists(address _creator) private view returns (bool exists){
    //address creator = msg.sender;
    if (player[_creator].id != 0){
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
    address creator = msg.sender;
    uint QUERY_EXECUTION_DELAY = 0;
    uint GAS_FOR_CALLBACK = 2000000;
    bytes32 queryId = provable_newRandomDSQuery( QUERY_EXECUTION_DELAY, NUM_RANDOM_BYTES_REQUESTED, GAS_FOR_CALLBACK);
    updatePlayerQuery(creator, queryId, 100);
    balance = address(this).balance;
    emit logNewProvableQuery("Provable query sent, waiting for response...", queryId);
  }


  function coinFlip() payable public{
    uint bet_value = msg.value;
    address creator = msg.sender;
    //uint winnings;
    //uint winner;
    require(msg.value <= address(this).balance, "Insufficient contract balance");
    require(player[creator].queryId == 0, "Current result pending");

    if (playerNotExists(creator)){
      createPlayer(creator, bet_value);
    }
    else{
      updateBetValue(creator, bet_value);
    }

    emit currentBetValue(bet_value);

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
    address payable payCreator = msg.sender;
    require(player[payCreator].lastWinPayed == 0, "No payout available");

    //uint res = player[payCreator].lastRandomNumber;
    emit newPayoutInitiated("Payout initiated");

    payCreator.transfer(player[payCreator].unpayedWinnings);

    updatePlayerPayout(payCreator, 1);
    emit payedOut(player[payCreator].unpayedWinnings);

    return player[payCreator].unpayedWinnings;
  }

  function depositeBalance() public onlyOwner payable returns(uint) {
      uint newBalance = address(this).balance + msg.value;
      balance = newBalance;
      return newBalance;
  }

  function withdrawAll() public onlyOwner payable returns(uint) {
      uint toTransfer = address(this).balance;
      balance = 0;
      msg.sender.transfer(toTransfer);
      emit hasBeenWithdrawn(toTransfer);
      return toTransfer;
  }

  function withdrawAmount(uint _amount) public onlyOwner payable returns(uint) {
      require(_amount <= address(this).balance, "Requested amount exeeds current balance");
      balance = address(this).balance - _amount;
      msg.sender.transfer(_amount);
      emit hasBeenWithdrawn(_amount);
      return _amount;
  }

  function getBalance() public view returns(uint){
    return address(this).balance;
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
