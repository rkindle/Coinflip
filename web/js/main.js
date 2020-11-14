var web3 = new Web3(Web3.givenProvider);
var contractInstance;
var contractAddress = "0x8dB0dc00E8960AccF2dFcD9894C3edF834B9C712";

$(document).ready(function() {
    window.ethereum.enable().then(function(accounts){
      contractInstance = new web3.eth.Contract(abi, contractAddress, {from: accounts[0]});
      console.log(contractInstance);
    });
    $("#flip_coin").click(flipCoin);
    $("#deposite").click(contractDeposite);
    $("#withdrawPartial").click(withdrawPartial);
    $("#withdrawAll").click(withdrawAll);
    $("#refresh").click(jackpotBalance);
});

function flipCoin(){
  var bet_value = $("#bet_value").val();

  var config = {
    value: web3.utils.toWei(bet_value,"ether")
  }

  contractInstance.methods.coinFlip().send(config)
  .on("transactionHash", function(hash){
    console.log(hash);
  })
  .on("confirmation", function(confirmationNr){
    console.log(confirmationNr);
  })
  .on("receipt", function(receipt){
    console.log(receipt);
  }).then(function(){
    var queryPending = checkForQuery();
    while (queryPending == 1){
      setTimeout(() => { console.log('Result not received yet');}, 2000);
      queryPending = checkForQuery();
    }

    jackpotBalance();
    lastResult();
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
  })

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
  })
}

function lastResult(){
  contractInstance.methods.getPlayer().call().then(function(res){
    if (res.lastResult == 1){
      $("#result").text("Won");
    }
    else{
      $("#result").text("Lost");
    }
    $("#lastBetAmount").text(web3.utils.fromWei(res.lastBetValue, 'ether'));
    $("#value_won").text(web3.utils.fromWei(res.lastWin, 'ether'));
  })
}

function checkForQuery(){
  contractInstance.methods.isQueryPending().call().then(function(res){
    if (res == 0){
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
      })
      return 0;
    }
    else{
      return 1;
    }
  })
}
