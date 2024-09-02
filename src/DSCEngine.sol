//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/v0.8/interfaces/AggregatorV3Interface.sol";
/**
 * @title DSCEngine
 * @author Venkata Surya Sundar Vadali.
 * @notice A decentralized stable coin is a type of cryptocurrency that is designed to have low price volatility.
 * This system
 */

contract DSCEngine is ReentrancyGuard{
    //errors
    error DSCEngine__NeedsMoreThanZero();
    error DSCEngine__TokenAddrLengthandPriceFeedLengthShouldBeSame();
    error DSCEngine__NotAllowedToken();
    error DSCEngine__TransferFailed();
    error DSCEngine__BreaksHealthFactor(uint256 healthFactor);
    error DSCEngine__MintFailed();

    //State Variables

    //constants
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1;

    mapping (address token => address priceFeed) private s_priceFeeds; //tokentoPriceFeed
    mapping (address user => mapping(address token => uint256 amount)) private s_collateralDeposited; //userToTokenToAmount
    mapping (address user => uint256 amountDSCMinted) private s_DSCminted;
    address[] private s_collateralTokens;

    DecentralizedStableCoin private immutable i_dsc;

    // Events
    event CollateralDeposited(address indexed user, address indexed token, uint256 amount);


    // Modifiers
    modifier moreThanZero(uint256 _amount) {
        if (_amount == 0){
            revert DSCEngine__NeedsMoreThanZero();
        }
        _;
    }

    modifier  isAllowedToken(address token) {
        if(s_priceFeeds[token] == address(0)){
            revert DSCEngine__NotAllowedToken();
        }
        _;
        
    }

    //Functions

    constructor(
        address[] memory tokenAddresses,
        address[] memory priceFeedAddresses,
        address dscAddress) {
        // USD price feed
        if(tokenAddresses.length != priceFeedAddresses.length){
            revert DSCEngine__TokenAddrLengthandPriceFeedLengthShouldBeSame();
        }

        for(uint256 i = 0; i < tokenAddresses.length; i++){
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }

        i_dsc = DecentralizedStableCoin(dscAddress);
    }

    function depositCollateralAndMintDSC() public {
        
    }

    function depositCollateral(
        address tokenCollateralAddress,
        uint256 amountCollateral) 
        external moreThanZero(amountCollateral) isAllowedToken(tokenCollateralAddress)
        nonReentrant
        {
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if(!success){
            revert DSCEngine__TransferFailed();
        }
    }       

    function redeemCollateralforDSC() public {
        
    }

    function redeemCollateral() public {
        
    }
    /**
     * @notice Mint DSC tokens
     * @param amountDSCtoMint Amount of DSC tokens to mint
     * @notice they must have more collateral value than the minimum threshold 
     */
    function mintDSC(uint256 amountDSCtoMint) external moreThanZero(amountDSCtoMint) nonReentrant {
        s_DSCminted[msg.sender] += amountDSCtoMint;
        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_dsc.mint(msg.sender, amountDSCtoMint);
        if (!minted){
            revert DSCEngine__MintFailed();
        }
    }

    function burnDSC(uint256 amount) public {
        
    }

    function liquidate() public {
        
    }

    function getHealthFactor() public {
        
    }


    // Private and Internal Functions

    function _getAccountInformation(address user)private view returns(uint256 totalDSCminted,uint256 collateralValueInUSD) {
        totalDSCminted = s_DSCminted[user];
        collateralValueInUSD = getAccountCollateralValue(user);
    }

    function _healthFactor(address user) private view returns (uint256){
        // total DSC Minted
        // total collateral value
        (uint256 totalDSCminted,uint256 collateralValueInUSD) = _getAccountInformation(user);
        uint256 collateralAdjustedForThreshold = (collateralValueInUSD * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForThreshold * PRECISION) / totalDSCminted;
        // return (collateralValueInUSD / totalDSCminted);
    }
    function _revertIfHealthFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);
        if(userHealthFactor < MIN_HEALTH_FACTOR){
            revert DSCEngine__BreaksHealthFactor(userHealthFactor);
        }
    }

    function getAccountCollateralValue(address user) public view returns(uint256 totalCollateralValueInUSD){
        // loop through each collateral token, get the amount they have deposited and get the price feed value
        for(uint256 i=0; i<s_collateralTokens.length; i++){
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValueInUSD += getUSDValue(token, amount);
        }
        return totalCollateralValueInUSD;

        
    }

    function getUSDValue(address token, uint256 amount) public view returns (uint256){
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (,int256 price,,,) = priceFeed.latestRoundData();
        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
    }




}