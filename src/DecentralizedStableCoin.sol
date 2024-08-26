//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20Burnable,ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
/**
 * @title Decentralized Stable Coin
 * @author Venkata Surya Sundar Vadali.
 * @notice A decentralized stable coin is a type of cryptocurrency that is designed to have low price volatility.
 * Collateral : Exogenous (ETH & BTC).
 * Minting: Algorithmic
 * Relative Stability: Pegged to USD
 * Governed by DSCEngine. This contract is ERC20 implementation of our stableCoin system.
 */
contract DecentralizedStableCoin is ERC20Burnable, Ownable {
    /*Errors */
    error DecentralizedStableCoin__MustbeMoreThanZero();
    error DecentralizedStableCoin__BurnAmountExceedsBalance();
    error DecentralizedStableCoin__NotZeroAddress();

    constructor() ERC20("DecentralizedStableCoin","DSC") Ownable(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266) {
        
    }

    function burn(uint256 _amount) public override onlyOwner{
        uint256 balance = balanceOf(msg.sender);
        if (_amount <= 0){
            revert DecentralizedStableCoin__MustbeMoreThanZero();
        }
        if (balance < _amount){
            revert DecentralizedStableCoin__BurnAmountExceedsBalance();
        }
        super.burn(_amount);
    }

    function mint(address _to, uint256 _amount) external onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert DecentralizedStableCoin__NotZeroAddress();
        }
        if (_amount <= 0) {
            revert DecentralizedStableCoin__MustbeMoreThanZero();
        }
        _mint(_to, _amount);
        return true;
    }



}