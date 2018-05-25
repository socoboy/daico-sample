const SimpleDAICO = artifacts.require('SimpleDAICO');
const DAICOToken = artifacts.require('DAICOToken');
const PollManagedFund = artifacts.require('PollManagedFund');
const RefundPoll = artifacts.require('RefundPoll');
const TapPoll = artifacts.require('TapPoll');

module.exports = function(deployer) {
  deployer.deploy(
    PollManagedFund,
    '0x11a5640b3143782d2de7865a68aea2bf9e206681',     // team wallet to receive fund
    '0x11a5640b3143782d2de7865a68aea2bf9e206681',     // team wallet to receive token
    ['0x11a5640b3143782d2de7865a68aea2bf9e206681'],   // owner
    { gas: 50000000 }
  ).then(() => {
    return deployer.deploy(
      DAICOToken,
      PollManagedFund.address,                        // Listener address, listen for fund
      ['0x11a5640b3143782d2de7865a68aea2bf9e206681'], // owner
      '0x11a5640b3143782d2de7865a68aea2bf9e206681',   // transfer limit manager
      { gas: 50000000 }
    ).then(() => {
      return deployer.deploy(
        SimpleDAICO,
        DAICOToken.address,                             // token address
        PollManagedFund.address,                        // fund address
        '0x11a5640b3143782d2de7865a68aea2bf9e206681',   // team wallet to receive token
        '0x11a5640b3143782d2de7865a68aea2bf9e206681'    // owner
      ).then(() => {
        return deployer.deploy(
          TapPoll,
          0,
          DAICOToken.address,
          PollManagedFund.address,
          1527282000,
          1558742400,
          0
        ).then(() => {

        });
      });
    });
  });
};
