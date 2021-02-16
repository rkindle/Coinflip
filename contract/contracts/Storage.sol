pragma solidity 0.5.12;

contract Storage{
  mapping (string => uint256) _uintStorage;
  mapping (string => address) _addressStorage;
  mapping (string => bool) _boolStorage;
  mapping (string => string) _stringStorage;
  mapping (string => bytes4) _bytesStorage;

  struct Player{
    uint id;
    uint queryPending;
    uint lastResult;
    uint lastWin;
    uint totalWin;
    uint totalPlay;
    uint totalWon;
    uint lastWinPayed;
    uint unpayedWinnings;
  }

  struct bet{
    address creator;
    uint betValue;
    uint result;
    uint headstails;
  }


  address public owner;
  bool public _initialized;


}
