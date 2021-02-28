var web3 = new Web3(Web3.givenProvider);
var contractInstance;
var contractAddress = "0x8bEa7B0a7eA6E4a2eB6DC0e3300Bb968cc9FD22c";
var coinSelection = "99";
var userAccount = "Not Connected";

$(document).ready(function() {
    window.ethereum.enable().then(function(accounts){
      contractInstance = new web3.eth.Contract(abi, contractAddress, {from: accounts[0]});
      userAccount = accounts[0];
      console.log(contractInstance);

      contractInstance.events.queryResultRecieved({
          filter:{userAccount}
        }).on('data', function(event){
          var data = event.returnValues;
          if (data.won == 1){
            $("#result").text("Won");
          }
          else{
            $("#result").text("Lost");
          }
          if(data.headstails == 1){
            $("#coin_Selection").text("Head");
          }
          else{
            $("#coin_Selection").text("Tail");
          }
          if(data.randomNumber == 1){
            $("#coinThrow").text("Head");
          }
          else{
            $("#coinThrow").text("Tail");
          }
          lastResult();
          jackpotBalance();
        }).on('error', console.error)
      $("#playerAdress").text(userAccount);
    });

    $("#flip_coin").click(flipCoin);
    $("#deposite").click(contractDeposite);
    $("#withdrawPartial").click(withdrawPartial);
    $("#withdrawAll").click(withdrawAll);
    $("#refresh").click(jackpotBalance);
    $("#getPlayer").click(lastResult);
    $("#initPayout").click(initiatePayout);
    $("#queryCheck").click(checkForQuery);
    $("#coin_heads").click(selectHeads);
    $("#coin_tails").click(selectTails);
    $("#players").click(getNumberOfPlayers);

});


function selectHeads(){
  coinSelection = 1;
  $("#coin_tails").hide();
  console.log("Heads selected");
}

function selectTails(){
  coinSelection = 0;
  $("#coin_heads").hide();
  console.log("Tails selected");
}

function flipCoin(){
  var bet_value = $("#bet_value").val();

  var config = {
    value: web3.utils.toWei(bet_value,"ether")
  }
  if (coinSelection == 99){
    alert('No Coin Side selected')
  }
  else{
    contractInstance.methods.coinFlip(coinSelection).send(config)
    .on("transactionHash", function(hash){
      console.log(hash);
      $("#coin_heads").show();
      $("#coin_tails").show();
    })
    .on("confirmation", function(confirmationNr){
      console.log(confirmationNr);
    })
    .on("receipt", function(receipt){
      console.log(receipt);
    }).then(function(){
      checkForQuery();
      coinSelection = 99;
    })
  }
}

function contractDeposite(){
  var deposite_value = $("#contract_deposite").val();

  var config = {
    value: web3.utils.toWei(deposite_value, "ether")
  }

  contractInstance.methods.depositeBalance().send(config)
  .on("transactionHash", function(hash){
    console.log(hash);
  })
  .on("confirmation", function(confirmationNr){
    console.log(confirmationNr);
  })
  .on("receipt", function(receipt){
    console.log(receipt);
    jackpotBalance();
  });
}

function withdrawPartial(){
  var amount = $("#contract_withrawPartial").val();

  contractInstance.methods.withdrawAmount(web3.utils.toWei(amount, "ether")).send()
  .on("transactionHash", function(hash){
    console.log(hash);
  })
  .on("confirmation", function(confirmationNr){
    console.log(confirmationNr);
  })
  .on("receipt", function(receipt){
    console.log(receipt);
    alert(amount + " ETH has been withdrawn");
    jackpotBalance();
  })
}

function withdrawAll(){
  contractInstance.methods.withdrawAll().send()
  .on("transactionHash", function(hash){
    console.log(hash);
  })
  .on("confirmation", function(confirmationNr){
    console.log(confirmationNr);
  })
  .on("receipt", function(receipt){
    console.log(receipt);
    alert("Contract balance has been withdrawn");
    jackpotBalance();
  })
}

function jackpotBalance(){
  contractInstance.methods.getBalance().call().then(function(res){
    $("#balance").text(web3.utils.fromWei(res, 'ether'));
  });
  contractInstance.methods.getAvailableBalance().call().then(function(res){
    $("#availableBalance").text(web3.utils.fromWei(res, 'ether'));
  });
}

function getNumberOfPlayers(){
  contractInstance.methods.getNumberofPlayers().call().then(function(res){
    $("#numberOfPlayers").text(res);
  });
}

function lastResult(){
  checkForQuery();
  updatePlayer();
}

function updatePlayer(){
  contractInstance.methods.getPlayer().call().then(function(res){
    $("#number_played").text(res.totalPlay);
    $("#number_won").text(res.totalWin);
    $("#total_won").text(web3.utils.fromWei(res.totalWon, 'ether'));
    $("#unpayed_winnings").text(web3.utils.fromWei(res.unpayedWinnings, 'ether'));
  });
}

function checkForQuery(){
  $("#query_pending").text("Checking");
  setTimeout(() => {
    contractInstance.methods.isQueryPending().call().then(function(res){
      if(res == 1){
        $("#query_pending").text("Pending Queries");
      }
      else{
        $("#query_pending").text("No Pending Queries");
        updatePlayer();
      }
    });
  }, 2000);
}

function initiatePayout(){
  contractInstance.methods.payout().send()
  .on("transactionHash", function(hash){
    console.log(hash);
  })
  .on("confirmation", function(confirmationNr){
    console.log(confirmationNr);
  })
  .on("receipt", function(receipt){
    console.log(receipt);
    jackpotBalance();
    lastResult();
  })
}
