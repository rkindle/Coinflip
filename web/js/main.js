var web3 = new Web3(Web3.givenProvider);
var contractInstance;
var contractAddress = "0xb69561B73f386D17B583Ec41c134A8a928169e14";
var coinSelection = "99";
var userAccount = "Not Connected";

$(document).ready(function() {
    window.ethereum.enable().then(function(accounts){
      contractInstance = new web3.eth.Contract(abi, contractAddress, {from: accounts[0]});
      userAccount = accounts[0];
      console.log(contractInstance);
      console.log(userAccount);
      $("#playerAdress").text(userAccount);
    });

    /*
      contractInstance.event.queryResultRecieved({
        filter:{userAccount}
      ).on('data', function(event){
        var data = event.returnValues;
        console.log(data); // same results as the optional callback above
      }).on('error', console.error);*/

    contractInstance.queryResultRecieved({filter:{player: userAccount}
    }).watch(function(error, result){
      if (!error){
        console.log(data);
        console.log("Player " + result.player);
        console.log("Won " + result.won);
        console.log("Random Number " + result.randomNumber);
        console.log("Heads or Tails " + result.headstails);
      }
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

  contractInstance.methods.coinFlip(coinSelection).send(config)
  .on("transactionHash", function(hash){
    console.log(hash);
  })
  .on("confirmation", function(confirmationNr){
    console.log(confirmationNr);
  })
  .on("receipt", function(receipt){
    console.log(receipt);
  }).then(function(){
    //lastResult();
    $("#coin_heads").show();
    $("#coin_tails").show();
    eventListener();
  })
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
    //alert("Contract Balance increased");
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
    //$("#lastBetAmount").text(web3.utils.fromWei(res.lastBetValue, 'ether'));
    $("#number_played").text(res.totalPlay);
    $("#total_won").text(web3.utils.fromWei(res.totalWon, 'ether'));
    $("#unpayed_winnings").text(web3.utils.fromWei(res.unpayedWinnings, 'ether'));
    /*if (res.lastRandomNumber == coinSelection){
      $("#result").text("Won");
      $("#value_won").text(web3.utils.fromWei(res.lastWin, 'ether'));
    }
    else{
      $("#result").text("Lost");
      $("#value_won").text(0);
    }*/
  });
}

function checkForQuery(){
  $("#query_pending").text("Checking");
  setTimeout(() => {
    contractInstance.methods.isQueryPending().call().then(function(res){
    $("#query_pending").text(res);
    if(res == 0){
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
    //jackpotBalance();
    //lastResult();
  })
}
