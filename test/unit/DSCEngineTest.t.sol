//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;
import {Test} from "forge-std/Test.sol";
import {DeployDSC} from "script/DeployDSC.s.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "test/mocks/MockV3Aggregator.sol";


contract DSCEngineTest is Test {
    DeployDSC deployer;
    DecentralizedStableCoin dsc;
    DSCEngine engine;
    HelperConfig config;
    address ethUSDPriceFeed;
    address btcUSDPriceFeed;
    address weth;

    address public USER = makeAddr("USER");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;
    uint256 public constant AMOUNT_TO_MINT = 5 ether;
    address public LIQUIDATOR = makeAddr("LIQUIDATOR");
    uint256 public constant COLLATERAL_TO_COVER = 2 ether;


    function setUp() public {
        deployer = new DeployDSC();
        (dsc,engine,config) = deployer.run();
        (ethUSDPriceFeed,btcUSDPriceFeed,  weth,,) = config.activeNetworkConfig();
        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
    }

    // Constructor tests

    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function testRevertsifTokenLengthDoesntMatchPriceFeeds() public {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethUSDPriceFeed);
        priceFeedAddresses.push(btcUSDPriceFeed);

        vm.expectRevert(DSCEngine.
        DSCEngine__TokenAddrLengthandPriceFeedLengthShouldBeSame.selector);
        new DSCEngine(tokenAddresses,priceFeedAddresses, address(dsc));

    }

    // Price tests

    function testGetUSDValue() public view{
        uint256 ethAmount = 15e18;
        uint256 expectedUSDValue = 30000e18;
        uint256 actualUSDValue = engine.getUSDValue(weth,ethAmount);
        assertEq(actualUSDValue,expectedUSDValue);

    }

    function testGetTokenAmountFromUSD() public view{
        uint256 usdAmount = 100 ether;
        uint256 expectedWeth = 0.05 ether;
        uint256 actualWeth = engine.getTokenAmountFromUSD(weth,usdAmount);
        assertEq(expectedWeth,actualWeth);

    }

    // Deposit Collateral tests

    // function testRevertsIfTransferFromFails() public {
    //     // Arrange - Setup
    //     address owner = msg.sender;
    //     vm.prank(owner);
    //     MockFailedTransferFrom mockDsc = new MockFailedTransferFrom();
    //     tokenAddresses = [address(mockDsc)];
    //     feedAddresses = [ethUsdPriceFeed];
    //     vm.prank(owner);
    //     DSCEngine mockDsce = new DSCEngine(tokenAddresses, feedAddresses, address(mockDsc));
    //     mockDsc.mint(user, amountCollateral);

    //     vm.prank(owner);
    //     mockDsc.transferOwnership(address(mockDsce));
    //     // Arrange - User
    //     vm.startPrank(user);
    //     ERC20Mock(address(mockDsc)).approve(address(mockDsce), amountCollateral);
    //     // Act / Assert
    //     vm.expectRevert(DSCEngine.DSCEngine__TransferFailed.selector);
    //     mockDsce.depositCollateral(address(mockDsc), amountCollateral);
    //     vm.stopPrank();
    // }

    function testRevertsIfCollateralZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);

        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        engine.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testDepositCollateral() public {
        vm.startPrank(USER);
        ERC20Mock(weth).mint(address(engine), AMOUNT_COLLATERAL);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        engine.depositCollateral(weth, 0);
        vm.stopPrank();

    }

    function testRevertsWithUnapprovedCollateral() public {
        ERC20Mock ranToken = new ERC20Mock("RAN","RAN", USER, AMOUNT_COLLATERAL);
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NotAllowedToken.selector);
        engine.depositCollateral(address(ranToken), AMOUNT_COLLATERAL);
        vm.stopPrank();

    }
    modifier depositedCollateral() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }
    
    modifier depositedCollateralAndMintedDsc() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateralAndMintDSC(weth, AMOUNT_COLLATERAL, AMOUNT_TO_MINT);
        vm.stopPrank();
        _;
    }

    function testCanDepositCollateralWithoutMinting() public depositedCollateral {
        uint256 userBalance = dsc.balanceOf(USER);
        assertEq(userBalance, 0);
    }    

    function testCanDepositCollateralAndGetAccountInfo() public depositedCollateral{
        (uint256 totalDSCMinted, uint256 collateralValueInUSD) = engine.getAccountInformation(USER);
        uint256 expectedTotalDSCMinted = 0;
        uint256 expectedDepositAmount = engine.getTokenAmountFromUSD(weth, collateralValueInUSD);
        assertEq(totalDSCMinted, expectedTotalDSCMinted);
        assertEq(AMOUNT_COLLATERAL, expectedDepositAmount);
    }

    // function testConstructorInitializesCorrectly() public {
    //     address[] memory tokenAddresses = new address[](2);
    //     address[] memory priceFeedAddresses = new address[](2);
    //     address dscAddress = address(new DecentralizedStableCoin());
    
    //     tokenAddresses[0] = address(0x123);
    //     tokenAddresses[1] = address(0x456);
    //     priceFeedAddresses[0] = address(0x789);
    //     priceFeedAddresses[1] = address(0xABC);
    
    //     DSCEngine engine = new DSCEngine(tokenAddresses, priceFeedAddresses, dscAddress);
    
    //     assertEq(engine.s_collateralTokens(0), tokenAddresses[0]);
    //     assertEq(engine.s_collateralTokens(1), tokenAddresses[1]);
    //     assertEq(engine.s_priceFeeds(tokenAddresses[0]), priceFeedAddresses[0]);
    //     assertEq(engine.s_priceFeeds(tokenAddresses[1]), priceFeedAddresses[1]);
    //     assertEq(address(engine.i_dsc()), dscAddress);
    // }

    function testRevertsIfMintedDscBreaksHealthFactor() public {        
        (, int256 price,,,) = MockV3Aggregator(ethUSDPriceFeed).latestRoundData();
        uint256 amountToMint = (AMOUNT_COLLATERAL * (uint256(price) * engine.getAdditionalFeedPrecision())) / engine.getPrecision();
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);

        uint256 expectedHealthFactor =
            engine.calculateHealthFactor(amountToMint, engine.getUSDValue(weth, AMOUNT_COLLATERAL));
        vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__BreaksHealthFactor.selector, expectedHealthFactor));
        engine.depositCollateralAndMintDSC(weth, AMOUNT_COLLATERAL, amountToMint);
        vm.stopPrank();
    }
        
    function testDepositCollateralAndMintDSC() public {
        // Setup
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        uint256 expectedMintAmount = 5 ether; // Conservative amount that won't break health factor
        
        // Execute
        engine.depositCollateralAndMintDSC(weth, AMOUNT_COLLATERAL, expectedMintAmount);
        assertEq(ERC20Mock(weth).balanceOf(address(engine)), AMOUNT_COLLATERAL);
        assertEq(dsc.balanceOf(USER), expectedMintAmount);
        vm.stopPrank();
    }

    function testCanMintWithDepositedCollateral() public depositedCollateralAndMintedDsc {
        uint256 userBalance = dsc.balanceOf(USER);
        assertEq(userBalance, AMOUNT_TO_MINT);
    }

    // function testRevertsIfMintFails() public {
    //     // Arrange - Setup
    //     MockFailedMintDSC mockDsc = new MockFailedMintDSC();
    //     tokenAddresses = [weth];
    //     feedAddresses = [ethUsdPriceFeed];
    //     address owner = msg.sender;
    //     vm.prank(owner);
    //     DSCEngine mockDsce = new DSCEngine(tokenAddresses, feedAddresses, address(mockDsc));
    //     mockDsc.transferOwnership(address(mockDsce));
    //     // Arrange - User
    //     vm.startPrank(user);
    //     ERC20Mock(weth).approve(address(mockDsce), amountCollateral);

    //     vm.expectRevert(DSCEngine.DSCEngine__MintFailed.selector);
    //     mockDsce.depositCollateralAndMintDsc(weth, amountCollateral, amountToMint);
    //     vm.stopPrank();
    // }

    function testRevertsIfMintAmountIsZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateralAndMintDSC(weth, AMOUNT_COLLATERAL, AMOUNT_TO_MINT);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        engine.mintDSC(0);
        vm.stopPrank();
    }

    function testRevertsIfMintAmountBreaksHealthFactor() public depositedCollateral {
        // 0xe580cc6100000000000000000000000000000000000000000000000006f05b59d3b20000
        // 0xe580cc6100000000000000000000000000000000000000000000003635c9adc5dea00000
        (, int256 price,,,) = MockV3Aggregator(ethUSDPriceFeed).latestRoundData();
        uint256 amountToMint = (AMOUNT_COLLATERAL * (uint256(price) * engine.getAdditionalFeedPrecision())) / engine.getPrecision();

        vm.startPrank(USER);
        uint256 expectedHealthFactor =
            engine.calculateHealthFactor(amountToMint, engine.getUSDValue(weth, AMOUNT_COLLATERAL));
        vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__BreaksHealthFactor.selector, expectedHealthFactor));
        engine.mintDSC(amountToMint);
        vm.stopPrank();
    }

    function testRevertsIfRedeemAmountIsZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateralAndMintDSC(weth, AMOUNT_COLLATERAL, AMOUNT_TO_MINT);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        engine.redeemCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertWhenZeroCollateral() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        engine.depositCollateralAndMintDSC(weth, 0, 5 ether);
        vm.stopPrank();
    }

    function testRevertWhenZeroMintAmount() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        engine.depositCollateralAndMintDSC(weth, AMOUNT_COLLATERAL, 0);
        vm.stopPrank();
    }

    function testRevertWithInvalidToken() public {
        vm.startPrank(USER);
        ERC20Mock invalidToken = new ERC20Mock("INVALID", "INVALID", USER, AMOUNT_COLLATERAL);
        
        vm.expectRevert(DSCEngine.DSCEngine__NotAllowedToken.selector);
        engine.depositCollateralAndMintDSC(address(invalidToken), AMOUNT_COLLATERAL, 5 ether);
        vm.stopPrank();
    }

    function testRedeemCollateral() public depositedCollateral {
        vm.startPrank(USER);
        engine.redeemCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        
        uint256 userBalance = ERC20Mock(weth).balanceOf(USER);
        assertEq(userBalance, AMOUNT_COLLATERAL);
    }
    
    function testRevertRedeemZeroCollateral() public {
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        engine.redeemCollateral(weth, 0);
        vm.stopPrank();
    }
    
    function testRevertRedeemInvalidCollateral() public {
        address invalidCollateral = makeAddr("invalidCollateral");
        vm.startPrank(USER);
        vm.expectRevert();
        engine.redeemCollateral(invalidCollateral, AMOUNT_COLLATERAL);
        vm.stopPrank();
    }
    
    // function testRevertRedeemCollateralBreaksHealthFactor() public {
    //     // Setup: Deposit collateral and mint DSC
    //     vm.startPrank(USER);
    //     ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
    //     engine.depositCollateralAndMintDSC(weth, AMOUNT_COLLATERAL, 50 ether);
        
    //     // Try to redeem all collateral (should fail due to outstanding DSC)
    //     vm.expectRevert(DSCEngine.DSCEngine__BreaksHealthFactor.selector);
    //     engine.redeemCollateral(weth, AMOUNT_COLLATERAL);
    //     vm.stopPrank();
    // }
    
    function testRevertRedeemMoreThanDeposited() public depositedCollateral {
        vm.startPrank(USER);
        vm.expectRevert();
        engine.redeemCollateral(weth, AMOUNT_COLLATERAL + 1);
        vm.stopPrank();
    }

    function testCanMintDsc() public depositedCollateral {
        uint256 amountToMint = 5 ether;
        vm.prank(USER);
        engine.mintDSC(amountToMint);
        uint256 userBalance = dsc.balanceOf(USER);
        assertEq(userBalance, amountToMint);
    }
    
    function testRevertMintZeroDSC() public {
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        engine.mintDSC(0);
        vm.stopPrank();
    }
    
    function testRevertMintWithoutCollateral() public {
        vm.startPrank(USER);
        vm.expectRevert();
        engine.mintDSC(1 ether);
        vm.stopPrank();
    }
    
    // function testRevertMintBreaksHealthFactor() public depositedCollateral {
    //     vm.startPrank(USER);
    //     uint256 tooMuchDsc = 1_000_000 ether; // Very large amount
    //     vm.expectRevert(DSCEngine.DSCEngine__BreaksHealthFactor.selector);
    //     engine.mintDSC(tooMuchDsc);
    //     vm.stopPrank();
    // }
    
    // function testRevertMintFailed() public depositedCollateral {
    //     vm.startPrank(USER);
    //     ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
    //     engine.depositCollateral(weth, AMOUNT_COLLATERAL);
        
    //     vm.expectRevert(DSCEngine.DSCEngine__BreaksHealthFactor.selector);
    //     engine.mintDSC(5 ether);
    //     vm.stopPrank();
    // }

    function testRevertsIfBurnAmountIsZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateralAndMintDSC(weth, AMOUNT_COLLATERAL, AMOUNT_TO_MINT);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        engine.burnDSC(0);
        vm.stopPrank();
    }

    function testCantBurnMoreThanUserHas() public {
        vm.prank(USER);
        vm.expectRevert();
        engine.burnDSC(1);
    }

    function testCanBurnDsc() public depositedCollateralAndMintedDsc {
        vm.startPrank(USER);
        dsc.approve(address(engine), AMOUNT_TO_MINT);
        engine.burnDSC(AMOUNT_TO_MINT);
        vm.stopPrank();

        uint256 userBalance = dsc.balanceOf(USER);
        assertEq(userBalance, 0);
    }

    // function testProperlyReportsHealthFactor() public depositedCollateralAndMintedDSC {
    //     uint256 expectedHealthFactor = 100 ether;
    //     uint256 healthFactor = engine.getHealthFactor(USER);
    //     // $100 minted with $20,000 collateral at 50% liquidation threshold
    //     // means that we must have $200 collatareral at all times.
    //     // 20,000 * 0.5 = 10,000
    //     // 10,000 / 100 = 100 health factor
    //     assertEq(healthFactor, expectedHealthFactor);
    // }

    // function testProperlyReportsHealthFactor() public depositedCollateralAndMintedDsc {
    //     uint256 expectedHealthFactor = 100 ether;
    //     uint256 healthFactor = engine.getHealthFactor(USER);
    //     // $100 minted with $20,000 collateral at 50% liquidation threshold
    //     // means that we must have $200 collatareral at all times.
    //     // 20,000 * 0.5 = 10,000
    //     // 10,000 / 100 = 100 health factor
    //     assertEq(healthFactor, expectedHealthFactor);
    // }

    // function testHealthFactorCanGoBelowOne() public depositedCollateralAndMintedDsc {
    //     int256 ethUsdUpdatedPrice = 18e8; // 1 ETH = $18
    //     // Remember, we need $200 at all times if we have $100 of debt

    //     MockV3Aggregator(ethUSDPriceFeed).updateAnswer(ethUsdUpdatedPrice);

    //     uint256 userHealthFactor = engine.getHealthFactor(USER);
    //     // 180*50 (LIQUIDATION_THRESHOLD) / 100 (LIQUIDATION_PRECISION) / 100 (PRECISION) = 90 / 100 (totalDscMinted) =
    //     // 0.9
    //     assert(userHealthFactor == 0.9 ether);
    // }

    function testMustRedeemMoreThanZero() public depositedCollateralAndMintedDsc {
        vm.startPrank(USER);
        dsc.approve(address(engine), AMOUNT_TO_MINT);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        engine.redeemCollateralforDSC(weth, 0, AMOUNT_TO_MINT);
        vm.stopPrank();
    }

    function testCanRedeemDepositedCollateral() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateralAndMintDSC(weth, AMOUNT_COLLATERAL, AMOUNT_TO_MINT);
        dsc.approve(address(engine), AMOUNT_TO_MINT);
        engine.redeemCollateralforDSC(weth, AMOUNT_COLLATERAL, AMOUNT_TO_MINT);
        vm.stopPrank();

        uint256 userBalance = dsc.balanceOf(USER);
        assertEq(userBalance, 0);
    }

    // This test needs it's own setup
    function testCantLiquidateGoodHealthFactor() public depositedCollateralAndMintedDsc {
        ERC20Mock(weth).mint(LIQUIDATOR, COLLATERAL_TO_COVER);

        vm.startPrank(LIQUIDATOR);
        ERC20Mock(weth).approve(address(engine), COLLATERAL_TO_COVER);
        engine.depositCollateralAndMintDSC(weth, COLLATERAL_TO_COVER, AMOUNT_TO_MINT);
        dsc.approve(address(engine), AMOUNT_TO_MINT);

        vm.expectRevert(DSCEngine.DSCEngine__HealthFactorOk.selector);
        engine.liquidate(weth, USER, AMOUNT_TO_MINT);
        vm.stopPrank();
    }

    modifier liquidated() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateralAndMintDSC(weth, AMOUNT_COLLATERAL, AMOUNT_TO_MINT);
        vm.stopPrank();
        int256 ethUsdUpdatedPrice = 18e8; // 1 ETH = $18

        MockV3Aggregator(ethUSDPriceFeed).updateAnswer(ethUsdUpdatedPrice);
        uint256 userHealthFactor = engine.getHealthFactor(USER);

        ERC20Mock(weth).mint(LIQUIDATOR, COLLATERAL_TO_COVER);

        vm.startPrank(LIQUIDATOR);
        ERC20Mock(weth).approve(address(engine), COLLATERAL_TO_COVER);
        engine.depositCollateralAndMintDSC(weth, COLLATERAL_TO_COVER, AMOUNT_TO_MINT);
        dsc.approve(address(engine), AMOUNT_TO_MINT);
        engine.liquidate(weth, USER, AMOUNT_TO_MINT); // We are covering their whole debt
        vm.stopPrank();
        _;
    }

    function testLiquidationPayoutIsCorrect() public liquidated {
        uint256 liquidatorWethBalance = ERC20Mock(weth).balanceOf(LIQUIDATOR);
        uint256 expectedWeth = engine.getTokenAmountFromUSD(weth, AMOUNT_TO_MINT)
            + (engine.getTokenAmountFromUSD(weth, AMOUNT_TO_MINT) * engine.getLiquidationBonus() / engine.getLiquidationPrecision());
        uint256 hardCodedExpected = 6_111_111_111_111_111_110;
        assertEq(liquidatorWethBalance, hardCodedExpected);
        assertEq(liquidatorWethBalance, expectedWeth);
    }

    function testUserStillHasSomeEthAfterLiquidation() public liquidated {
        // Get how much WETH the user lost
        uint256 amountLiquidated = engine.getTokenAmountFromUSD(weth, AMOUNT_TO_MINT)
            + (engine.getTokenAmountFromUSD(weth, AMOUNT_TO_MINT) * engine.getLiquidationBonus() / engine.getLiquidationPrecision());

        uint256 usdAmountLiquidated = engine.getUSDValue(weth, amountLiquidated);
        uint256 expectedUserCollateralValueInUsd = engine.getUSDValue(weth, AMOUNT_COLLATERAL) - (usdAmountLiquidated);

        (, uint256 userCollateralValueInUsd) = engine.getAccountInformation(USER);
        uint256 hardCodedExpectedValue = 70_000_000_000_000_000_020;
        assertEq(userCollateralValueInUsd, expectedUserCollateralValueInUsd);
        assertEq(userCollateralValueInUsd, hardCodedExpectedValue);
    }

    function testLiquidatorTakesOnUsersDebt() public liquidated {
        (uint256 liquidatorDscMinted,) = engine.getAccountInformation(LIQUIDATOR);
        assertEq(liquidatorDscMinted, AMOUNT_TO_MINT);
    }

    function testUserHasNoMoreDebt() public liquidated {
        (uint256 userDscMinted,) = engine.getAccountInformation(USER);
        assertEq(userDscMinted, 0);
    }

    ///////////////////////////////////
    // View & Pure Function Tests //
    //////////////////////////////////
    function testGetCollateralTokenPriceFeed() public {
        address priceFeed = engine.getCollateralTokenPriceFeed(weth);
        assertEq(priceFeed, ethUSDPriceFeed);
    }

    function testGetCollateralTokens() public {
        address[] memory collateralTokens = engine.getCollateralTokens();
        assertEq(collateralTokens[0], weth);
    }

    function testGetMinHealthFactor() public {
        uint256 minHealthFactor = engine.getMinHealthFactor();
        uint256 expectedMinHealthFactor = 1e18; // DEFAULT_MIN_HEALTH_FACTOR
        assertEq(minHealthFactor, expectedMinHealthFactor);
    }

    function testGetLiquidationThreshold() public {
        uint256 liquidationThreshold = engine.getLiquidationThreshold();
        uint256 expectedLiquidationThreshold = 50; // DEFAULT_LIQUIDATION_THRESHOLD
        assertEq(liquidationThreshold, expectedLiquidationThreshold);
    }

    function testGetAccountCollateralValueFromInformation() public depositedCollateral {
        (, uint256 collateralValue) = engine.getAccountInformation(USER);
        uint256 expectedCollateralValue = engine.getUSDValue(weth, AMOUNT_COLLATERAL);
        assertEq(collateralValue, expectedCollateralValue);
    }

    function testGetCollateralBalanceOfUser() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        uint256 collateralBalance = engine.getCollateralBalanceOfUser(USER, weth);
        assertEq(collateralBalance, AMOUNT_COLLATERAL);
    }

    function testGetAccountCollateralValue() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        uint256 collateralValue = engine.getAccountCollateralValue(USER);
        uint256 expectedCollateralValue = engine.getUSDValue(weth, AMOUNT_COLLATERAL);
        assertEq(collateralValue, expectedCollateralValue);
    }

    function testGetDsc() public {
        address dscAddress = engine.getDsc();
        assertEq(dscAddress, address(dsc));
    }

    function testLiquidationPrecision() public {
        uint256 expectedLiquidationPrecision = 100;
        uint256 actualLiquidationPrecision = engine.getLiquidationPrecision();
        assertEq(actualLiquidationPrecision, expectedLiquidationPrecision);
    }


}