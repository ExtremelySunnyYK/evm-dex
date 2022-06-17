// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @title DEX
 * @author chiayong.eth
 * @notice Empty DEX.sol that just outlines what features could be part of the challenge (up to you!)
 * @dev We want to create an automatic market where our contract will hold reserves of both ETH and 🎈 Balloons. These reserves will provide liquidity that allows anyone to swap between the assets.
 * NOTE: functions outlined here are what work with the front end of this branch/repo. Also return variable names that may need to be specified exactly may be referenced (if you are confused, see solutions folder in this repo and/or cross reference with front-end code).
 */
contract DEX {
    /* ========== GLOBAL VARIABLES ========== */

    using SafeMath for uint256; //outlines use of SafeMath for uint256 variables
    IERC20 token; //instantiates the imported contract

    // Reserves
    uint256 public totalLiquidity;
    mapping(address => uint256) public s_liquidity;
    address private _owner;

    /* ========== EVENTS ========== */

    /**
     * @notice Emitted when ethToToken() swap transacted
     */
    event EthToTokenSwap();

    /**
     * @notice Emitted when tokenToEth() swap transacted
     */
    event TokenToEthSwap();

    /**
     * @notice Emitted when liquidity provided to DEX and mints LPTs.
     */
    event LiquidityProvided();

    /**
     * @notice Emitted when liquidity removed from DEX and decreases LPT count within DEX.
     */
    event LiquidityRemoved();

    /* ========== CONSTRUCTOR ========== */

    constructor(address token_addr) {
        token = IERC20(token_addr); //specifies the token address that will hook into the interface and be used through the variable 'token'
        _owner = msg.sender;
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    /**
     * @notice initializes amount of tokens that will be transferred to the DEX itself from the erc20 contract mintee (and only them based on how Balloons.sol is written). Loads contract up with both ETH and Balloons.
     * @param tokens amount to be transferred to DEX
     * @return totalLiquidity is the number of LPTs minting as a result of deposits made to DEX contract
     * NOTE: since ratio is 1:1, this is fine to initialize the totalLiquidity (wrt to balloons) as equal to eth balance of contract.
     */
    function init(uint256 tokens) public payable returns (uint256) {
        require(totalLiquidity == 0, "DEX : init  - already has liquidity");
        totalLiquidity = address(this).balance;
        s_liquidity[msg.sender] = totalLiquidity;
        require(token.transferFrom(msg.sender, address(this), tokens));
        return totalLiquidity;
    }

    /**
     * @notice returns yOutput, or yDelta for xInput (or xDelta)
     * @dev Follow along with the [original tutorial](https://medium.com/@austin_48503/%EF%B8%8F-minimum-viable-exchange-d84f30bd0c90) Price section for an understanding of the DEX's pricing model and for a price function to add to your contract. You may need to update the Solidity syntax (e.g. use + instead of .add, * instead of .mul, etc). Deploy when you are done.
     ( amount of ETH in DEX ) * ( amount of tokens in DEX ) = k
     the “price” is basically how much of the resulting output asset you will get if you put in a certain amount of the input asset.
     
      @param input_amount amount you want to swap
      @param input_reserve the reserve you want to swap from
      @param output_reserve the reserve you want to swap to       
     */
    function price(
        uint256 input_amount,
        uint256 input_reserve,
        uint256 output_reserve
    ) public pure returns (uint256 yOutput) {
        uint256 input_amount_with_fee = input_amount.mul(997); // deduct fee from input 99.7%
        uint256 numerator = input_amount_with_fee.mul(output_reserve); //
        uint256 denominator = input_reserve.mul(1000).add(
            input_amount_with_fee
        ); // new reserves
        return numerator / denominator; // given the amount of tokens you are adding to the DEX, what is the price of the input/output?
    }

    /**
     * @notice returns liquidity for a user. Note this is not needed typically due to the `liquidity()` mapping variable being public and having a getter as a result. This is left though as it is used within the front end code (App.jsx).
     */
    function getLiquidity(address lp) public view returns (uint256) {
        // return liquidity[lp];
    }

    /**
     * @notice sends Ether to DEX in exchange for $BAL
     */
    function ethToToken() public payable returns (uint256 tokenOutput) {
        require(msg.value > 0, "cannot swap 0 eth");
        // Get token reserve,
        uint256 token_reserve = tokens.balanceOf(address(this));
        uint256 ethReserve = address(this).balance.sub(msg.value);

        uint tokenOutput = price(msg.value, ethReserve, token_reserve);
        require(
            token.transfer(msg.sender, tokenOutput),
            "ethToToken(): reverted swap due to failed transfer"
        ); // need approval for this to work
        emit EthToTokenSwap(
            msg.sender,
            "Eth to Balloons",
            msg.value,
            tokenOutput
        );
        return tokenOutput;
    }

    /**
     * @notice sends $BAL tokens to DEX in exchange for Ether
     */
    function tokenToEth(uint256 tokenInput) public returns (uint256 ethOutput) {
        require(tokenInput > 0, "cannot swap 0 Bal tokens");
        uint256 token_reserve = tokens.balanceOf(address(this));
        uint256 ethOutput = price(
            tokenInput,
            token_reserve,
            address(this).balance
        );
        require(
            token.transferFrom(msg.sender, address(this), tokenInput),
            "tokenToEth(): reverted swap."
        ); // sending token from sender to dex
        (bool sent, ) = msg.sender.call{value: ethOutput}(""); // sending eth to caller
        require(sent, "tokenToEth: revert in transferring eth to you!");
        emit TokenToEthSwap(
            msg.sender,
            "Balloons to Ether",
            tokenInput,
            ethOutput
        );
        return ethOutput;
    }

    /**
     * @notice allows deposits of $BAL and $ETH to liquidity pool
     * NOTE: parameter is the msg.value sent with this function call. That amount is used to determine the amount of $BAL needed as well and taken from the depositor.
     * NOTE: user has to make sure to give DEX approval to spend their tokens on their behalf by calling approve function prior to this function call.
     * NOTE: Equal parts of both assets will be removed from the user's wallet with respect to the price outlined by the AMM.
     */
    function deposit() public payable returns (uint256 tokensDeposited) {
        require(msg.value > 0, "Cannot deposit 0 Eth");
        uint256 ethReserve = address(this).balance.sub(msg.value); // new reserves. we have to subtract because the msg.value has already been added to the reserve
        uint256 token_reserve = token.balanceOf(address(this));
        uint256 tokenDeposit = (msg.value.mul(token_reserve) / ethReserve).add(
            1
        );

        uint256 liquidityMinted = msg.value.mul(totalLiquidity) / ethReserve;
        s_liquidity[msg.sender] = s_liquidity[msg.sender].add(liquidityMinted);
        totalLiquidity = totalLiquidity.add(liquidityMinted);

        require(token.transferFrom(msg.sender, address(this), tokenDeposit));
        emit LiquidityProvided(
            msg.sender,
            liquidityMinted,
            msg.value,
            tokenDeposit
        );
        return tokenDeposit;
    }

    /**
     * @notice allows withdrawal of $BAL and $ETH from liquidity pool
     * NOTE: with this current code, the msg caller could end up getting very little back if the liquidity is super low in the pool. I guess they could see that with the UI.
     */
    function withdraw(uint256 amount)
        public
        returns (uint256 eth_amount, uint256 token_amount)
    {
        require(
            s_liquidity[msg.sender] >= amount,
            "withdraw: sender does not have enough liquidity to withdraw."
        );
        uint256 ethReserve = address(this).balance;
        uint256 tokenReserve = token.balanceOf(address(this));
        uint256 ethWithdrawn;

        ethWithdrawn = amount.mul(ethReserve) / totalLiquidity;

        uint256 tokenAmount = amount.mul(tokenReserve) / totalLiquidity;
        s_liquidity[msg.sender] = s_liquidity[msg.sender].sub(amount);
        totalLiquidity = totalLiquidity.sub(amount);
        (bool sent, ) = payable(msg.sender).call{value: ethWithdrawn}("");
        require(sent, "withdraw(): revert in transferring eth to you!");
        require(token.transfer(msg.sender, tokenAmount));
        emit LiquidityRemoved(msg.sender, amount, ethWithdrawn, tokenAmount);
        return (ethWithdrawn, tokenAmount);
    }
}
