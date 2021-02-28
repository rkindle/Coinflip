const Coinflip = artifacts.require('Coinflip');
const ProxyFlip = artifacts.require('ProxyFlip');

module.exports = async function(deployer, network, accounts){

  //Depoloy contracts
  const coinflip = await Coinflip.new();
  const proxyflip = await ProxyFlip.new(coinflip.address);
  console.log(proxyflip.address);
};
