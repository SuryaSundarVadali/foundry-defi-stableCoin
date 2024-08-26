//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
/**
 * @title DSCEngine
 * @author Venkata Surya Sundar Vadali.
 * @notice A decentralized stable coin is a type of cryptocurrency that is designed to have low price volatility.
 * This system
 */

contract DSCEngine {
    //errors
    error DSCEngine__NeedsMoreThanZero();
    error DSCEngine__TokenAddrLengthandPriceFeedLengthShouldBeSame();
    error DSCEngine__NotAllowedToken();

    //State Variables
    mapping (address token => address priceFeed) private s_priceFeeds; //tokentoPriceFeed
    DecentralizedStableCoin private immutable i_dsc;


    // Modifiers
    modifier moreTHanZero(uint256 _amount) {
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
        }

        i_dsc = DecentralizedStableCoin(dscAddress);
    }

    function depositCollateralAndMintDSC() public {
        
    }

    function depositCollateral(address tokenCollateralAddress,uint256 amountCollateral) external moreTHanZero(amountCollateral) {
        
    }       

    function redeemCollateralforDSC() public {
        
    }

    function redeemCollateral() public {
        
    }

    function burnDSC() public {
        
    }

    function liquidate() public {
        
    }

    function getHealthFactor() public {
        
    }


}