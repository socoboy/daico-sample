pragma solidity ^0.4.21;

import './fund/ICrowdsaleFund.sol';
import './token/TransferLimitedToken.sol';
import './token/LockedTokens.sol';
import './utilities/Ownable.sol';
import './utilities/Pausable.sol';


contract SimpleDAICO is Ownable, SafeMath, Pausable {

    uint256 public constant ETHER_MIN_CONTRIB = 0.2 ether;
    uint256 public constant ETHER_MAX_CONTRIB = 20 ether;

    uint256 public constant SALE_START_TIME = 1524060000; // 18.04.2018 14:00:00 UTC
    uint256 public constant SALE_END_TIME = 1526479200; // 16.05.2018 14:00:00 UTC

    uint256 public tokenPriceNum = 0;
    uint256 public tokenPriceDenom = 0;
    
    TransferLimitedToken public token;
    ICrowdsaleFund public fund;
    LockedTokens public lockedTokens;

    mapping(address => uint256) public userTotalContributed;

    address public teamTokenWallet;

    uint256 public totalEtherContributed = 0;
    uint256 public rawTokenSupply = 0;

    uint256 public hardCap = 0; // World hard cap will be set right before Token Sale

    event LogContribution(address contributor, uint256 amountWei, uint256 tokenAmount, uint256 timestamp);

    modifier checkContribution() {
        require(isValidContribution());
        _;
    }

    modifier checkCap() {
        require(validateCap());
        _;
    }

    modifier checkTime() {
        require(now >= SALE_START_TIME && now <= SALE_END_TIME);
        _;
    }

    function SimpleDAICO(
        address tokenAddress,
        address fundAddress,
        address _teamTokenWallet,
        address _owner
    ) public
        Ownable(_owner)
    {
        require(tokenAddress != address(0));

        token = TransferLimitedToken(tokenAddress);
        fund = ICrowdsaleFund(fundAddress);

        teamTokenWallet = _teamTokenWallet;
    }

    /**
     * @dev check contribution amount and time
     */
    function isValidContribution() internal view returns(bool) {
        uint256 currentUserContribution = safeAdd(msg.value, userTotalContributed[msg.sender]);
        if(msg.value >= ETHER_MIN_CONTRIB) {
            if(currentUserContribution > ETHER_MAX_CONTRIB) {
                    return false;
            }
            return true;

        }

        return false;
    }

    /**
     * @dev Check hard cap overflow
     */
    function validateCap() internal view returns(bool){
        if(msg.value <= safeSub(hardCap, totalEtherContributed)) {
            return true;
        }
        return false;
    }

    /**
     * @dev Set token price once before start of crowdsale
     */
    function setTokenPrice(uint256 _tokenPriceNum, uint256 _tokenPriceDenom) public onlyOwner {
        require(tokenPriceNum == 0 && tokenPriceDenom == 0);
        require(_tokenPriceNum > 0 && _tokenPriceDenom > 0);
        tokenPriceNum = _tokenPriceNum;
        tokenPriceDenom = _tokenPriceDenom;
    }

    /**
     * @dev Set hard cap.
     * @param _hardCap - Hard cap value
     */
    function setHardCap(uint256 _hardCap) public onlyOwner {
        require(hardCap == 0);
        hardCap = _hardCap;
    }

    /**
     * @dev Set LockedTokens contract address
     */
    function setLockedTokens(address lockedTokensAddress) public onlyOwner {
        lockedTokens = LockedTokens(lockedTokensAddress);
    }

    /**
     * @dev Fallback function to receive ether contributions
     */
    function () payable public whenNotPaused {
        processContribution(msg.sender, msg.value);
    }

    /**
     * @dev Process ether contribution. Calc bonuses and issue tokens to contributor.
     */
    function processContribution(address contributor, uint256 amount) private checkTime checkContribution checkCap {
        uint256 tokenAmount = safeDiv(safeMul(amount, tokenPriceNum), tokenPriceDenom);
        rawTokenSupply = safeAdd(rawTokenSupply, tokenAmount);

        processPayment(contributor, amount, tokenAmount);
    }

    function processPayment(address contributor, uint256 etherAmount, uint256 tokenAmount) internal {

        token.issue(contributor, tokenAmount);
        fund.processContribution.value(etherAmount)(contributor);
        totalEtherContributed = safeAdd(totalEtherContributed, etherAmount);
        userTotalContributed[contributor] = safeAdd(userTotalContributed[contributor], etherAmount);
        LogContribution(contributor, etherAmount, tokenAmount, now);
    }

    /**
     * @dev Finalize crowdsale if we reached hard cap or current time > SALE_END_TIME
     */
    function finalizeCrowdsale() public onlyOwner {
        if(
            totalEtherContributed >= safeSub(hardCap, 1000 ether) ||
            now >= SALE_END_TIME
        ) {
            fund.onCrowdsaleEnd();
            uint256 suppliedTokenAmount = token.totalSupply();

            // Team
            uint256 companyTokenAmount = safeDiv(safeMul(suppliedTokenAmount, 3), 17); // 15%
            token.issue(address(lockedTokens), companyTokenAmount);
            lockedTokens.addTokens(teamTokenWallet, companyTokenAmount, now + 730 days); // Lock for a long time before able to use

            token.finishIssuance();
        }
    }
}
