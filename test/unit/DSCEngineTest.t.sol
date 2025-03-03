//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;
import {Test} from "forge-std/Test.sol";
import {DeployDSC} from "script/DeployDSC.s.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";


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
    
    function testDepositCollateralAndMintDSC() public {
        // Setup
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        uint256 expectedMintAmount = 5 ether; // Conservative amount that won't break health factor
        
        // Execute
        engine.depositCollateralAndMintDSC(weth, AMOUNT_COLLATERAL, expectedMintAmount);
        
        // Verify
        (uint256 totalDSCMinted, uint256 collateralValueInUSD) = engine.getAccountInformation(USER);
        assertEq(totalDSCMinted, expectedMintAmount);
        assertEq(ERC20Mock(weth).balanceOf(address(engine)), AMOUNT_COLLATERAL);
        assertEq(dsc.balanceOf(USER), expectedMintAmount);
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

    // function testRevertOnBreakingHealthFactor() public {
    //     vm.startPrank(USER);
    //     ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        
    //     // Try to mint more than collateral value allows
    //     uint256 tooMuchDsc = 50000 ether;
        
    //     vm.expectRevert(DSCEngine.DSCEngine__BreaksHealthFactor.selector);
    //     engine.depositCollateralAndMintDSC(weth, AMOUNT_COLLATERAL, tooMuchDsc);
    //     vm.stopPrank();
    // }

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






}