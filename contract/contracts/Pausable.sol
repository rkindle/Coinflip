pragma solidity 0.5.12;

import "./Ownable.sol";

contract isPausable is Ownable{

  bool private _paused;

  constructor() internal{
    _paused = false;
  }

  modifier whenNotPaused(){
    require(!_paused);
    _;
  }

  modifier whenPaused(){
    require(_paused);
    _;
  }

  function pause() public onlyOwner whenNotPaused{
    _paused = true;
  }

  function unpause() public onlyOwner whenPaused{
    _paused = false;
  }
}
